// ページを jsdom で実際に描画して、読者が見る状態を確かめる。
//
// check.mjs は要素とデータの有無しか見ないので、次のものを検出できない。
//   - 辞書が空で表示される
//   - 進捗バーが出ない
//   - 用語リンクがコードブロックの中に張られてコードが読めなくなる
// ここでは DOM を実際に組んで、数で確認する。
//
//   node tools/render-check.mjs public
//
// jsdom が入っていなければ何もせず成功で抜ける（check.mjs の依存0を崩さないため）。
import { readFileSync, existsSync, readdirSync } from "node:fs";
import { resolve, join } from "node:path";

let JSDOM;
try {
  ({ JSDOM } = await import("jsdom"));
} catch {
  console.log("jsdom が無いのでスキップしました。有効にするには: npm i -D jsdom");
  process.exit(0);
}

const ROOT = resolve(process.argv[2] ?? "public");
let bad = 0;
const fail = (m) => { console.log("  ✗ " + m); bad++; };

// 外部スクリプトは jsdom が取りに行かないので、ページが読む順に自分で流し込む。
function render(file, scripts) {
  const dom = new JSDOM(readFileSync(file, "utf8"), { runScripts: "outside-only" });
  for (const s of scripts) if (existsSync(s)) dom.window.eval(readFileSync(s, "utf8"));
  return dom.window;
}

const themes = readdirSync(ROOT, { withFileTypes: true })
  .filter((e) => e.isDirectory() && existsSync(join(ROOT, e.name, "theory", "glossary.html")))
  .map((e) => e.name);
if (!themes.length) { console.log("理論編のあるテーマが見つかりません"); process.exit(0); }

for (const theme of themes) {
  const T = join(ROOT, theme);
  const chaptersJs = join(T, "chapters.js");
  const termsJs = join(T, "theory", "terms.js");
  const chapterCount = [...readFileSync(chaptersJs, "utf8").matchAll(/\bn:\s*\d+/g)].length;

  console.log(`\n######## ${theme} ########`);

  // ---- 1. 用語辞書 ----
  {
    const w = render(join(T, "theory", "glossary.html"),
      [chaptersJs, termsJs, join(ROOT, "shared", "glossary.js")]);
    const doc = w.document;
    const items = doc.querySelectorAll(".gitem");
    const where = doc.querySelectorAll(".where a");
    const count = doc.getElementById("gcount")?.textContent ?? "(なし)";

    console.log(`辞書: ${items.length}語 / グループ${doc.querySelectorAll("#glist section").length}` +
                ` / 章リンク${where.length} / まちがえやすい${doc.querySelectorAll(".misread").length}` +
                ` / 表示"${count}"`);
    if (!items.length) fail("辞書に語が1つも描画されていない");
    if (where.length !== items.length)
      fail(`章リンクが ${where.length}/${items.length}。ch が chapters.js に無い語がある`);
    if (!count.includes(String(items.length))) fail("語数の表示が語数と合わない");

    const first = where[0];
    console.log(`  章リンクの例: "${first?.textContent}" → ${first?.getAttribute("href")}`);

    const q = doc.getElementById("q");
    q.value = items[0].querySelector("h3").textContent.slice(0, 3);
    q.dispatchEvent(new w.Event("input"));
    const shown = [...doc.querySelectorAll(".gitem")].filter((e) => e.style.display !== "none").length;
    console.log(`  検索 "${q.value}" → ${shown}語（表示"${doc.getElementById("gcount").textContent}"）`);
    if (shown === 0 || shown === items.length) fail("検索が絞り込めていない");
  }

  // ---- 2. 理論編の各章（進捗バーと用語の自動リンク） ----
  const chapterFiles = readdirSync(join(T, "theory"))
    .filter((f) => /^\d\d-.*\.html$/.test(f)).sort();

  for (const f of chapterFiles) {
    const file = join(T, "theory", f);
    const w = render(file, [chaptersJs, termsJs, join(ROOT, "shared", "theory.js")]);
    const doc = w.document;
    const ch = doc.body.dataset.ch;

    const nav = doc.querySelector(".chapnav");
    const lis = doc.querySelectorAll(".chapnav ol li");
    const curLi = doc.querySelectorAll(".chapnav li.cur");
    const terms = doc.querySelectorAll("a.term");

    // 用語リンクが入ってはいけない場所に入っていないか（SKIP の検証）
    const leaked = ["pre", "code", "h1", "h2", "h3", "h4", "summary", "nav.top"]
      .map((sel) => [sel, doc.querySelectorAll(`${sel} a.term`).length])
      .filter(([, n]) => n > 0);

    // 同じ語に3本以上リンクが張られていないか（LIMIT = 2）
    const byId = {};
    for (const a of terms) {
      const id = (a.getAttribute("href") || "").split("#")[1] || "?";
      byId[id] = (byId[id] || 0) + 1;
    }
    const over = Object.entries(byId).filter(([, n]) => n > 2);

    // href の形
    const badHref = [...terms].filter(
      (a) => !new RegExp(`^/${theme}/theory/glossary#[^#]+$`).test(a.getAttribute("href") || "")).length;

    console.log(`${f}: 章${ch} / 章リスト${lis.length} / 用語リンク${terms.length}本（${Object.keys(byId).length}語）`);
    if (!nav) fail(`${f}: 進捗バー（.chapnav）が描画されていない`);
    if (lis.length !== chapterCount) fail(`${f}: 章リストが ${lis.length}/${chapterCount}`);
    if (curLi.length !== 1) fail(`${f}: 現在章の印（li.cur）が ${curLi.length}個`);
    if (!terms.length) fail(`${f}: 用語リンクが1本も張られていない`);
    if (leaked.length) fail(`${f}: 用語リンクが ${leaked.map(([s, n]) => `${s}内に${n}本`).join("・")}`);
    if (over.length) fail(`${f}: 同じ語に3本以上: ${over.map(([i, n]) => `${i}×${n}`).join(", ")}`);
    if (badHref) fail(`${f}: 用語リンクの href が想定外の形 ${badHref}本`);
  }
}

console.log(bad === 0 ? "\n全ページで描画・リンク・検索が動いた" : `\n✗ 問題 ${bad} 件`);
process.exit(bad === 0 ? 0 : 1);
