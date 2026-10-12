# CLAUDE.md — Cruscotto Costi Energia · Basilico

Handoff per Claude Code. Leggi tutto questo file prima di toccare qualsiasi cosa.
Lingua di lavoro: **italiano**. Utente: Max, consulente PMI (metodologia OSM).

## 1. Obiettivo

Tenere aggiornato il cruscotto dei costi energetici del cliente **Basilico di Bonino Alessandro**
(Via Corniglia 22, 16152 Genova) con le **nuove bollette** man mano che arrivano,
e mantenere coerente la relazione per il broker.

Forniture, entrambe con FuturEnergy (Energia Pulita), mercato libero:
- Energia elettrica: POD IT001E11676733, 20 kW, offerta ULTRAGREEN MF BASSA TENSIONE
- Gas: PDR 03270037115412, offerta ULTRAGREEN

Scopo commerciale: ottenere un prezzo bloccato (richiesta al broker) o cambiare fornitore.

## 2. File del progetto (devono stare nella stessa cartella)

| File | Ruolo |
| --- | --- |
| `cruscotto-basilico.html` | Dashboard single-file. Contiene codice **e dati** (array `SEED_ENTRIES`). |
| `Relazione_FuturEnergy_Basilico.docx` | Relazione tecnica per il broker, con KPI calcolati dai dati. |
| `CLAUDE.md` | Questo file. |

Se `cruscotto-basilico.html` manca, chiedi a Max di fornirlo: non ricostruirlo a memoria.
Lavora sempre sul file reale presente in cartella, mai su versioni ipotetiche.

## 3. Architettura del cruscotto

- HTML + CSS + JS vanilla, nessun framework. Unica dipendenza: SheetJS (xlsx 0.18.5) da cdnjs, per import/export Excel.
- Tema scuro, variabili CSS in `:root` (ambra = energia elettrica, ciano = gas).
- Grafici SVG disegnati a mano (`lineChartSVG`, `barChartSVG`, `yoyChartSVG`, `dualAxisChartSVG`), assi con tacche "rotonde" (`niceAxisTicks`).
- Stato globale `state`: `entries`, `tab`, `form`, `offers`, `compare`, `metric` ("costo" | "consumo").
- Tre tab: **Dashboard**, **Bollette** (form di inserimento + storico), **Confronto offerte**.
- Utenze in `UTENZE`: chiavi `casaLuce` (kWh, Energia Elettrica) e `casaGas` (Smc, Gas). **Le chiavi storiche `casaLuce`/`casaGas` non vanno rinominate** (l'import Excel le usa come fallback).
- Funzioni chiave: `renderDashboard`, `renderBollette`, `renderConfronto`, `upsertEntry`, `exportExcel`, `importExcel`, `commonMonths`, `rangeTotals`.

### Struttura di una voce di `SEED_ENTRIES`

```js
{ id:"2026-8", anno:2026, mese:8,
  casaLuce:{ fornitore:"FuturEnergy (Energia Pulita)", consumo:0.00, costo:0.00, note:"Offerta ULTRAGREEN MF BASSA TENSIONE — fattura EE… del GG/MM/AAAA" },
  casaGas:{ fornitore:"FuturEnergy (Energia Pulita)", consumo:0.00, costo:0.00, note:"Offerta ULTRAGREEN — fattura GN… del GG/MM/AAAA" } }
```

`id` = `"anno-mese"` (mese senza zero iniziale). Una voce per mese; `casaLuce` e `casaGas` sono sotto-oggetti opzionali.

## 4. Dati attuali (giugno 2025 – luglio 2026, 14 mesi)

Usali per verificare che il file non sia stato alterato. Costi IVA inclusa.

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
4. Se aggiungi un'utenza a un mese già esistente, **estendi la voce esistente**, non crearne una duplicata.
5. **kWh e Smc non si sommano mai** in modalità consumi (unità incompatibili).
6. **Confronti anno su anno**: usare solo i mesi presenti in entrambi gli anni (`commonMonths`), mai totali di anni con copertura diversa.
7. **"Ultimi 12 mesi"**: totale reale se i mesi disponibili sono ≥ 12; stima annualizzata solo sotto i 12.
8. **Formato numeri italiano** (1.234,56 €). Non usare `Intl.NumberFormat` per le migliaia: è inaffidabile qui, usare la formattazione manuale con regex (`fmtEUR`, `fmtNum`).
9. Dalla fattura di luglio 2025 in poi l'offerta EE è ULTRAGREEN FIX BASSA TENSIONE (fino a dic 2025), poi ULTRAGREEN MF BASSA TENSIONE (da gen 2026). Riporta nella nota il nome offerta come scritto in fattura.
10. Nota standard: `"<Offerta> — fattura <numero> del <data>"`.

## 6. Workflow: aggiungere nuove bollette (compito principale)

1. Max fornisce le bollette (PDF o dati). Per ogni fattura ricava: periodo di competenza, consumo (kWh o Smc), totale fattura IVA inclusa, numero e data fattura, nome offerta, intestatario.
2. **Prima di scrivere**, mostra a Max una tabella riepilogativa dei valori estratti e segnala: conguagli, letture stimate vs reali, ricalcoli, oneri una tantum, cambi di intestatario. Chiedi conferma sui casi dubbi.
3. Aggiungi le voci a `SEED_ENTRIES` con `Edit` su un'ancora univoca (il testo completo dell'ultima voce esistente). Mantieni l'ordine cronologico.
4. Se un importo include elementi non di competenza del mese, spiegalo in `note` (vedi §5.2).
5. Valida (vedi §7).
6. Aggiorna la relazione `.docx` solo se Max lo chiede; se lo fa, ricalcola da zero tabelle e percentuali (vedi §8) e controlla che testo e numeri restino coerenti.
7. Riepilogo finale breve: mesi aggiunti, variazione rispetto allo stesso mese dell'anno prima, eventuali anomalie.

