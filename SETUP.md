# Messa in funzione del cruscotto multi-cliente

Tempo stimato: 20–30 minuti, una volta sola. Serve solo un browser.

## Come funziona

- **`index.html`** è il sito: una pagina sola, da pubblicare su un hosting statico gratuito.
- I **dati** (clienti, forniture, bollette, offerte) stanno in un database **Supabase**, non più nel file HTML.
- **Login senza password**: si inserisce l'email e si riceve un link.
- **Tu (admin)** vedi e modifichi tutti i clienti. **Ogni cliente** vede solo i propri dati, in sola lettura (Dashboard, Storico bollette, Confronto offerte).
  Il controllo è fatto dal database (Row Level Security), non dalla pagina: anche chi smanettasse col browser non può leggere i dati di altri.
- Le tue bollette personali sono semplicemente un altro "cliente" senza accessi esterni.

## 1. Crea il progetto Supabase

1. Vai su <https://supabase.com>, crea un account gratuito e poi **New project**.
2. Nome a piacere (es. `cruscotto-energia`), una password del database (conservala) e **Region: Central EU (Frankfurt)**, così i dati dei clienti restano in UE.
3. Attendi un paio di minuti che il progetto sia pronto.

## 2. Crea le tabelle e carica Basilico

Nel progetto: menu a sinistra **SQL Editor** > **New query**. Esegui in quest'ordine, incollando il contenuto di ogni file e premendo **Run**:

1. `supabase/01_schema.sql`: tabelle e regole di accesso.
2. `supabase/00_admin.sql`: **prima** sostituisci `la-tua-email@esempio.it` con la tua email, tutta in minuscolo.
3. `supabase/02_seed_basilico.sql`: il cliente Basilico con i 14 mesi di bollette (giu 2025 – lug 2026).

Controllo rapido: in **Table Editor** > `bollette` devi vedere 28 righe.

## 3. Collega la pagina al database

1. **Project Settings** > **API**: copia **Project URL** e la chiave **anon public**.
2. Apri `index.html` con un editor di testo, cerca il blocco `CONFIG` e incollale:
   ```js
   const CONFIG = {
     SUPABASE_URL: "https://xxxxxxxx.supabase.co",
     SUPABASE_ANON_KEY: "eyJhbGciOi...",
   };
   ```
   La chiave *anon* è pensata per stare in una pagina pubblica. **Non usare mai la chiave `service_role`**: quella aggira tutte le protezioni.

## 4. Pubblica il sito

Il login via email non funziona aprendo il file dal computer: serve un indirizzo web.

**Opzione semplice: Netlify Drop**
1. Vai su <https://app.netlify.com/drop> (account gratuito).
2. Trascina una cartella che contiene **solo** `index.html`.
3. Ottieni un indirizzo tipo `https://nome-a-caso.netlify.app`; dalle impostazioni puoi cambiarlo (es. `cruscotto-energia-max.netlify.app`).
4. Quando aggiorni `index.html`, trascina di nuovo la cartella nella sezione *Deploys* del sito.

**Alternativa: GitHub Pages**, se il repository è pubblico: Settings > Pages > Branch `main` / root.

## 5. Autorizza l'indirizzo del sito per il login

In Supabase: **Authentication** > **URL Configuration**:
- **Site URL**: l'indirizzo del sito (es. `https://cruscotto-energia-max.netlify.app`)
- **Redirect URLs**: aggiungi lo stesso indirizzo seguito da `/**`

Facoltativo ma consigliato: **Authentication** > **Email Templates** > *Magic Link*, traduci il testo in italiano (es. oggetto "Il tuo accesso al Cruscotto Energia").

## 6. Primo accesso

Apri il sito, inserisci la tua email e clicca il link che ricevi. In alto deve comparire il badge **ADMIN** e il tab **Gestione**.

## 7. Aggiungere un cliente

Tab **Gestione**:
1. **Crea cliente** (nome, indirizzo).
2. **Forniture**: aggiungi ogni POD (luce) e PDR (gas) con la sede; per la luce anche la potenza. Un cliente può avere più punti di fornitura: in dashboard vengono sommati (kWh con kWh, Smc con Smc) e con il filtro "Fornitura" li vedi uno per uno.
3. **Accessi**: inserisci l'email (o le email) del cliente.
4. Manda al cliente l'indirizzo del sito: entra con la sua email e vede solo i suoi dati.

Le bollette si inseriscono dal tab **Bollette**, scegliendo la fornitura. Una bolletta per fornitura e mese: se reinserisci lo stesso mese, sostituisce la precedente (dopo conferma).

## Da sapere

- **Email di accesso**: il servizio email incluso in Supabase ne invia poche all'ora ed è pensato per le prove. Con più clienti attivi configura un SMTP tuo (**Project Settings** > **Authentication** > *SMTP Settings*, es. Brevo o l'SMTP della tua casella).
- **Pausa del piano gratuito**: un progetto gratuito senza attività per 7 giorni viene messo in pausa. Si riattiva con un clic dalla dashboard Supabase, senza perdere i dati.
- **Backup**: da admin, *Scarica Excel* esporta il cliente selezionato (foglio mensile più dettaglio per fornitura). Supabase gratuito non fa backup automatici scaricabili: fai un export periodico.
- **Chi si registra senza essere abilitato** può fare login ma vede solo "Accesso non ancora abilitato", senza alcun dato.
- **Togliere l'accesso** a un cliente: Gestione > Accessi > *Revoca*. Vale dal successivo caricamento della pagina.

## Verifiche automatiche (per sviluppo)

```bash
npm install
npm test     # test dell'interfaccia (jsdom) + test delle regole di accesso su Postgres locale
```
