# CLAUDE.md — Cruscotto Costi Energia (multi-cliente)

Handoff per Claude Code. Leggi tutto questo file prima di toccare qualsiasi cosa.
Lingua di lavoro: **italiano**. Utente: Max, consulente PMI (metodologia OSM).

## 1. Obiettivo

Cruscotto **multi-cliente** dei costi energetici (luce e gas) per i clienti PMI di Max e per le sue bollette personali.
Max è **amministratore** (vede e modifica tutto); ogni cliente accede con la propria email e vede **solo i propri dati, in sola lettura**.

Primo cliente: **Basilico di Bonino Alessandro** (Via Corniglia 22, 16152 Genova), forniture FuturEnergy (Energia Pulita), mercato libero:
- Energia elettrica: POD IT001E11676733, 20 kW, offerta ULTRAGREEN MF BASSA TENSIONE
- Gas: PDR 03270037115412, offerta ULTRAGREEN

Scopo commerciale per Basilico: ottenere un prezzo bloccato (richiesta al broker) o cambiare fornitore.
La relazione `Relazione_FuturEnergy_Basilico.docx` va tenuta coerente con i dati.

## 2. File del progetto

| File | Ruolo |
| --- | --- |
| `index.html` | App single-file (HTML+CSS+JS vanilla). Contiene **solo codice e configurazione**, nessun dato. |
| `supabase/01_schema.sql` | Tabelle, funzioni e regole RLS. Rieseguibile. |
| `supabase/00_admin.sql` | Email degli amministratori (placeholder da sostituire). |
| `supabase/02_seed_basilico.sql` | Dati iniziali di Basilico, **generato** da `tools/genera-seed.js` partendo dall'archivio. Non editarlo a mano. |
| `archivio/cruscotto-basilico.html` | Vecchio cruscotto single-file con `SEED_ENTRIES` (giu 2025 – lug 2026). Solo riferimento storico, non più aggiornato. |
| `Relazione_FuturEnergy_Basilico.docx` | Relazione tecnica per il broker. |
| `SETUP.md` | Guida per Max: Supabase, pubblicazione, primi accessi. |
| `tests/test-app.js`, `tests/test-rls.sh` | Test interfaccia (jsdom + Supabase simulato) e test regole di accesso (Postgres locale). `npm test`. |

**La fonte di verità dei dati è il database Supabase di Max**, a cui Claude non ha accesso diretto.

## 3. Architettura

- Dipendenze da CDN: supabase-js 2.117.2 (jsdelivr) e SheetJS 0.18.5 (cdnjs). Nessun build.
- `CONFIG` in testa allo script: `SUPABASE_URL` e `SUPABASE_ANON_KEY` (chiave pubblica; mai la `service_role`).
- Login: magic link via email (`signInWithOtp`). `is_admin()` (RPC) decide il ruolo.
- Tabelle: `admins(email)`, `clienti`, `accessi(email, cliente_id)`, `forniture(cliente_id, tipo 'luce'|'gas', codice POD/PDR, sede, potenza_kw, offerta, attiva)`,
  `bollette(fornitura_id, anno, mese, fornitore, consumo, costo, note)` con **unique(fornitura_id, anno, mese)**, `offerte(cliente_id, ...)`.
- RLS: lettura se `is_admin()` o email in `accessi` per quel cliente; scrittura solo admin. Email confrontata in minuscolo dal JWT.
- Interfaccia: tab **Dashboard**, **Bollette**, **Confronto offerte** (tutti) e **Gestione** (solo admin: clienti, forniture, accessi).
  Barra contesto: selettore cliente (admin o chi ha più clienti) e filtro fornitura.
- `buildEntries()` converte le bollette nelle voci mensili storiche `{id:"anno-mese", anno, mese, casaLuce:{...}, casaGas:{...}}`,
  **sommando le forniture dello stesso tipo** (kWh con kWh, Smc con Smc). Tutta la dashboard (`renderDashboard`, grafici SVG, `commonMonths`, `rangeTotals`, `niceAxisTicks`) lavora su queste voci ed è copiata dall'originale: **le chiavi `casaLuce`/`casaGas` non vanno rinominate**.
- Cliente: niente form, niente modifica/elimina, niente import/export; in Confronto offerte può simulare valori ma non salva.
- Excel (solo admin): export del cliente selezionato (foglio "Dati Mensili" aggregato + "Dettaglio bollette");
  import del foglio "Dati Mensili" sull'unica fornitura attiva per tipo o su quella scelta nel filtro (upsert, con conferma).
- Tema scuro, variabili CSS in `:root` (ambra = energia elettrica, ciano = gas). Numeri in formato italiano con `fmtEUR`/`fmtNum` (no `Intl.NumberFormat`).

