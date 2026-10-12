// Test dell'app index.html con jsdom e un Supabase simulato in memoria.
// Le regole di accesso reali sono verificate da tests/test-rls.sh: qui il mock
// le imita solo per controllare cosa mostra l'interfaccia ai diversi ruoli.
// Uso: node tests/test-app.js
const fs = require("fs");
const path = require("path");
const { JSDOM } = require("jsdom");

const ROOT = path.join(__dirname, "..");
const HTML = fs.readFileSync(path.join(ROOT, "index.html"), "utf8")
  .replace('SUPABASE_URL: ""', 'SUPABASE_URL: " https://test.supabase.co/rest/v1/ "')
  .replace('SUPABASE_ANON_KEY: ""', 'SUPABASE_ANON_KEY: "test-key"');

// ---- dati iniziali: gli stessi del seed SQL (Basilico) ----
function seedDb() {
  const src = fs.readFileSync(path.join(ROOT, "archivio/cruscotto-basilico.html"), "utf8");
  const entries = new Function(`return ${src.match(/const SEED_ENTRIES = (\[[\s\S]*?\n\]);/)[1]};`)();
  const C = "cli-basilico", L = "forn-luce", G = "forn-gas";
  const db = {
    admins: [{ email: "admin@test.it" }],
    clienti: [{ id: C, nome: "Basilico di Bonino Alessandro", indirizzo: "Via Corniglia 22, 16152 Genova" },
              { id: "cli-altro", nome: "Altro Cliente", indirizzo: null }],
    accessi: [{ email: "basilico@test.it", cliente_id: C }],
    forniture: [
      { id: L, cliente_id: C, tipo: "luce", codice: "IT001E11676733", sede: "Via Corniglia 22", potenza_kw: 20, offerta: "ULTRAGREEN MF", attiva: true, created_at: "1" },
      { id: G, cliente_id: C, tipo: "gas", codice: "03270037115412", sede: "Via Corniglia 22", potenza_kw: null, offerta: "ULTRAGREEN", attiva: true, created_at: "2" },
      { id: "forn-altro", cliente_id: "cli-altro", tipo: "luce", codice: "POD-X", sede: "X", attiva: true, created_at: "3" },
    ],
    bollette: [],
    offerte: [{ id: "off-1", cliente_id: C, fornitore: "FuturEnergy (attuale)", tipo: "luce", prezzo: null, spread: null, fisso: null, ordine: 1 }],
  };
  let n = 0;
  for (const e of entries) for (const [k, fid] of [["casaLuce", L], ["casaGas", G]]) {
    const d = e[k]; if (!d) continue;
    db.bollette.push({ id: "b" + (++n), fornitura_id: fid, anno: e.anno, mese: e.mese, fornitore: d.fornitore, consumo: d.consumo, costo: d.costo, note: d.note });
  }
  db.bollette.push({ id: "b-altro", fornitura_id: "forn-altro", anno: 2026, mese: 1, fornitore: "Y", consumo: 1, costo: 999, note: "segreto" });
  return db;
}

