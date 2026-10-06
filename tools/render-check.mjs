// 辞書ページを jsdom で実際に描画して、読者が見る状態を確かめる。
//
// check.mjs は要素とデータの有無しか見ないので、「辞書が空で表示される」を検出できない。
// ここでは実際に DOM を組んで、語・章リンク・語数表示・検索の絞り込みまで確認する。
//
//   node tools/render-check.mjs public
//
// jsdom が入っていなければ何もせず成功で抜ける（check.mjs の依存0を崩さないため）。
import { readFileSync, existsSync, readdirSync } from "node:fs";
import { resolve, join } from "node:path";

// jsdom は任意。無ければ何もせず 0 で抜ける（npm install を必須にしない）。
let JSDOM;
try {
  ({ JSDOM } = await import("jsdom"));
} catch {
  console.log("jsdom が無いのでスキップしました。有効にするには: npm i -D jsdom");
  process.exit(0);
}

const ROOT = resolve(process.argv[2] ?? "public");
let bad = 0;

const themes = readdirSync(ROOT, { withFileTypes: true })
  .filter((e) => e.isDirectory() && existsSync(join(ROOT, e.name, "theory", "glossary.html")))
  .map((e) => e.name);
if (!themes.length) { console.log("辞書ページが見つかりません"); process.exit(0); }

for (const theme of themes) {
  const html = readFileSync(`${ROOT}/${theme}/theory/glossary.html`, "utf8");
  const dom = new JSDOM(html, { runScripts: "outside-only" });
  const { window } = dom;

  // 外部スクリプトは jsdom が取りに行かないので、順番どおりに自分で流し込む
  for (const f of [
    `${ROOT}/${theme}/chapters.js`,
    `${ROOT}/${theme}/theory/terms.js`,
    `${ROOT}/shared/glossary.js`,
  ]) {
    window.eval(readFileSync(f, "utf8"));
  }

  const doc = window.document;
  const items = doc.querySelectorAll(".gitem");
  const sections = doc.querySelectorAll("#glist section");
  const indexLinks = doc.querySelectorAll("#gindex a");
  const where = doc.querySelectorAll(".where a");
  const misread = doc.querySelectorAll(".misread");
  const count = doc.getElementById("gcount")?.textContent ?? "(なし)";

  console.log(`\n######## ${theme} ########`);
  console.log(`語           : ${items.length}`);
  console.log(`グループ     : ${sections.length}（索引リンク ${indexLinks.length}）`);
  console.log(`章リンク     : ${where.length}`);
  console.log(`まちがえやすい: ${misread.length}`);
  console.log(`語数の表示   : ${count}`);

  if (items.length === 0) { console.log("✗ 語が1つも描画されていない"); bad++; }
  if (where.length !== items.length) {
    console.log(`✗ 章リンクが ${where.length}/${items.length}。ch が chapters.js に無い語がある`);
    bad++;
  }
  if (!count.includes(String(items.length))) { console.log(`✗ 語数の表示が語数と合わない`); bad++; }

  // 章リンクの文面と行き先を1つ見る（chapters.js の値が使われているか）
  const first = where[0];
  console.log(`章リンクの例 : "${first?.textContent}" → ${first?.getAttribute("href")}`);

  // 検索を実際に動かす
  const q = doc.getElementById("q");
  q.value = items[0].querySelector("h3").textContent.slice(0, 3);
  q.dispatchEvent(new window.Event("input"));
  const shown = [...doc.querySelectorAll(".gitem")].filter((e) => e.style.display !== "none").length;
  console.log(`検索 "${q.value}" → ${shown} 語に絞られた（表示: ${doc.getElementById("gcount").textContent}）`);
  if (shown === 0 || shown === items.length) { console.log("✗ 検索が絞り込めていない"); bad++; }
}

console.log(bad === 0 ? "\n両テーマとも描画・検索が動いた" : `\n✗ 問題 ${bad} 件`);
process.exit(bad === 0 ? 0 : 1);
