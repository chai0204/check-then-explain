/**
 * 理論編の共通スクリプト。
 *  1) 進捗バー（章の位置 + ページ内スクロール）。章の一覧は閉じた箱（details.chapnav）に入れ、
 *     見出しの行には進み具合だけを出す（2026-10-22、章を読む前に一覧が並ぶのが煩わしいとオーナーが指摘）
 *  2) 本文中の用語を辞書へ自動リンク（terms.js のデータを使う）
 * 用語リンクは手で書かずに済ませる。書き漏らしが出ないし、
 * 辞書を足せば全ページに自動で反映される。
 */
(() => {
  // 章の一覧はテーマ側が渡す（<theme>/chapters.js が window.CHAPTERS を定義する）。
  // ここにハードコードすると1テーマしか載らない。
  const CHAPTERS = window.CHAPTERS || [];
  const THEME = document.body.dataset.theme || "";
  const GLOSSARY = "/" + THEME + "/theory/glossary#";

  const cur = parseInt(document.body.dataset.ch || "0", 10);

  /* ---- 1. 進捗 ---- */
  if (cur > 0) {
    const bar = document.createElement("div");
    bar.className = "progress";
    bar.innerHTML = "<i></i>";
    document.body.prepend(bar);
    const fill = bar.firstChild;

    const nav = document.createElement("details");
    nav.className = "chapnav";
    nav.innerHTML =
      `<summary class="meter"><span>全${CHAPTERS.length}章中 第${cur}章</span>` +
      `<span class="track"><i style="width:0"></i></span><span class="pct">0%</span></summary>` +
      "<ol>" + CHAPTERS.map((c) =>
        `<li class="${c.n < cur ? "done" : c.n === cur ? "cur" : ""}">` +
        `<a href="${c.url}">${c.n}. ${c.t}</a></li>`).join("") + "</ol>";
    // 章の頭の閉じた箱（この章のゴールと前提など）の先頭に並べる。無ければリード文の後、それも無ければ題の後
    const h1 = document.querySelector("h1");
    const h2 = document.querySelector(".wrap h2");
    const fold = document.querySelector(".wrap > details.fold");
    const lead = h1 && h1.nextElementSibling && h1.nextElementSibling.matches("p.lead") ? h1.nextElementSibling : null;
    if (fold && (!h2 || fold.compareDocumentPosition(h2) & Node.DOCUMENT_POSITION_FOLLOWING)) fold.before(nav);
    else if (lead) lead.after(nav);
    else if (h1) h1.after(nav);
    const track = nav.querySelector(".track i");
    const pct = nav.querySelector(".pct");

    const update = () => {
      const h = document.documentElement;
      const max = h.scrollHeight - h.clientHeight;
      const within = max > 0 ? Math.min(1, h.scrollTop / max) : 1;
      fill.style.width = (within * 100).toFixed(1) + "%";
      const total = ((cur - 1 + within) / CHAPTERS.length) * 100;
      track.style.width = total.toFixed(1) + "%";
      pct.textContent = Math.round(total) + "%";
    };
    addEventListener("scroll", update, { passive: true });
    addEventListener("resize", update);
    update();
  }

  /* ---- 2. 用語の自動リンク ---- */
  const groups = window.TERM_GROUPS || [];
  const entries = [];
  for (const g of groups) {
    for (const t of g.terms) {
      for (const name of [t.t, ...(t.alt || [])]) entries.push({ name, id: t.id, hint: t.hint });
    }
  }
  // 長い語から先に当てる（「IPアドレス」を「IP」より先に）
  entries.sort((a, b) => b.name.length - a.name.length);

  const SKIP = new Set(["A","PRE","CODE","SCRIPT","STYLE","H1","H2","H3","H4","BUTTON","SUMMARY","NAV"]);
  const used = new Map();               // 用語ごとの出現回数（1ページ2回までリンク）
  const LIMIT = 2;

  function walk(node) {
    for (const child of [...node.childNodes]) {
      if (child.nodeType === 1) {
        if (!SKIP.has(child.tagName) && !child.classList.contains("no-term")) walk(child);
      } else if (child.nodeType === 3) {
        linkText(child);
      }
    }
  }

  // 英数字で始まる・終わる語は、前後も英数字のところでは当てない（PARTUUID の中の UUID、devtmpfs の中の tmpfs）
  const WORD = /[A-Za-z0-9_]/;
  function find(text, name) {
    const head = WORD.test(name[0]), tail = WORD.test(name[name.length - 1]);
    for (let from = 0; ; ) {
      const i = text.indexOf(name, from);
      if (i < 0) return -1;
      const prev = text[i - 1] || "", next = text[i + name.length] || "";
      if (!(head && WORD.test(prev)) && !(tail && WORD.test(next))) return i;
      from = i + 1;
    }
  }

  function linkText(textNode) {
    const text = textNode.nodeValue;
    if (!text || !text.trim()) return;
    for (const e of entries) {
      if ((used.get(e.id) || 0) >= LIMIT) continue;
      const i = find(text, e.name);
      if (i < 0) continue;
      const before = text.slice(0, i), after = text.slice(i + e.name.length);
      const a = document.createElement("a");
      a.className = "term";
      a.href = GLOSSARY + e.id;
      a.title = e.hint + "（クリックで辞書。戻るで復帰）";
      a.textContent = e.name;
      const frag = document.createDocumentFragment();
      const head = before ? document.createTextNode(before) : null;
      if (head) frag.append(head);
      frag.append(a);
      const rest = document.createTextNode(after);
      frag.append(rest);
      textNode.replaceWith(frag);
      used.set(e.id, (used.get(e.id) || 0) + 1);
      if (head) linkText(head);          // 当たった語より前にも、短い語が残っている
      linkText(rest);                    // 残りにも続けて当てる
      return;
    }
  }

  // 本文を先に、章の頭の閉じた箱（この章のゴールと前提など）を後に走査する。
  // 1語2本までの枠を、目に見える本文で先に使うため（箱を先に走査すると、閉じた箱の中で枠を使い切ることがある）
  const main = document.querySelector(".wrap");
  if (main && groups.length) {
    const folds = [...main.querySelectorAll(":scope > details.fold")].filter((d) => !d.classList.contains("no-term"));
    folds.forEach((d) => d.classList.add("no-term"));
    walk(main);
    folds.forEach((d) => { d.classList.remove("no-term"); walk(d); });
  }
})();