// ---- mock minimale di supabase-js con "RLS" in memoria ----
function makeSupabase(db, email) {
  let uid = 0;
  const isAdmin = () => db.admins.some(a => a.email === email);
  const clientiVisibili = () => isAdmin() ? db.clienti.map(c => c.id) : db.accessi.filter(a => a.email === email).map(a => a.cliente_id);
  const visibile = (table, row) => {
    if (isAdmin()) return true;
    const cv = clientiVisibili();
    if (table === "clienti") return cv.includes(row.id);
    if (table === "accessi") return row.email === email;
    if (table === "forniture" || table === "offerte") return cv.includes(row.cliente_id);
    if (table === "bollette") { const f = db.forniture.find(x => x.id === row.fornitura_id); return f && cv.includes(f.cliente_id); }
    return false;
  };
  const calls = [];
  function builder(table) {
    const st = { op: "select", filters: [], orders: [], range: null, payload: null, single: false, onConflict: null, ret: false };
    const b = {
      select() { if (st.op !== "select") st.ret = true; return b; },
      insert(p) { st.op = "insert"; st.payload = p; return b; },
      update(p) { st.op = "update"; st.payload = p; return b; },
      upsert(p, o) { st.op = "upsert"; st.payload = p; st.onConflict = o && o.onConflict; return b; },
      delete() { st.op = "delete"; return b; },
      eq(c, v) { st.filters.push(r => r[c] === v); return b; },
      in(c, vs) { st.filters.push(r => vs.includes(r[c])); return b; },
      order(c) { st.orders.push(c); return b; },
      range(a, z) { st.range = [a, z]; return b; },
      single() { st.single = true; return b; },
      then(res, rej) { return Promise.resolve(exec()).then(res, rej); },
    };
    function exec() {
      calls.push({ table, op: st.op });
      const rows = db[table];
      const match = r => st.filters.every(f => f(r));
      if (st.op === "select") {
        let out = rows.filter(r => visibile(table, r) && match(r));
        for (const c of [...st.orders].reverse()) out = [...out].sort((a, b) => (a[c] > b[c]) - (a[c] < b[c]));
        if (st.range) out = out.slice(st.range[0], st.range[1] + 1);
        return { data: out.map(r => ({ ...r })), error: null };
      }
      if (!isAdmin()) return { data: null, error: { message: "new row violates row-level security policy" } };
      if (st.op === "delete") { db[table] = rows.filter(r => !match(r)); if (table === "clienti") cascade(); return { data: null, error: null }; }
      if (st.op === "update") { rows.filter(match).forEach(r => Object.assign(r, st.payload)); return { data: null, error: null }; }
      const list = Array.isArray(st.payload) ? st.payload : [st.payload];
      const inserted = [];
      for (const p of list) {
        if (table === "accessi" && rows.some(r => r.email === p.email && r.cliente_id === p.cliente_id)) return { data: null, error: { code: "23505", message: "duplicate" } };
        const keys = st.onConflict ? st.onConflict.split(",") : null;
        const ex = keys && rows.find(r => keys.every(k => r[k] === p[k]));
        if (ex) { Object.assign(ex, p); inserted.push(ex); }
        else { const row = { id: `${table}-new-${++uid}`, created_at: String(100 + uid), ...p }; rows.push(row); inserted.push(row); }
      }
      return { data: st.single ? { ...inserted[0] } : inserted, error: null };
    }
    function cascade() {
      const cids = new Set(db.clienti.map(c => c.id));
      db.forniture = db.forniture.filter(f => cids.has(f.cliente_id));
      const fids = new Set(db.forniture.map(f => f.id));
      db.bollette = db.bollette.filter(b => fids.has(b.fornitura_id));
    }
    return b;
  }
  let listener = null;
  const session = email ? { user: { id: "u-" + email, email } } : null;
  return {
    calls,
    otp: [],
    createClient(url) { this.url = url; return this; },
    from: builder,
    rpc: async (fn) => fn === "is_admin" ? { data: isAdmin(), error: null } : { data: null, error: { message: "rpc?" } },
    auth: {
      onAuthStateChange(cb) { listener = cb; setTimeout(() => cb("INITIAL_SESSION", session), 0); return { data: { subscription: { unsubscribe() {} } } }; },
      signInWithOtp: async ({ email: e }) => { mock.otp.push(e); return { error: null }; },
      signOut: async () => { listener && listener("SIGNED_OUT", null); return { error: null }; },
    },
  };
  var mock;
}

async function boot(db, email, opts = {}) {
  const errors = [];
  const sb = makeSupabase(db, email);
  sb.auth.signInWithOtp = async ({ email: e }) => { sb.otp.push(e); return { error: null }; };
  const html = opts.noConfig ? fs.readFileSync(path.join(ROOT, "index.html"), "utf8") : HTML;
  const dom = new JSDOM(html, {
    runScripts: "dangerously", url: "https://cruscotto.example/",
    beforeParse(w) {
      w.supabase = sb;
      w.XLSX = { utils: { json_to_sheet: r => ({ rows: r }), book_new: () => ({ sheets: [] }), book_append_sheet: (wb, ws, n) => wb.sheets.push(n) }, writeFile: (wb, n) => { w.__written = { wb, n }; } };
      w.confirm = () => true;
      w.prompt = () => w.__promptAnswer ?? null;
      w.alert = m => { w.__alerts = (w.__alerts || []).concat(m); };
      w.scrollTo = () => {};
      w.console.error = (...a) => errors.push(a.join(" "));
      w.addEventListener("error", e => errors.push(String(e.message)));
    },
  });
  await tick();
  return { dom, w: dom.window, doc: dom.window.document, sb, errors };
}
const tick = (ms = 60) => new Promise(r => setTimeout(r, ms));
const $ = (env, sel) => env.doc.querySelector(sel);
const main = env => env.doc.getElementById("main").innerHTML;
async function click(env, sel) { const el = typeof sel === "string" ? $(env, sel) : sel; if (!el) throw new Error("manca " + sel); el.click(); await tick(); }
function setVal(env, sel, v, ev = "input") { const el = $(env, sel); if (!el) throw new Error("manca " + sel); el.value = v; el.dispatchEvent(new env.w.Event(ev, { bubbles: true })); }
async function tab(env, id) { await click(env, `.tab-btn[data-tab="${id}"]`); }

