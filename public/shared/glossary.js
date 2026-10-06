// 用語辞書の描画と検索。2テーマで同一のロジックなので共通化している。
//
// 章タイトルと URL は window.CHAPTERS（<theme>/chapters.js）から組む。
// ここで独自に持つと、進捗バーと辞書で違うタイトルが読者に見える。
// 実際にそうなっていた（進捗バー「まとめると速い」／辞書「書き込みは、まとめると270倍速い」）。
//
// 置いたままにせず外部ファイルにしたのは CSP のため。
// inline script を残すと script-src に 'unsafe-inline' が要る。
//
// HTML 側に必要な要素: #glist #gindex #q（#gcount は任意）
(() => {
  const groups = window.TERM_GROUPS || [];
  const list = document.getElementById("glist");
  const index = document.getElementById("gindex");
  const count = document.getElementById("gcount");
  const q = document.getElementById("q");
  if (!list || !index || !q) return;

  const CH = {}, CHURL = {};
  for (const c of window.CHAPTERS || []) {
    CH[c.n] = `${c.n}. ${c.t}`;
    CHURL[c.n] = c.url;
  }

  let total = 0;
  groups.forEach((g, gi) => {
    const id = "g" + gi;
    index.insertAdjacentHTML("beforeend", `<a href="#${id}">${g.g}</a>`);
    const sec = document.createElement("section");
    sec.innerHTML = `<h2 id="${id}">${g.g}</h2>`;
    for (const t of g.terms) {
      total++;
      const alt = (t.alt || []).length ? `<small>${t.alt.join(" / ")}</small>` : "";
      const mis = t.misread ? `<p class="misread"><b>まちがえやすい点:</b> ${t.misread}</p>` : "";
      // 章データが無い語（辞書だけに載せた語）でもリンクを壊さない
      const where = CHURL[t.ch]
        ? `<p class="where">詳しく: <a href="${CHURL[t.ch]}">${CH[t.ch]}</a></p>` : "";
      sec.insertAdjacentHTML("beforeend",
        `<div class="gitem" id="${t.id}" data-k="${(t.t + " " + (t.alt||[]).join(" ") + " " + t.hint).toLowerCase()}">
           <h3>${t.t}${alt}</h3>
           <p><b>ひとことで:</b> ${t.hint}</p>
           <p>${t.body}</p>
           ${mis}
           ${where}
         </div>`);
    }
    list.append(sec);
  });
  if (count) count.textContent = `全 ${total} 語`;

  q.addEventListener("input", () => {
    const v = q.value.trim().toLowerCase();
    let shown = 0;
    document.querySelectorAll(".gitem").forEach((el) => {
      const hit = !v || el.dataset.k.includes(v) || el.textContent.toLowerCase().includes(v);
      el.style.display = hit ? "" : "none";
      if (hit) shown++;
    });
    document.querySelectorAll("#glist section").forEach((s) => {
      s.style.display = [...s.querySelectorAll(".gitem")].some((e) => e.style.display !== "none") ? "" : "none";
    });
    if (count) count.textContent = v ? `${shown} / ${total} 語` : `全 ${total} 語`;
  });
})();