## 4. Dati Basilico al momento della migrazione (giugno 2025 – luglio 2026, 14 mesi)

Sono quelli caricati da `02_seed_basilico.sql` e verificati dai test. Costi IVA inclusa.

| Mese | EE kWh | EE € | Gas Smc | Gas € |
| --- | ---: | ---: | ---: | ---: |
| 2025-06 | 3.647,97 | 1.144,18 | 65 | 112,37 |
| 2025-07 | 3.682,89 | 1.119,08 | 61 | 95,06 |
| 2025-08 | 2.031,12 | 633,89 | 61 | 104,82 |
| 2025-09 | 3.297,36 | 973,50 | 70 | 106,74 |
| 2025-10 | 3.328,76 | 1.122,05 | 1.178 | 1.385,44 |
| 2025-11 | 3.197,00 | 1.083,02 | 471 | 561,61 |
| 2025-12 | 3.375,19 | 1.135,95 | 734 | 861,16 |
| 2026-01 | 2.253,51 | 782,24 | 1.034,58 | 1.822,18 |
| 2026-02 | 3.332,13 | 1.332,92 | 623,21 | 726,73 |
| 2026-03 | 3.548,56 | 1.370,39 | 474,82 | 666,34 |
| 2026-04 | 3.380,52 | 1.123,02 | 233,32 | 313,38 |
| 2026-05 | 3.590,33 | 1.172,65 | 67,54 | 109,58 |
| 2026-06 | 3.652,80 | 1.273,69 | 60,38 | 100,88 |
| 2026-07 | 3.514,61 | 1.399,50 | 56,28 | 102,98 |

Totali di controllo: EE 2025 (giu–dic) 22.560 kWh / 7.211,67 €; EE 2026 (gen–lug) 23.272 kWh / 8.454,41 €;
Gas 2025 (giu–dic) 2.640 Smc / 3.227,20 €; Gas 2026 (gen–lug) 2.550 Smc / 3.842,07 €.

## 5. Convenzioni sui dati (NON violare)

1. **Importi IVA inclusa** nel campo `costo`, sempre.
2. **Conguagli retroattivi**: restano nel mese della fattura, ma la `note` deve spiegarli (importo, Smc/kWh, mesi a cui si riferiscono, causa).
   - Gas ottobre 2025: 1.178 Smc / 1.385,44 € include un conguaglio di 790,93 € (848 Smc) per mag–set 2025. Consumo reale del mese: 330 Smc (~594,51 €).
   - Gas gennaio 2026: mese diviso tra due intestatari. 1–15/01 Cantaboni Cinzia (600,69 Smc, 1.170,46 €, include conguagli nov–dic per 372,66 €); 16–31/01 Bonino Alessandro (433,89 Smc, 651,72 €, include voltura una tantum 117,94 €). Le due fatture sono **sommate in un'unica voce** con nota dettagliata.
3. **Cambio intestatario a metà mese** → una sola voce, importi sommati, nota dettagliata.
4. **Una bolletta per fornitura e mese** (vincolo unico nel database): un secondo inserimento sostituisce il primo, quindi più fatture dello stesso mese sulla stessa fornitura vanno sommate prima.
5. **kWh e Smc non si sommano mai** in modalità consumi (unità incompatibili).
6. **Confronti anno su anno**: usare solo i mesi presenti in entrambi gli anni (`commonMonths`), mai totali di anni con copertura diversa.
7. **"Ultimi 12 mesi"**: totale reale se i mesi disponibili sono ≥ 12; stima annualizzata solo sotto i 12.
8. **Formato numeri italiano** (1.234,56 €). Non usare `Intl.NumberFormat` per le migliaia: è inaffidabile qui, usare la formattazione manuale con regex (`fmtEUR`, `fmtNum`).
9. (Basilico) Dalla fattura di luglio 2025 in poi l'offerta EE è ULTRAGREEN FIX BASSA TENSIONE (fino a dic 2025), poi ULTRAGREEN MF BASSA TENSIONE (da gen 2026). Riporta nella nota il nome offerta come scritto in fattura.
10. Nota standard: `"<Offerta> — fattura <numero> del <data>"`.

## 6. Workflow: aggiungere nuove bollette (compito principale)