## 7. Validazione

- Controllo sintassi: `node --check` su uno script estratto, oppure render completo con jsdom: `new JSDOM(html, { runScripts: "dangerously" })` con stub di `XLSX`, attesa di ~500 ms, poi verifica che `#main.innerHTML` non sia vuoto e che non ci siano errori in console.
- Verifica dei dati: ricalcola i totali di §4 estesi ai nuovi mesi e confrontali con quelli mostrati dalla dashboard.
- Non modificare il file in modo da cambiare valori già presenti senza dirlo a Max.

## 8. Formule per la relazione e i KPI

- Prezzo medio unitario = costo totale / consumo (EE in €/kWh, gas in €/Smc), calcolato su mesi confrontabili.
- Variazione = (valore nuovo − valore anno prima) / valore anno prima, sullo **stesso mese** o sugli stessi mesi.
- Valori già in relazione (da rivedere se arrivano nuovi mesi): EE prezzo medio +13,6% (0,32 → 0,36 €/kWh); gas +23,2% (1,222 → 1,507 €/Smc); luglio 2026 EE +25,1% sull'importo e +31,0% sul prezzo unitario (0,304 → 0,398 €/kWh); giugno 2026 +11,3% importo, +11,2% prezzo; giugno→luglio 2026 +14% sul prezzo.
- Benchmark di mercato citati (rilevati ad agosto 2026, da riverificare): Enel Business Super Luce 0,161 €/kWh + 15 €/POD/mese, 24 mesi, 3–25 kW; Enel Fix Business Gas ~0,56 €/Smc + 15 €/PDR/mese, 24 mesi. Solo componente energia, IVA e imposte escluse. **Non sono confrontabili 1:1 col prezzo medio di fattura** (che include tutte le componenti): non dirlo come se fossero omogenei.
- Criticità da mantenere in relazione: conguagli gas ripetuti (790,93 € e 372,66 €), picchi di potenza 23–25 kW contro 20 kW contrattuali, spread rispetto a PUN/PSV, voltura 117,94 €.

## 9. Regole di comportamento

- Rispondi in italiano.
- Fai qualche domanda di chiarimento prima di iniziare un compito non banale (compiti e risultati attesi).
- Lavora su una copia o con edit mirati; non riscrivere l'intero HTML se basta aggiungere voci.
- Riconsegna sempre il dashboard come **file HTML completo e funzionante**, autonomo (nessuna dipendenza oltre a SheetJS da CDN).
- Se un dato in fattura è ambiguo o mancante, chiedi: non inventare.
- Non toccare le chiavi `casaLuce`/`casaGas` né la struttura del form senza motivo esplicito.

## 10. Prima mossa in una nuova sessione

1. Leggi questo file e `cruscotto-basilico.html`.
2. Conferma che i totali in §4 corrispondono ai dati nel file.
3. Chiedi a Max quali bollette vuole inserire (mesi, formato dei documenti) e se aggiornare anche la relazione.
