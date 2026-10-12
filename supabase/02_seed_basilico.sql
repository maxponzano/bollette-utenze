-- Dati iniziali: cliente Basilico (generato da tools/genera-seed.js, non modificare a mano)
-- Eseguire DOPO 01_schema.sql. Rieseguibile: aggiorna i valori senza duplicare.

insert into public.clienti (id, nome, indirizzo, note) values
  ('6b2f0c1e-0000-4000-8000-000000000001', 'Basilico di Bonino Alessandro', 'Via Corniglia 22, 16152 Genova', 'Mercato libero, FuturEnergy (Energia Pulita)')
on conflict (id) do update set nome = excluded.nome, indirizzo = excluded.indirizzo, note = excluded.note;

insert into public.forniture (id, cliente_id, tipo, codice, sede, potenza_kw, offerta) values
  ('6b2f0c1e-0000-4000-8000-0000000000e1', '6b2f0c1e-0000-4000-8000-000000000001', 'luce', 'IT001E11676733', 'Via Corniglia 22', 20, 'ULTRAGREEN MF BASSA TENSIONE'),
  ('6b2f0c1e-0000-4000-8000-0000000000a1', '6b2f0c1e-0000-4000-8000-000000000001', 'gas', '03270037115412', 'Via Corniglia 22', null, 'ULTRAGREEN')
on conflict (id) do update set codice = excluded.codice, sede = excluded.sede, potenza_kw = excluded.potenza_kw, offerta = excluded.offerta;

insert into public.offerte (id, cliente_id, fornitore, tipo, ordine) values
  ('6b2f0c1e-0000-4000-8000-0000000000f1', '6b2f0c1e-0000-4000-8000-000000000001', 'FuturEnergy (attuale)', 'luce', 1),
  ('6b2f0c1e-0000-4000-8000-0000000000f2', '6b2f0c1e-0000-4000-8000-000000000001', 'Nuovo fornitore', 'luce', 2)
on conflict (id) do nothing;

