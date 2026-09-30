/**
 * 理論編の共通スクリプト。
 *  1) 進捗バー（章の位置 + ページ内スクロール）
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

    const nav = document.createElement("div");
    nav.className = "chapnav";
    nav.innerHTML =
      `<div class="meter"><span>全${CHAPTERS.length}章中 第${cur}章</span>` +
      `<span class="track"><i style="width:0"></i></span><span class="pct">0%</span></div>` +
      "<ol>" + CHAPTERS.map((c) =>
        `<li class="${c.n < cur ? "done" : c.n === cur ? "cur" : ""}">` +
        `<a href="${c.url}">${c.n}. ${c.t}</a></li>`).join("") + "</ol>";
    const anchor = document.querySelector("h1");
    if (anchor) anchor.after(nav);
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

  function linkText(textNode) {
    const text = textNode.nodeValue;
    if (!text || !text.trim()) return;
    for (const e of entries) {
      if ((used.get(e.id) || 0) >= LIMIT) continue;
      const i = text.indexOf(e.name);
      if (i < 0) continue;
      const before = text.slice(0, i), after = text.slice(i + e.name.length);
      const a = document.createElement("a");
      a.className = "term";
      a.href = GLOSSARY + e.id;
      a.title = e.hint + "（クリックで辞書。戻るで復帰）";
      a.textContent = e.name;
      const frag = document.createDocumentFragment();
      if (before) frag.append(document.createTextNode(before));
      frag.append(a);
      const rest = document.createTextNode(after);
      frag.append(rest);
      textNode.replaceWith(frag);
      used.set(e.id, (used.get(e.id) || 0) + 1);
      linkText(rest);                    // 残りにも続けて当てる
      return;
    }
  }

  const main = document.querySelector(".wrap");
  if (main && groups.length) walk(main);
})();