1. Max fornisce le bollette (PDF o dati) e dice a quale cliente si riferiscono. Per ogni fattura ricava: fornitura (POD/PDR), periodo di competenza, consumo (kWh o Smc), totale IVA inclusa, numero e data fattura, nome offerta, intestatario.
2. **Prima di scrivere**, mostra a Max una tabella riepilogativa dei valori estratti e segnala: conguagli, letture stimate vs reali, ricalcoli, oneri una tantum, cambi di intestatario. Chiedi conferma sui casi dubbi.
3. Consegna i dati in uno di questi modi, a scelta di Max:
   - **file SQL** `supabase/bollette/AAAA-MM_<cliente>.sql` da eseguire nel SQL Editor, con upsert che risolve la fornitura dal codice:
     ```sql
     insert into public.bollette (fornitura_id, anno, mese, fornitore, consumo, costo, note)
     select f.id, 2026, 8, 'FuturEnergy (Energia Pulita)', 0.00, 0.00, 'Offerta … — fattura … del GG/MM/AAAA'
     from public.forniture f where f.codice = 'IT001E11676733'
     on conflict (fornitura_id, anno, mese) do update
       set fornitore = excluded.fornitore, consumo = excluded.consumo, costo = excluded.costo, note = excluded.note;
     ```
   - oppure una tabella pronta da ricopiare nel form del tab Bollette.
4. Se un importo include elementi non di competenza del mese, spiegalo in `note` (vedi §5.2). Con cambio intestatario a metà mese sulla **stessa** fornitura: una sola bolletta, importi sommati (§5.3).
5. Aggiorna la relazione `.docx` solo se Max lo chiede; se lo fa, ricalcola da zero tabelle e percentuali (vedi §8).
6. Riepilogo finale breve: mesi aggiunti, variazione rispetto allo stesso mese dell'anno prima, eventuali anomalie.

## 7. Validazione

- Dopo ogni modifica a `index.html` o agli SQL: `npm install` (una volta) e `npm test`.
  - `tests/test-app.js`: carica `index.html` in jsdom con Supabase simulato, verifica admin / cliente / non abilitato, inserimento, modifica, più POD, export, e i totali di §4.
  - `tests/test-rls.sh`: avvia un Postgres locale, applica gli SQL e verifica che ogni ruolo veda e possa scrivere solo ciò che deve.
- Se cambi lo schema, aggiorna anche il mock in `tests/test-app.js` e i casi in `tests/test-rls.sh`.
- Non modificare valori già presenti senza dirlo a Max.

## 8. Formule per la relazione e i KPI

- Prezzo medio unitario = costo totale / consumo (EE in €/kWh, gas in €/Smc), calcolato su mesi confrontabili.
- Variazione = (valore nuovo − valore anno prima) / valore anno prima, sullo **stesso mese** o sugli stessi mesi.
- Valori già in relazione (da rivedere se arrivano nuovi mesi): EE prezzo medio +13,6% (0,32 → 0,36 €/kWh); gas +23,2% (1,222 → 1,507 €/Smc); luglio 2026 EE +25,1% sull'importo e +31,0% sul prezzo unitario (0,304 → 0,398 €/kWh); giugno 2026 +11,3% importo, +11,2% prezzo; giugno→luglio 2026 +14% sul prezzo.
- Benchmark di mercato citati (rilevati ad agosto 2026, da riverificare): Enel Business Super Luce 0,161 €/kWh + 15 €/POD/mese, 24 mesi, 3–25 kW; Enel Fix Business Gas ~0,56 €/Smc + 15 €/PDR/mese, 24 mesi. Solo componente energia, IVA e imposte escluse. **Non sono confrontabili 1:1 col prezzo medio di fattura** (che include tutte le componenti): non dirlo come se fossero omogenei.
- Criticità da mantenere in relazione: conguagli gas ripetuti (790,93 € e 372,66 €), picchi di potenza 23–25 kW contro 20 kW contrattuali, spread rispetto a PUN/PSV, voltura 117,94 €.

## 9. Regole di comportamento

- Rispondi in italiano.
- Fai qualche domanda di chiarimento prima di iniziare un compito non banale (compiti e risultati attesi).
- Modifiche mirate a `index.html`; non riscriverlo se basta un edit. Deve restare un file unico funzionante (dipendenze solo da CDN: supabase-js e SheetJS).
- **Sicurezza**: ogni nuova tabella va creata con RLS attiva e policy coerenti (lettura `puo_vedere`, scrittura `is_admin`), con test in `tests/test-rls.sh`. Mai nascondere dati solo lato interfaccia. Mai chiavi `service_role` nel codice o nel repo.
- Non inserire nel repo dati personali dei clienti oltre a quelli già presenti (email reali di accesso stanno solo nel database).
- Se un dato in fattura è ambiguo o mancante, chiedi: non inventare.
- Non rinominare le chiavi `casaLuce`/`casaGas`.

## 10. Prima mossa in una nuova sessione

1. Leggi questo file, `index.html` e gli SQL in `supabase/`.
2. Esegui `npm test` per verificare che tutto sia integro.
3. Chiedi a Max quali bollette vuole inserire (cliente, mesi, formato dei documenti) e se aggiornare anche la relazione.
