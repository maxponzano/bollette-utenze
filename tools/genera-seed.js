// Genera supabase/02_seed_basilico.sql dai dati SEED_ENTRIES del cruscotto storico.
// Uso: node tools/genera-seed.js
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const html = fs.readFileSync(path.join(root, "archivio/cruscotto-basilico.html"), "utf8");
const m = html.match(/const SEED_ENTRIES = (\[[\s\S]*?\n\]);/);
if (!m) throw new Error("SEED_ENTRIES non trovato");
const entries = new Function(`return ${m[1]};`)();

// UUID fissi: rieseguire lo script non crea duplicati
const CLIENTE = "6b2f0c1e-0000-4000-8000-000000000001";
const LUCE = "6b2f0c1e-0000-4000-8000-0000000000e1";
const GAS = "6b2f0c1e-0000-4000-8000-0000000000a1";

const q = s => s == null ? "null" : `'${String(s).replace(/'/g, "''")}'`;
const n = v => Number(v).toFixed(2);

const rows = [];
for (const e of entries) {
  for (const [key, fid] of [["casaLuce", LUCE], ["casaGas", GAS]]) {
    const d = e[key];
    if (!d) continue;
    rows.push(`  (${q(fid)}, ${e.anno}, ${e.mese}, ${q(d.fornitore)}, ${n(d.consumo)}, ${n(d.costo)}, ${q(d.note || null)})`);
  }
}

const sql = `-- Dati iniziali: cliente Basilico (generato da tools/genera-seed.js, non modificare a mano)
-- Eseguire DOPO 01_schema.sql. Rieseguibile: aggiorna i valori senza duplicare.

insert into public.clienti (id, nome, indirizzo, note) values
  (${q(CLIENTE)}, 'Basilico di Bonino Alessandro', 'Via Corniglia 22, 16152 Genova', 'Mercato libero, FuturEnergy (Energia Pulita)')
on conflict (id) do update set nome = excluded.nome, indirizzo = excluded.indirizzo, note = excluded.note;

insert into public.forniture (id, cliente_id, tipo, codice, sede, potenza_kw, offerta) values
  (${q(LUCE)}, ${q(CLIENTE)}, 'luce', 'IT001E11676733', 'Via Corniglia 22', 20, 'ULTRAGREEN MF BASSA TENSIONE'),
  (${q(GAS)}, ${q(CLIENTE)}, 'gas', '03270037115412', 'Via Corniglia 22', null, 'ULTRAGREEN')
on conflict (id) do update set codice = excluded.codice, sede = excluded.sede, potenza_kw = excluded.potenza_kw, offerta = excluded.offerta;

insert into public.offerte (id, cliente_id, fornitore, tipo, ordine) values
  ('6b2f0c1e-0000-4000-8000-0000000000f1', ${q(CLIENTE)}, 'FuturEnergy (attuale)', 'luce', 1),
  ('6b2f0c1e-0000-4000-8000-0000000000f2', ${q(CLIENTE)}, 'Nuovo fornitore', 'luce', 2)
on conflict (id) do nothing;

insert into public.bollette (fornitura_id, anno, mese, fornitore, consumo, costo, note) values
${rows.join(",\n")}
on conflict (fornitura_id, anno, mese) do update
  set fornitore = excluded.fornitore, consumo = excluded.consumo, costo = excluded.costo, note = excluded.note;
`;

fs.writeFileSync(path.join(root, "supabase/02_seed_basilico.sql"), sql);
console.log(`Scritte ${rows.length} bollette (${entries.length} mesi) in supabase/02_seed_basilico.sql`);