insert into public.bollette (fornitura_id, anno, mese, fornitore, consumo, costo, note) values
  ('6b2f0c1e-0000-4000-8000-0000000000e1', 2025, 6, 'FuturEnergy (Energia Pulita)', 3647.97, 1144.18, 'Offerta PMI SILVER MF — fattura EE00489769/2025 del 10/07/2025'),
  ('6b2f0c1e-0000-4000-8000-0000000000a1', 2025, 6, 'FuturEnergy (Energia Pulita)', 65.00, 112.37, 'Offerta PMI GAS VARIABILE PSV — cliente Basilico di Cantaboni Cinzia — fattura GN00264087/2025 del 10/07/2025'),
  ('6b2f0c1e-0000-4000-8000-0000000000e1', 2025, 7, 'FuturEnergy (Energia Pulita)', 3682.89, 1119.08, 'Offerta ULTRAGREEN FIX BASSA TENSIONE — fattura EE00566615/2025 del 07/08/2025'),
  ('6b2f0c1e-0000-4000-8000-0000000000a1', 2025, 7, 'FuturEnergy (Energia Pulita)', 61.00, 95.06, 'Offerta ULTRAGREEN FIX — cliente Basilico di Cantaboni Cinzia — fattura GN00304582/2025 del 07/08/2025'),
  ('6b2f0c1e-0000-4000-8000-0000000000e1', 2025, 8, 'FuturEnergy (Energia Pulita)', 2031.12, 633.89, 'Offerta ULTRAGREEN FIX BASSA TENSIONE — fattura EE00646658/2025 del 10/09/2025'),
  ('6b2f0c1e-0000-4000-8000-0000000000a1', 2025, 8, 'FuturEnergy (Energia Pulita)', 61.00, 104.82, 'Offerta ULTRAGREEN FIX — include piccolo ricalcolo di +6,98€ — fattura GN00387521/2025 del 30/09/2025'),
  ('6b2f0c1e-0000-4000-8000-0000000000e1', 2025, 9, 'FuturEnergy (Energia Pulita)', 3297.36, 973.50, 'Offerta ULTRAGREEN FIX BASSA TENSIONE — fattura EE00727896/2025 del 07/10/2025'),
  ('6b2f0c1e-0000-4000-8000-0000000000a1', 2025, 9, 'FuturEnergy (Energia Pulita)', 70.00, 106.74, 'Offerta ULTRAGREEN FIX — fattura GN00389922/2025 del 07/10/2025'),
  ('6b2f0c1e-0000-4000-8000-0000000000e1', 2025, 10, 'FuturEnergy (Energia Pulita)', 3328.76, 1122.05, 'Offerta ULTRAGREEN FIX BASSA TENSIONE — fattura EE00806894/2025 del 07/11/2025'),
  ('6b2f0c1e-0000-4000-8000-0000000000a1', 2025, 10, 'FuturEnergy (Energia Pulita)', 1178.00, 1385.44, 'Offerta ULTRAGREEN FIX — fattura GN00432592/2025 del 07/11/2025. Importo elevato perché include un grosso conguaglio retroattivo di 790,93€ (848 Smc) per mag-set 2025: le letture stimate dei mesi precedenti erano molto più basse della lettura reale rilevata con l''autolettura del 21/10/2025. Il consumo di ottobre vero e proprio è 330 Smc (~594,51€ al netto del conguaglio).'),
  ('6b2f0c1e-0000-4000-8000-0000000000e1', 2025, 11, 'FuturEnergy (Energia Pulita)', 3197.00, 1083.02, 'Offerta ULTRAGREEN FIX BASSA TENSIONE — fattura EE00887025/2025 del 05/12/2025'),
  ('6b2f0c1e-0000-4000-8000-0000000000a1', 2025, 11, 'FuturEnergy (Energia Pulita)', 471.00, 561.61, 'Offerta ULTRAGREEN FIX — fattura GN00474823/2025 del 05/12/2025'),
  ('6b2f0c1e-0000-4000-8000-0000000000e1', 2025, 12, 'FuturEnergy (Energia Pulita)', 3375.19, 1135.95, 'Offerta ULTRAGREEN FIX BASSA TENSIONE — fattura EE00001243/2026 del 07/01/2026'),
  ('6b2f0c1e-0000-4000-8000-0000000000a1', 2025, 12, 'FuturEnergy (Energia Pulita)', 734.00, 861.16, 'Offerta ULTRAGREEN FIX — cliente Basilico di Cantaboni Cinzia — fattura GN00000388/2026 del 07/01/2026'),
  ('6b2f0c1e-0000-4000-8000-0000000000e1', 2026, 1, 'FuturEnergy (Energia Pulita)', 2253.51, 782.24, 'Offerta ULTRAGREEN MF BASSA TENSIONE — fattura EE00105397/2026 del 06/02/2026'),
  ('6b2f0c1e-0000-4000-8000-0000000000a1', 2026, 1, 'FuturEnergy (Energia Pulita)', 1034.58, 1822.18, 'Mese diviso tra due intestatari per cambio cliente il 16/01: 1-15/01 Cantaboni Cinzia, 600,69 Smc, 1.170,46€ (include conguagli di ricalcolo nov-dic 2025 per 372,66€ — fattura GN00041777/2026); 16-31/01 Bonino Alessandro, 433,89 Smc, 651,72€ (include oneri una tantum di voltura per 117,94€ — fattura GN00041624/2026), entrambe del 06/02/2026'),
  ('6b2f0c1e-0000-4000-8000-0000000000e1', 2026, 2, 'FuturEnergy (Energia Pulita)', 3332.13, 1332.92, 'Offerta ULTRAGREEN MF BASSA TENSIONE — fattura EE00183301/2026 del 06/03/2026'),
  ('6b2f0c1e-0000-4000-8000-0000000000a1', 2026, 2, 'FuturEnergy (Energia Pulita)', 623.21, 726.73, 'Offerta ULTRAGREEN — include ricalcolo di -0,08€ per lettura precedentemente errata — fattura GN00097880/2026 del 06/03/2026'),
  ('6b2f0c1e-0000-4000-8000-0000000000e1', 2026, 3, 'FuturEnergy (Energia Pulita)', 3548.56, 1370.39, 'Offerta ULTRAGREEN MF BASSA TENSIONE — fattura EE00263349/2026 del 07/04/2026'),
  ('6b2f0c1e-0000-4000-8000-0000000000a1', 2026, 3, 'FuturEnergy (Energia Pulita)', 474.82, 666.34, 'Offerta ULTRAGREEN — fattura GN00145994/2026 del 07/04/2026'),
  ('6b2f0c1e-0000-4000-8000-0000000000e1', 2026, 4, 'FuturEnergy (Energia Pulita)', 3380.52, 1123.02, 'Offerta ULTRAGREEN MF BASSA TENSIONE — fattura EE00342015/2026 del 07/05/2026'),
  ('6b2f0c1e-0000-4000-8000-0000000000a1', 2026, 4, 'FuturEnergy (Energia Pulita)', 233.32, 313.38, 'Offerta ULTRAGREEN — fattura GN00194345/2026 del 07/05/2026'),
  ('6b2f0c1e-0000-4000-8000-0000000000e1', 2026, 5, 'FuturEnergy (Energia Pulita)', 3590.33, 1172.65, 'Offerta ULTRAGREEN MF BASSA TENSIONE — fattura EE00418821/2026 del 08/06/2026'),
  ('6b2f0c1e-0000-4000-8000-0000000000a1', 2026, 5, 'FuturEnergy (Energia Pulita)', 67.54, 109.58, 'Offerta ULTRAGREEN — fattura GN00241183/2026 del 08/06/2026'),
  ('6b2f0c1e-0000-4000-8000-0000000000e1', 2026, 6, 'FuturEnergy (Energia Pulita)', 3652.80, 1273.69, 'Offerta ULTRAGREEN MF BASSA TENSIONE — fattura EE00495245/2026 del 07/07/2026'),
  ('6b2f0c1e-0000-4000-8000-0000000000a1', 2026, 6, 'FuturEnergy (Energia Pulita)', 60.38, 100.88, 'Offerta ULTRAGREEN — intestazione ceduta a Basilico di Bonino Alessandro (nuova fornitura dal 16/01/2026) — fattura GN00288138/2026 del 07/07/2026'),
  ('6b2f0c1e-0000-4000-8000-0000000000e1', 2026, 7, 'FuturEnergy (Energia Pulita)', 3514.61, 1399.50, 'Offerta ULTRAGREEN MF BASSA TENSIONE — fattura EE00573904/2026 del 07/08/2026'),
  ('6b2f0c1e-0000-4000-8000-0000000000a1', 2026, 7, 'FuturEnergy (Energia Pulita)', 56.28, 102.98, 'Offerta ULTRAGREEN — cliente Basilico di Bonino Alessandro — fattura GN00335115/2026 del 07/08/2026')
on conflict (fornitura_id, anno, mese) do update
  set fornitore = excluded.fornitore, consumo = excluded.consumo, costo = excluded.costo, note = excluded.note;
