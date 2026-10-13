// トップの記事一覧の検索・絞り込み・並べ替え・「さらに表示」と、SQL モード。
// 表は静的な HTML として全行が焼かれているので、このスクリプトが動かなくても一覧は読める
// （そのときは全件が既定の並び = 確認済みを先に、次に公開日の新しい順で出る）。
// 条件は URL（?q=…&cert=… / ?sql=…）にも映し、そのまま共有できる。
(() => {
  const tbl = document.querySelector("table.catalog");
  const form = document.querySelector(".catalog-controls");
  if (!tbl || !form) return;
  const body = tbl.tBodies[0];
  const rows = [...body.rows];
  const $ = (id) => document.getElementById(id);
  const ctl = { q: $("cq"), status: $("c-status"), cert: $("c-cert"), domain: $("c-domain"), method: $("c-method"), diff: $("c-diff"), sort: $("c-sort") };
  const count = $("c-count"), more = $("c-more"), wide = tbl.closest(".catalog-wide");
  const PAGE = 10;
  let limit = PAGE;
  const norm = (s) => (s || "").normalize("NFKC").toLowerCase();
  const titleCmp = (a, b) => a.dataset.title.localeCompare(b.dataset.title, "ja");
  const certCmp = (a, b) => (a.dataset.certOrder || "~").localeCompare(b.dataset.certOrder || "~");
  const byKey = {
    rec: (a, b) => (+b.dataset.verified - +a.dataset.verified) || b.dataset.created.localeCompare(a.dataset.created) || certCmp(a, b) || titleCmp(a, b),
    created: (a, b) => b.dataset.created.localeCompare(a.dataset.created) || certCmp(a, b) || titleCmp(a, b),
    updated: (a, b) => b.dataset.updated.localeCompare(a.dataset.updated) || certCmp(a, b) || titleCmp(a, b),
    cert: (a, b) => certCmp(a, b) || titleCmp(a, b),
    time: (a, b) => (+a.dataset.min - +b.dataset.min) || titleCmp(a, b),
    title: (a, b) => titleCmp(a, b),
  };

  const params = new URLSearchParams(location.search);
  for (const [k, el] of Object.entries(ctl)) if (params.has(k)) el.value = params.get(k);

  function apply(resetLimit) {
    if (resetLimit) limit = PAGE;
    const words = norm(ctl.q.value).split(/\s+/).filter(Boolean);
    const sorted = [...rows].sort(byKey[ctl.sort.value] || byKey.rec);
    let matched = 0;
    for (const r of sorted) {
      const d = r.dataset;
      const ok = (!ctl.status.value || d.status === ctl.status.value)
        && (!ctl.cert.value || (ctl.cert.value === "none" ? !d.cert : d.cert === ctl.cert.value))
        && (!ctl.domain.value || d.domain.split(" ").includes(ctl.domain.value))
        && (!ctl.method.value || d.method === ctl.method.value)
        && (!ctl.diff.value || d.diff === ctl.diff.value)
        && words.every((w) => norm(d.q).includes(w));
      if (ok) matched++;
      r.hidden = !ok || matched > limit;
      body.appendChild(r);
    }
    const shown = Math.min(matched, limit);
    count.textContent = matched === rows.length && shown === matched ? `全 ${rows.length} 件`
      : `${matched} 件中 ${shown} 件を表示` + (matched < rows.length ? `（全 ${rows.length} 件）` : "");
    const rest = matched - shown;
    more.hidden = rest <= 0;
    more.textContent = `さらに表示（あと ${rest} 件）`;
    const p = new URLSearchParams();
    for (const [k, el] of Object.entries(ctl)) if (el.value && !(k === "sort" && el.value === "rec")) p.set(k, el.value);
    history.replaceState(null, "", p.toString() ? `?${p}` : location.pathname);
  }
  form.addEventListener("submit", (e) => e.preventDefault());
  for (const el of Object.values(ctl)) el.addEventListener("input", () => apply(true));
  more.addEventListener("click", () => { limit += PAGE; apply(false); });
  form.hidden = false;
  apply(true);

  // ---- SQL モード ----
  // 台帳（/catalog/catalog.sql）を、ブラウザの中の SQLite（sql.js）に読み込んで引く。
  // 受け付けるのは SELECT 文1つと「.schema 表名」だけ。読み込んだ後は PRAGMA query_only で読み取り専用にする。
  const sqlmode = $("c-sqlmode"), box = $("c-sqlbox"), ta = $("c-sql"), out = $("c-sqlout"), run = $("c-run");
  if (!sqlmode || !box) return;
  const VENDOR = "/shared/vendor/sql.js-1.14.2/";
  const MAX_ROWS = 500;
  let dbPromise = null;
  const el = (tag, text, cls) => { const e = document.createElement(tag); if (text !== undefined) e.textContent = text; if (cls) e.className = cls; return e; };
  // sql.js と台帳を読み込む。回線の都合で取得が一度失敗しても、少し待って1回だけ読み直す
  let scriptP = null;
  function loadScript() {
    if (window.initSqlJs) return Promise.resolve();
    if (!scriptP) scriptP = new Promise((resolve, reject) => {
      const s = document.createElement("script");
      s.src = VENDOR + "sql-wasm.js";
      s.onload = resolve;
      s.onerror = () => { scriptP = null; s.remove(); reject(new Error("sql.js を読み込めなかった")); };
      document.head.appendChild(s);
    });
    return scriptP;
  }
  function attempt() {
    return loadScript().then(() => Promise.all([
      window.initSqlJs({ locateFile: (f) => VENDOR + f }),
      fetch("/catalog/catalog.sql").then((r) => { if (!r.ok) throw new Error(`台帳を読み込めなかった（HTTP ${r.status}）`); return r.text(); }),
    ])).then(([SQL, text]) => {
      const db = new SQL.Database();
      db.exec(text);
      db.exec("PRAGMA query_only = 1");
      return db;
    });
  }
  function loadDb() {
    if (dbPromise) return dbPromise;
    dbPromise = attempt().catch(() => new Promise((r) => setTimeout(r, 800)).then(attempt));
    dbPromise.catch(() => { dbPromise = null; });
    return dbPromise;
  }
  // 文字列とコメントの外に、2つ目の文があるか
  function extraStatement(s) {
    let i = 0, q = null;
    while (i < s.length) {
      const c = s[i];
      if (q) { if (c === q) { if (s[i + 1] === q) i++; else q = null; } else if (q === "]" && c === "]") q = null; i++; continue; }
      if (c === "'" || c === '"' || c === "`") { q = c; i++; continue; }
      if (c === "[") { q = "]"; i++; continue; }
      if (c === "-" && s[i + 1] === "-") { while (i < s.length && s[i] !== "\n") i++; continue; }
      if (c === "/" && s[i + 1] === "*") { const j = s.indexOf("*/", i + 2); i = j < 0 ? s.length : j + 2; continue; }
      if (c === ";") return /\S/.test(s.slice(i + 1).replace(/--[^\n]*/g, "").replace(/\/\*[\s\S]*?\*\//g, ""));
      i++;
    }
    return false;
  }
  function classify(src) {
    const s = src.trim();
    if (!s) return { error: "SQL を書いてください" };
    if (s.startsWith(".")) {
      const m = s.match(/^\.schema\s+([A-Za-z_][A-Za-z0-9_]*)\s*;?$/);
      if (m) return { kind: "schema", table: m[1] };
      if (/^\.schema\s*;?$/.test(s)) return { error: ".schema には表の名前を付けてください（例: .schema article）" };
      return { error: "使えるドットコマンドは .schema 表名 だけです" };
    }
    const body = s.replace(/^(\s|--[^\n]*\n|\/\*[\s\S]*?\*\/)+/, "");
    if (!/^select\b/i.test(body)) return { error: "受け付けるのは SELECT 文と .schema 表名 だけです" };
    if (extraStatement(s)) return { error: "1回に書けるのは SELECT 文1つだけです" };
    return { kind: "select", sql: s };
  }
  function showError(msg) { out.replaceChildren(el("p", msg, "sqlerr")); }
  function showRows(cols, rowsData, truncated) {
    const t = el("table", undefined, "sqlres"), thead = el("thead"), hr = el("tr");
    for (const c of cols) hr.appendChild(el("th", c));
    thead.appendChild(hr); t.appendChild(thead);
    const tb = el("tbody");
    for (const r of rowsData) {
      const tr = el("tr");
      for (const v of r) tr.appendChild(v === null ? el("td", "NULL", "null") : el("td", String(v)));
      tb.appendChild(tr);
    }
    t.appendChild(tb);
    const wrap = el("div", undefined, "scroll"); wrap.appendChild(t);
    out.replaceChildren(el("p", `${rowsData.length} 行${truncated ? `（先頭の ${MAX_ROWS} 行だけ表示）` : ""}`, "detail"), wrap);
  }
  async function exec() {
    const c = classify(ta.value);
    const p = new URLSearchParams(); p.set("sql", ta.value.trim());
    history.replaceState(null, "", `?${p}`);
    if (c.error) return showError(c.error);
    out.replaceChildren(el("p", "台帳を読み込んでいます…", "detail"));
    let db;
    try { db = await loadDb(); } catch (e) { return showError(e.message); }
    try {
      if (c.kind === "schema") {
        const st = db.prepare("SELECT sql FROM sqlite_schema WHERE tbl_name = ? AND sql IS NOT NULL ORDER BY type DESC, name");
        st.bind([c.table]);
        const parts = [];
        while (st.step()) parts.push(st.get()[0] + ";");
        st.free();
        if (!parts.length) {
          const names = db.exec("SELECT name FROM sqlite_schema WHERE type = 'table' ORDER BY name")[0]?.values.map((v) => v[0]).join(", ");
          return showError(`${c.table} という表はありません（表: ${names}）`);
        }
        return out.replaceChildren(el("pre", parts.join("\n\n"), "sqlschema"));
      }
      const st = db.prepare(c.sql);
      const cols = st.getColumnNames();
      const data = [];
      let truncated = false;
      while (st.step()) { if (data.length >= MAX_ROWS) { truncated = true; break; } data.push(st.get()); }
      st.free();
      showRows(cols, data, truncated);
    } catch (e) { showError(e.message); }
  }
  function setMode(on) {
    box.hidden = !on;
    for (const k of ["q", "status", "cert", "domain", "method", "diff", "sort"]) ctl[k].hidden = on;
    wide.hidden = on; count.hidden = on; more.hidden = on || more.hidden;
    if (!on) apply(true);
  }
  sqlmode.addEventListener("change", () => { setMode(sqlmode.checked); if (sqlmode.checked) ta.focus(); });
  run.addEventListener("click", exec);
  ta.addEventListener("keydown", (e) => { if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) { e.preventDefault(); exec(); } });
  for (const b of box.querySelectorAll("button.ex")) b.addEventListener("click", () => { ta.value = b.dataset.sql; exec(); });
  if (params.has("sql")) { sqlmode.checked = true; ta.value = params.get("sql"); setMode(true); exec(); }
})();
