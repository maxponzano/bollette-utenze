#!/usr/bin/env bash
# Verifica le regole di accesso (RLS) su un Postgres locale che simula Supabase.
# Uso: bash tests/test-rls.sh   (richiede i binari di PostgreSQL 14+)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
WORK="$(mktemp -d)"
PORT=55432
trap '"$PGBIN/pg_ctl" -D "$WORK/data" stop -m fast >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

if [ "$(id -u)" = "0" ]; then RUN="su postgres -s /bin/bash -c"; chown -R postgres "$WORK"; else RUN="bash -c"; fi
$RUN "'$PGBIN/initdb' -D '$WORK/data' -U postgres -A trust >/dev/null"
$RUN "'$PGBIN/pg_ctl' -D '$WORK/data' -o '-p $PORT -k $WORK -c listen_addresses=' -l '$WORK/log' start >/dev/null"
export PGOPTIONS="-c client_min_messages=warning"
PSQL=(psql -h "$WORK" -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1 -qAt)

# --- stub minimo di Supabase: ruoli e auth.jwt() ---
"${PSQL[@]}" <<'SQL'
create role anon nologin; create role authenticated nologin;
create schema auth; grant usage on schema auth to anon, authenticated;
create function auth.jwt() returns jsonb language sql stable as
  $$ select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $$;
grant usage on schema public to anon, authenticated;
SQL

"${PSQL[@]}" -f "$ROOT/supabase/01_schema.sql" >/dev/null
sed "s/la-tua-email@esempio.it/admin@test.it/" "$ROOT/supabase/00_admin.sql" | "${PSQL[@]}" >/dev/null
"${PSQL[@]}" -f "$ROOT/supabase/02_seed_basilico.sql" >/dev/null
"${PSQL[@]}" -f "$ROOT/supabase/02_seed_basilico.sql" >/dev/null   # rieseguibile senza duplicati

# secondo cliente con due POD, e gli accessi
"${PSQL[@]}" <<'SQL' >/dev/null
insert into clienti (id, nome) values ('00000000-0000-4000-8000-000000000002', 'Altro Cliente');
insert into forniture (id, cliente_id, tipo, codice) values
  ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-000000000002', 'luce', 'POD-A'),
  ('00000000-0000-4000-8000-0000000000b2', '00000000-0000-4000-8000-000000000002', 'luce', 'POD-B');
insert into bollette (fornitura_id, anno, mese, fornitore, consumo, costo) values
  ('00000000-0000-4000-8000-0000000000b1', 2026, 1, 'X', 100, 50),
  ('00000000-0000-4000-8000-0000000000b2', 2026, 1, 'X', 200, 90);
insert into accessi (email, cliente_id) values
  ('basilico@test.it', '6b2f0c1e-0000-4000-8000-000000000001'),
  ('altro@test.it',    '00000000-0000-4000-8000-000000000002');
SQL

FAIL=0
# esegue una query come utente autenticato con l'email indicata
as_user() { # email ruolo sql
  "${PSQL[@]}" -c "set role $2; select set_config('request.jwt.claims', '{\"email\":\"$1\"}', false);" -c "$3" | tail -1
}
check() { # descrizione atteso ottenuto
  if [ "$2" = "$3" ]; then echo "  OK   $1 ($3)"; else echo "  FAIL $1: atteso '$2', ottenuto '$3'"; FAIL=1; fi
}
try_write() { # email sql -> "ok" | "negato"
  if as_user "$1" authenticated "$2" >/dev/null 2>&1; then echo ok; else echo negato; fi
}

echo "Admin:"
check "vede tutti i clienti"   2  "$(as_user admin@test.it authenticated 'select count(*) from clienti')"
check "vede tutte le bollette" 30 "$(as_user admin@test.it authenticated 'select count(*) from bollette')"
check "is_admin()"             t  "$(as_user admin@test.it authenticated 'select is_admin()')"
check "può inserire bollette"  ok "$(try_write admin@test.it "insert into bollette (fornitura_id,anno,mese,fornitore,consumo,costo) values ('00000000-0000-4000-8000-0000000000b1',2026,2,'X',1,1)")"
check "totale EE Basilico 2026" "23272.46|8454.41" "$(as_user admin@test.it authenticated "select sum(consumo)||'|'||sum(costo) from bollette where fornitura_id='6b2f0c1e-0000-4000-8000-0000000000e1' and anno=2026")"
check "totale gas Basilico 2025" "2640.00|3227.20" "$(as_user admin@test.it authenticated "select sum(consumo)||'|'||sum(costo) from bollette where fornitura_id='6b2f0c1e-0000-4000-8000-0000000000a1' and anno=2025")"

echo "Cliente Basilico:"
check "vede solo il suo cliente"   "Basilico di Bonino Alessandro" "$(as_user basilico@test.it authenticated "select string_agg(nome, ',') from clienti")"
check "vede solo le sue forniture" 2  "$(as_user basilico@test.it authenticated 'select count(*) from forniture')"
check "vede solo le sue bollette"  28 "$(as_user basilico@test.it authenticated 'select count(*) from bollette')"
check "vede solo il suo accesso"   1  "$(as_user basilico@test.it authenticated 'select count(*) from accessi')"
check "non vede la lista admin"    0  "$(as_user basilico@test.it authenticated 'select count(*) from admins')"
check "is_admin() falso"           f  "$(as_user basilico@test.it authenticated 'select is_admin()')"
check "non può inserire bollette"  negato "$(try_write basilico@test.it "insert into bollette (fornitura_id,anno,mese,fornitore,consumo,costo) values ('6b2f0c1e-0000-4000-8000-0000000000e1',2030,1,'X',1,1)")"
check "non può modificare bollette" 0 "$(as_user basilico@test.it authenticated "with u as (update bollette set costo=0 returning 1) select count(*) from u")"
check "non può cancellare bollette" 0 "$(as_user basilico@test.it authenticated "with d as (delete from bollette returning 1) select count(*) from d")"
check "non può darsi altri accessi" negato "$(try_write basilico@test.it "insert into accessi (email,cliente_id) values ('basilico@test.it','00000000-0000-4000-8000-000000000002')")"
check "non può diventare admin"    negato "$(try_write basilico@test.it "insert into admins (email) values ('basilico@test.it')")"
check "email in maiuscolo = stessa" 28 "$(as_user BASILICO@test.it authenticated 'select count(*) from bollette')"

echo "Altro cliente:"
check "vede solo le sue 2 forniture" 2 "$(as_user altro@test.it authenticated 'select count(*) from forniture')"
check "non vede Basilico"            0 "$(as_user altro@test.it authenticated "select count(*) from clienti where nome like 'Basilico%'")"

echo "Utente senza accessi / anonimo:"
check "login senza accesso: nessun cliente" 0 "$(as_user sconosciuto@test.it authenticated 'select count(*) from clienti')"
check "login senza accesso: nessuna bolletta" 0 "$(as_user sconosciuto@test.it authenticated 'select count(*) from bollette')"
check "token senza email: nessuna bolletta" 0 "$(as_user '' authenticated 'select count(*) from bollette')"
check "anonimo: lettura negata" negato "$(if as_user x anon 'select count(*) from bollette' >/dev/null 2>&1; then echo ok; else echo negato; fi)"

[ "$FAIL" = 0 ] && echo "TUTTI I TEST RLS SUPERATI" || { echo "ALCUNI TEST RLS FALLITI"; exit 1; }
