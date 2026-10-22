// 全ページ共通の小さなスクリプト（2026-10-22 から）。
//  1) 閉じた箱（<details>）の中や見出しをリンクで指されたら、箱を開いてから見せる。
//     理論編の前置きを閉じた箱にしたので、/kvm/theory/#cages のようなリンクが、閉じた箱の見出しで止まらないように。
//  2) 受けた記事の印。このブラウザの localStorage にだけ持つ（サーバにも、ほかの端末にも送らない）。
//     DB とアカウントを持たないための形で、端末をまたぐときは、トップで作る「写すリンク」で運ぶ（shared/catalog.js）。
//     記事のホームと実践編の終わりにある <div class="mydone" data-slug="…" hidden> に、印を付ける・外すボタンを出す。
//     トップの一覧は window.cteDone を使う。ストレージが使えないブラウザ（禁止の設定など）では何も出さない。
(() => {
  /* ---- 1. リンク先の箱を開く ---- */
  function reveal() {
    let id = "";
    try { id = decodeURIComponent(location.hash.slice(1)); } catch { return; }
    const t = id && document.getElementById(id);
    if (!t) return;
    let opened = false;
    for (let d = t.closest("details"); d; d = d.parentElement && d.parentElement.closest("details")) {
      if (!d.open) { d.open = true; opened = true; }
    }
    if (opened) t.scrollIntoView();
  }
  addEventListener("hashchange", reveal);
  reveal();

  /* ---- 2. 受けた印 ---- */
  const KEY = "cte.done";                       // { "記事の slug": "印を付けた日 YYYY-MM-DD" }
  const SLUG = /^[a-z0-9][a-z0-9-]{0,63}$/, DATE = /^\d{4}-\d{2}-\d{2}$/;
  function read() {
    try {
      const v = JSON.parse(localStorage.getItem(KEY) || "{}");
      const out = {};
      if (v && typeof v === "object" && !Array.isArray(v))
        for (const [k, d] of Object.entries(v)) if (SLUG.test(k) && DATE.test(d)) out[k] = d;
      return out;
    } catch { return {}; }
  }
  function write(m) {
    try { localStorage.setItem(KEY, JSON.stringify(m)); return true; } catch { return false; }
  }
  const usable = (() => {
    try { localStorage.setItem(KEY + ".probe", "1"); localStorage.removeItem(KEY + ".probe"); return true; } catch { return false; }
  })();
  const today = () => {
    const d = new Date(), p = (n) => String(n).padStart(2, "0");
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
  };
  const subs = [];
  const notify = () => subs.forEach((f) => f());
  const api = window.cteDone = {
    usable,
    all: read,
    get: (slug) => read()[slug] || null,
    set(slug, on) {
      const m = read();
      if (on) m[slug] = m[slug] || today(); else delete m[slug];
      const ok = write(m);
      notify();
      return ok;
    },
    // ほかの端末から写した印を足す。すでにある印は残す（日付も変えない）。足した数を返す
    merge(entries) {
      const m = read();
      let n = 0;
      for (const [k, d] of entries) if (SLUG.test(k) && DATE.test(d) && !m[k]) { m[k] = d; n++; }
      if (n && write(m)) notify();
      return n;
    },
    subscribe(f) { subs.push(f); },
  };
  // 別のタブで付けた・外した印も映す
  addEventListener("storage", (e) => { if (e.key === KEY) notify(); });

  const boxes = [...document.querySelectorAll(".mydone[data-slug]")];
  if (!usable || !boxes.length) return;
  const el = (tag, cls, text) => {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text) e.textContent = text;
    return e;
  };
  let refocus = null;
  function draw(box) {
    const slug = box.dataset.slug, d = api.get(slug);
    const b = el("button", d ? "undo" : "", d ? "印を外す" : "受けた印を付ける");
    b.type = "button";
    b.addEventListener("click", () => { refocus = box; api.set(slug, !d); });
    box.replaceChildren(...(d
      ? [el("span", "tag done", "✓ 受けた"), el("span", "detail", `${d} に印を付けました。印はこのブラウザにだけ残ります。`), b]
      : [b, el("span", "detail", "終えたら付けておくと、トップの記事の一覧で見分けられます。印はこのブラウザにだけ残り、サーバには送りません。")]));
    box.hidden = false;
    if (refocus === box) b.focus();
  }
  api.subscribe(() => { boxes.forEach(draw); refocus = null; });
  boxes.forEach(draw);
})();
