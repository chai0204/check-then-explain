// トップの記事一覧の検索・絞り込み・並べ替え。表は静的な HTML として全行が焼かれているので、
// このスクリプトが動かなくても一覧は読める（既定の並び = 最終更新の新しい順）。
// 条件は URL の ?q=…&cert=… にも映し、そのまま共有できる。
(() => {
  const tbl = document.querySelector("table.catalog");
  const form = document.querySelector(".catalog-controls");
  if (!tbl || !form) return;
  const body = tbl.tBodies[0];
  const rows = [...body.rows];
  const $ = (id) => document.getElementById(id);
  const ctl = { q: $("cq"), status: $("c-status"), cert: $("c-cert"), domain: $("c-domain"), method: $("c-method"), diff: $("c-diff"), sort: $("c-sort") };
  const count = $("c-count");
  const norm = (s) => (s || "").normalize("NFKC").toLowerCase();
  const byKey = {
    updated: (a, b) => b.dataset.updated.localeCompare(a.dataset.updated) || certCmp(a, b) || titleCmp(a, b),
    cert: (a, b) => certCmp(a, b) || titleCmp(a, b),
    time: (a, b) => (+a.dataset.min - +b.dataset.min) || titleCmp(a, b),
    title: (a, b) => titleCmp(a, b),
  };
  function certCmp(a, b) { return (a.dataset.certOrder || "~").localeCompare(b.dataset.certOrder || "~"); }
  function titleCmp(a, b) { return a.dataset.title.localeCompare(b.dataset.title, "ja"); }

  // URL の条件を読む（例: /?cert=LinuC%20レベル1&q=ssh）
  const params = new URLSearchParams(location.search);
  for (const [k, el] of Object.entries(ctl)) if (params.has(k)) el.value = params.get(k);

  function apply() {
    const words = norm(ctl.q.value).split(/\s+/).filter(Boolean);
    let shown = 0;
    for (const r of rows) {
      const d = r.dataset;
      const ok = (!ctl.status.value || d.status === ctl.status.value)
        && (!ctl.cert.value || (ctl.cert.value === "none" ? !d.cert : d.cert === ctl.cert.value))
        && (!ctl.domain.value || d.domain.split(" ").includes(ctl.domain.value))
        && (!ctl.method.value || d.method === ctl.method.value)
        && (!ctl.diff.value || d.diff === ctl.diff.value)
        && words.every((w) => norm(d.q).includes(w));
      r.hidden = !ok;
      if (ok) shown++;
    }
    [...rows].sort(byKey[ctl.sort.value] || byKey.updated).forEach((r) => body.appendChild(r));
    count.textContent = shown === rows.length ? `全 ${rows.length} 件` : `${shown} 件（全 ${rows.length} 件中）`;
    const p = new URLSearchParams();
    for (const [k, el] of Object.entries(ctl)) if (el.value && !(k === "sort" && el.value === "updated")) p.set(k, el.value);
    history.replaceState(null, "", p.toString() ? `?${p}` : location.pathname);
  }
  form.addEventListener("submit", (e) => e.preventDefault());
  for (const el of Object.values(ctl)) el.addEventListener("input", apply);
  form.hidden = false;
  apply();
})();
