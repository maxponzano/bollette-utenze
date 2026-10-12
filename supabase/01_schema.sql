-- =====================================================================
-- Cruscotto Costi Energia — schema multi-cliente (Supabase / Postgres)
-- Eseguire UNA volta nel SQL Editor di Supabase.
--
-- Modello di accesso:
--   * admins   : email degli amministratori -> vedono e modificano tutto
--   * accessi  : email del cliente -> cliente_id che può vedere (sola lettura)
--   * chi non compare in nessuna delle due tabelle, anche se fa login, non vede nulla
-- L'identità è l'email del token di login (auth.jwt() ->> 'email').
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Tabelle
-- ---------------------------------------------------------------------
create table if not exists public.admins (
  email text primary key check (email = lower(email))
);

create table if not exists public.clienti (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null,
  indirizzo   text,
  note        text,
  created_at  timestamptz not null default now()
);

create table if not exists public.accessi (
  email      text not null check (email = lower(email)),
  cliente_id uuid not null references public.clienti(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (email, cliente_id)
);

-- Una fornitura = un punto di prelievo (POD luce o PDR gas) di un cliente
create table if not exists public.forniture (
  id          uuid primary key default gen_random_uuid(),
  cliente_id  uuid not null references public.clienti(id) on delete cascade,
  tipo        text not null check (tipo in ('luce','gas')),
  codice      text,                 -- POD / PDR
  sede        text,                 -- es. "Negozio Via Corniglia"
  potenza_kw  numeric(8,2),         -- solo luce
  offerta     text,                 -- nome offerta corrente
  attiva      boolean not null default true,
  created_at  timestamptz not null default now()
);
create index if not exists forniture_cliente_idx on public.forniture(cliente_id);

-- Una bolletta = competenza di un mese per una fornitura (importi IVA inclusa)
create table if not exists public.bollette (
  id           uuid primary key default gen_random_uuid(),
  fornitura_id uuid not null references public.forniture(id) on delete cascade,
  anno         int  not null check (anno between 2000 and 2100),
  mese         int  not null check (mese between 1 and 12),
  fornitore    text not null,
  consumo      numeric(12,2) not null,
  costo        numeric(12,2) not null,
  note         text,
  updated_at   timestamptz not null default now(),
  unique (fornitura_id, anno, mese)
);
create index if not exists bollette_fornitura_idx on public.bollette(fornitura_id);

-- Offerte salvate per il tab "Confronto offerte"
create table if not exists public.offerte (
  id          uuid primary key default gen_random_uuid(),
  cliente_id  uuid not null references public.clienti(id) on delete cascade,
  fornitore   text not null default '',
  tipo        text not null default 'luce' check (tipo in ('luce','gas')),
  prezzo      numeric(10,5),
  spread      numeric(10,5),
  fisso       numeric(10,2),
  ordine      int not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists offerte_cliente_idx on public.offerte(cliente_id);

-- ---------------------------------------------------------------------
-- Funzioni di controllo accesso
-- (security definer: leggono admins/accessi senza passare dalle loro RLS)
-- ---------------------------------------------------------------------
create or replace function public.email_corrente() returns text
language sql stable
as $$ select lower(coalesce(auth.jwt() ->> 'email', '')) $$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.admins where email = public.email_corrente() and email <> '') $$;

create or replace function public.puo_vedere(cid uuid) returns boolean
language sql stable security definer set search_path = public
as $$
  select public.is_admin()
      or exists (select 1 from public.accessi a
                 where a.cliente_id = cid and a.email = public.email_corrente() and a.email <> '')
$$;

create or replace function public.puo_vedere_fornitura(fid uuid) returns boolean
language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.forniture f where f.id = fid and public.puo_vedere(f.cliente_id)) $$;

-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------
alter table public.admins    enable row level security;
alter table public.clienti   enable row level security;
alter table public.accessi   enable row level security;
alter table public.forniture enable row level security;
alter table public.bollette  enable row level security;
alter table public.offerte   enable row level security;

-- Nessun accesso per utenti non autenticati
revoke all on public.admins, public.clienti, public.accessi, public.forniture, public.bollette, public.offerte from anon;

-- admins: ognuno vede solo la propria riga; si modifica solo dal SQL Editor
drop policy if exists admins_select on public.admins;
create policy admins_select on public.admins for select to authenticated
  using (email = public.email_corrente());

-- clienti
drop policy if exists clienti_select on public.clienti;
create policy clienti_select on public.clienti for select to authenticated
  using (public.puo_vedere(id));
drop policy if exists clienti_admin on public.clienti;
create policy clienti_admin on public.clienti for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- accessi: il cliente vede le proprie righe, l'admin tutte
drop policy if exists accessi_select on public.accessi;
create policy accessi_select on public.accessi for select to authenticated
  using (public.is_admin() or email = public.email_corrente());
drop policy if exists accessi_admin on public.accessi;
create policy accessi_admin on public.accessi for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- forniture
drop policy if exists forniture_select on public.forniture;
create policy forniture_select on public.forniture for select to authenticated
  using (public.puo_vedere(cliente_id));
drop policy if exists forniture_admin on public.forniture;
create policy forniture_admin on public.forniture for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- bollette
drop policy if exists bollette_select on public.bollette;
create policy bollette_select on public.bollette for select to authenticated
  using (public.puo_vedere_fornitura(fornitura_id));
drop policy if exists bollette_admin on public.bollette;
create policy bollette_admin on public.bollette for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- offerte
drop policy if exists offerte_select on public.offerte;
create policy offerte_select on public.offerte for select to authenticated
  using (public.puo_vedere(cliente_id));
drop policy if exists offerte_admin on public.offerte;
create policy offerte_admin on public.offerte for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- permessi espliciti: necessari se il progetto non espone automaticamente le nuove tabelle
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.clienti, public.accessi, public.forniture, public.bollette, public.offerte to authenticated;
grant select on public.admins to authenticated;
grant execute on function public.is_admin(), public.puo_vedere(uuid), public.puo_vedere_fornitura(uuid), public.email_corrente() to authenticated;

-- aggiorna updated_at a ogni modifica di una bolletta
create or replace function public.tocca_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at = now(); return new; end $$;
drop trigger if exists bollette_updated_at on public.bollette;
create trigger bollette_updated_at before update on public.bollette
  for each row execute function public.tocca_updated_at();