let fails = 0;
function ok(desc, cond, extra = "") { console.log(`  ${cond ? "OK  " : "FAIL"} ${desc}${!cond && extra ? " — " + extra : ""}`); if (!cond) fails++; }

module.exports = { seedDb, makeSupabase };
if (require.main === module) (async () => {
  // ---------------- configurazione mancante ----------------
  console.log("Senza configurazione:");
  let env = await boot(seedDb(), null, { noConfig: true });
  ok("mostra 'Configurazione mancante'", main(env).includes("Configurazione mancante"));

  // ---------------- login ----------------
  console.log("Login:");
  env = await boot(seedDb(), null);
  ok("mostra il form di login", !!$(env, "#loginForm"));
  ok("nessun tab visibile prima del login", env.doc.getElementById("tabs").innerHTML === "");
  setVal(env, "#loginEmail", " Cliente@Test.it ");
  $(env, "#loginForm").dispatchEvent(new env.w.Event("submit", { cancelable: true }));
  await tick();
  ok("URL Supabase ripulito dal percorso", env.sb.url === "https://test.supabase.co", env.sb.url);
  ok("invia il link all'email normalizzata", env.sb.otp[0] === "cliente@test.it", JSON.stringify(env.sb.otp));
  ok("conferma l'invio", main(env).includes("Link inviato"));

  // ---------------- admin ----------------
  console.log("Admin:");
  const db = seedDb();
  env = await boot(db, "admin@test.it");
  ok("nessun errore JS", env.errors.length === 0, env.errors.join(" | "));
  ok("badge admin", env.doc.getElementById("headerActions").innerHTML.includes("admin"));
  ok("tab Gestione presente", !!$(env, '.tab-btn[data-tab="gestione"]'));
  ok("selettore clienti con 2 clienti", $(env, "#clienteSel") && $(env, "#clienteSel").options.length === 2);
  ok("primo cliente in ordine alfabetico: Altro Cliente", $(env, "#brandSub").textContent === "Altro Cliente");
  setVal(env, "#clienteSel", "cli-basilico", "change"); await tick();
  ok("passa a Basilico", $(env, "#brandSub").textContent.startsWith("Basilico"));
  ok("cliente ricordato in localStorage", env.w.localStorage.getItem("cruscotto.cliente") === "cli-basilico");
  const html = main(env);
  ok("KPI spesa EE 2026 = 8.454,41 €", html.includes("8.454,41 €"));
  ok("KPI spesa gas 2026 = 3.842,07 €", html.includes("3.842,07 €"));
  const ent = env.w.eval("JSON.stringify(sortedEntries().map(e=>[e.id,e.casaLuce&&e.casaLuce.costo,e.casaGas&&e.casaGas.costo]))");
  ok("14 mesi aggregati", JSON.parse(ent).length === 14);
  const tot = JSON.parse(env.w.eval(`JSON.stringify((()=>{const se=sortedEntries();const s=(y,k,m)=>Math.round(se.filter(e=>e.anno===y).reduce((a,e)=>a+(e[k]?e[k][m]:0),0)*100)/100;return [s(2025,'casaLuce','consumo'),s(2025,'casaLuce','costo'),s(2026,'casaLuce','consumo'),s(2026,'casaLuce','costo'),s(2025,'casaGas','consumo'),s(2025,'casaGas','costo'),s(2026,'casaGas','consumo'),s(2026,'casaGas','costo')]})())`));
  ok("totali di controllo §4", JSON.stringify(tot) === JSON.stringify([22560.29, 7211.67, 23272.46, 8454.41, 2640, 3227.2, 2550.13, 3842.07]), JSON.stringify(tot));
  ok("dati dell'altro cliente non mescolati", !html.includes("999,00"));
  ok("variazione bolletta EE Lug '26 vs 2025 = +25,1%", html.includes("+25.1%"));
  setVal(env, "#metricSelect", "consumo", "change"); await tick();
  ok("modalità consumi: grafici kWh e Smc separati", main(env).includes("consumi elettrici (kWh)") && main(env).includes("consumi gas (Smc)"));
  setVal(env, "#metricSelect", "costo", "change"); await tick();

  // Bollette: form + inserimento
  await tab(env, "bollette");
  ok("form di inserimento visibile", !!$(env, "#saveEntryBtn"));
  ok("pulsanti modifica/elimina presenti", env.doc.querySelectorAll("[data-edit]").length === 28);
  setVal(env, "#f_fornitura", "forn-luce", "change"); await tick();
  setVal(env, "#f_anno", "2026"); setVal(env, "#f_mese", "8", "change");
  setVal(env, "#f_fornitore", "FuturEnergy (Energia Pulita)"); setVal(env, "#f_consumo", "3000.5"); setVal(env, "#f_costo", "1234.56");
  setVal(env, "#f_note", "Offerta ULTRAGREEN MF BASSA TENSIONE — fattura EE1 del 07/09/2026");
  await click(env, "#saveEntryBtn"); await tick();
  ok("bolletta agosto 2026 salvata", db.bollette.some(b => b.fornitura_id === "forn-luce" && b.anno === 2026 && b.mese === 8 && b.costo === 1234.56));
  ok("storico mostra agosto 2026", main(env).includes("Agosto 2026") && main(env).includes("1.234,56 €"));
  // modifica della stessa bolletta (nessun doppione)
  const nuova = db.bollette.find(b => b.anno === 2026 && b.mese === 8);
  await click(env, `[data-edit="${nuova.id}"]`);
  ok("form in modalità modifica", $(env, "#saveEntryBtn").textContent.includes("Salva modifiche"));
  setVal(env, "#f_costo", "1200");
  await click(env, "#saveEntryBtn"); await tick();
  ok("modifica senza doppioni", db.bollette.filter(b => b.fornitura_id === "forn-luce" && b.anno === 2026 && b.mese === 8).length === 1 && nuova.costo === 1200);
  // validazione
  setVal(env, "#f_costo", "");
  await click(env, "#saveEntryBtn");
  ok("validazione campi obbligatori", $(env, "#formErr").style.display === "block");
  // eliminazione
  await click(env, `[data-delete="${nuova.id}"]`); await tick();
  ok("bolletta eliminata", !db.bollette.some(b => b.id === nuova.id));

  // Confronto offerte: modifica salvata
  await tab(env, "confronto");
  setVal(env, 'tr[data-offer-row="off-1"] [data-of="prezzo"]', "0.2");
  await tick(900);
  ok("offerta salvata nel database (admin)", db.offerte[0].prezzo === 0.2);
  ok("stima annua calcolata", main(env).match(/\d\.\d{3},\d{2} €/));

  // Gestione: nuovo cliente con due POD
  await tab(env, "gestione");
  setVal(env, "#nc_nome", "Max — casa"); await click(env, "#addClienteBtn"); await tick();
  const maxc = db.clienti.find(c => c.nome === "Max — casa");
  ok("cliente creato e selezionato", maxc && $(env, "#brandSub").textContent === "Max — casa");
  for (const [cod, sede] of [["IT001E000A", "Casa"], ["IT001E000B", "Box"]]) {
    setVal(env, "#nf_codice", cod); setVal(env, "#nf_sede", sede);
    await click(env, "#saveFornituraBtn"); await tick();
  }
  ok("due forniture luce create", db.forniture.filter(f => f.cliente_id === maxc.id && f.tipo === "luce").length === 2);
  setVal(env, "#nf_tipo", "gas", "change"); await tick();
  ok("form fornitura gas: etichetta PDR, niente potenza", main(env).includes(">PDR<") && !$(env, "#nf_potenza"));
  setVal(env, "#na_email", "Moglie@Test.it"); await click(env, "#addAccessoBtn"); await tick();
  ok("accesso aggiunto in minuscolo", db.accessi.some(a => a.email === "moglie@test.it" && a.cliente_id === maxc.id));
  setVal(env, "#na_email", "moglie@test.it"); await click(env, "#addAccessoBtn"); await tick();
  ok("accesso duplicato segnalato", (env.doc.getElementById("toast") || {}).textContent?.includes("già abilitata"));
  const [fa, fb] = db.forniture.filter(f => f.cliente_id === maxc.id);
  await tab(env, "bollette");
  for (const [f, cons, cost] of [[fa, 100, 50], [fb, 40, 20.5]]) {
    setVal(env, "#f_fornitura", f.id, "change"); await tick();
    setVal(env, "#f_anno", "2026"); setVal(env, "#f_mese", "9", "change");
    setVal(env, "#f_fornitore", "Enel"); setVal(env, "#f_consumo", String(cons)); setVal(env, "#f_costo", String(cost));
    await click(env, "#saveEntryBtn"); await tick();
  }
  const sett = JSON.parse(env.w.eval("JSON.stringify(sortedEntries().find(e=>e.id==='2026-9').casaLuce)"));
  ok("due POD sommati nel mese: 140 kWh / 70,50 €", sett.consumo === 140 && sett.costo === 70.5, JSON.stringify(sett));
  ok("storico mostra le due sedi", main(env).includes(">Casa<") && main(env).includes(">Box<"));
  ok("filtro fornitura visibile", !!$(env, "#fornituraSel"));
  setVal(env, "#fornituraSel", fb.id, "change"); await tick();
  const solob = JSON.parse(env.w.eval("JSON.stringify(sortedEntries().find(e=>e.id==='2026-9').casaLuce)"));
  ok("filtro su una sola fornitura: 40 kWh", solob.consumo === 40);
  // export
  await click(env, "#exportBtn");
  ok("export Excel con nome cliente e due fogli", env.w.__written && env.w.__written.n === "Cruscotto_Energia_Max_casa.xlsx" && env.w.__written.wb.sheets.length === 2, JSON.stringify(env.w.__written && env.w.__written.n));
  // eliminazione cliente con conferma del nome
  await tab(env, "gestione");
  env.w.__promptAnswer = "nome sbagliato"; await click(env, "#deleteClienteBtn");
  ok("eliminazione bloccata se il nome non corrisponde", db.clienti.some(c => c.id === maxc.id));
  env.w.__promptAnswer = "Max — casa"; await click(env, "#deleteClienteBtn"); await tick();
  ok("cliente eliminato con forniture e bollette", !db.clienti.some(c => c.id === maxc.id) && !db.forniture.some(f => f.cliente_id === maxc.id));
  ok("nessun errore JS (admin)", env.errors.length === 0, env.errors.join(" | "));
  await click(env, "#logoutBtn"); await tick();
  ok("logout torna al login", !!$(env, "#loginForm"));

  // ---------------- cliente ----------------
  console.log("Cliente:");
  env = await boot(seedDb(), "basilico@test.it");
  ok("nessun errore JS", env.errors.length === 0, env.errors.join(" | "));
  ok("vede il proprio cliente", $(env, "#brandSub").textContent.startsWith("Basilico"));
  ok("nessun selettore clienti", !$(env, "#clienteSel"));
  ok("nessun tab Gestione", !$(env, '.tab-btn[data-tab="gestione"]'));
  ok("niente import/export", !$(env, "#exportBtn") && !$(env, "#importInput"));
  ok("niente badge admin", !env.doc.getElementById("headerActions").innerHTML.includes("role-badge"));
  ok("KPI uguali all'admin", main(env).includes("8.454,41 €"));
  await tab(env, "bollette");
  ok("storico visibile", main(env).includes("Luglio 2026"));
  ok("nessun form di inserimento", !$(env, "#saveEntryBtn"));
  ok("nessun pulsante modifica/elimina", !$(env, "[data-edit]") && !$(env, "[data-delete]"));
  ok("nessun dato dell'altro cliente", !main(env).includes("segreto"));
  await tab(env, "confronto");
  const scritture = () => env.sb.calls.filter(c => c.op !== "select").length;
  setVal(env, 'tr[data-offer-row="off-1"] [data-of="prezzo"]', "0.3"); await tick(900);
  ok("può simulare un'offerta senza salvare", scritture() === 0 && main(env).includes("non vengono salvate"));
  ok("nessun errore JS (cliente)", env.errors.length === 0, env.errors.join(" | "));

  // ---------------- utente senza accesso ----------------
  console.log("Utente non abilitato:");
  env = await boot(seedDb(), "sconosciuto@test.it");
  ok("messaggio accesso non abilitato", main(env).includes("Accesso non ancora abilitato"));
  ok("nessun tab", env.doc.getElementById("tabs").innerHTML === "");

  console.log(fails ? `\n${fails} TEST APP FALLITI` : "\nTUTTI I TEST APP SUPERATI");
  process.exit(fails ? 1 : 0);
})().catch(e => { console.error(e); process.exit(1); });
