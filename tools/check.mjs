#!/usr/bin/env node
// 公開前の機械検査。Node 標準ライブラリのみ（npm install を要らなくする）。
//
// error にしてよいのは「機械的に一意に判定でき、直し方が自明で、放置すると
// 読者が実害を受ける」ものだけ。誤報が2回出た時点で検査そのものが捨てられるので、
// 判断が要るものは warn に置く。
import { readdirSync, readFileSync, existsSync, statSync } from "node:fs";
import { join, dirname, relative, resolve } from "node:path";

const ROOT = resolve(process.argv[2] ?? "public");
const errors = [];
const warns = [];
const err = (f, m) => errors.push(`${relative(ROOT, f)}: ${m}`);
const warn = (f, m) => warns.push(`${relative(ROOT, f)}: ${m}`);

function walk(dir, out = []) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}
const files = walk(ROOT);
const htmls = files.filter((f) => f.endsWith(".html"));

// ---- 用語辞書の id を集める（リンク検査の突き合わせ先に必ず含める） ----
// これを含めないと #sni のような辞書アンカーを「存在しない」と誤検知する。
const termIds = new Map(); // theme -> Set(id)
for (const f of files.filter((f) => f.endsWith("terms.js"))) {
  const theme = relative(ROOT, f).split("/")[0];
  const ids = new Set();
  for (const m of readFileSync(f, "utf8").matchAll(/\bid\s*:\s*"([^"]+)"/g)) ids.add(m[1]);
  termIds.set(theme, ids);
  if (ids.size === 0) err(f, "用語の id が1つも読み取れない");
}

// ---- 1. 内部リンクとアンカーの実在 ----
const anchorsOf = new Map();
for (const f of htmls) {
  const html = readFileSync(f, "utf8");
  const set = new Set();
  for (const m of html.matchAll(/\sid="([^"]+)"/g)) set.add(m[1]);
  anchorsOf.set(f, set);
}
function resolveTarget(href) {
  // /a/b → public/a/b.html または public/a/b/index.html
  const clean = href.replace(/[?#].*$/, "");
  if (!clean.startsWith("/")) return null;
  const base = join(ROOT, clean);
  if (clean.endsWith("/")) return existsSync(join(base, "index.html")) ? join(base, "index.html") : null;
  if (existsSync(base) && statSync(base).isFile()) return base;
  if (existsSync(base + ".html")) return base + ".html";
  if (existsSync(join(base, "index.html"))) return join(base, "index.html");
  return null;
}
// <script> の中身はリンク検査から除外する。
// JS のテンプレートリテラル（`${CHURL[t.ch]}` 等）を「存在しないリンク」と
// 誤検知すると、誤報1件で検査そのものが信用されなくなる。
// 開始タグは残して中身だけ落とす（<script src="..."> の src は検査したい）
const stripScripts = (h) => h.replace(/(<script\b[^>]*>)[\s\S]*?<\/script>/g, "$1");

for (const f of htmls) {
  const theme = relative(ROOT, f).split("/")[0];
  const html = stripScripts(readFileSync(f, "utf8"));
  for (const m of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
    const href = m[1];
    if (/^(https?:|mailto:|#|data:)/.test(href)) {
      if (href.startsWith("#")) {
        const id = href.slice(1);
        const known = anchorsOf.get(f).has(id) || (termIds.get(theme)?.has(id) ?? false);
        if (!known) err(f, `ページ内アンカー #${id} が存在しない`);
      }
      continue;
    }
    if (!href.startsWith("/")) {
      // プレースホルダは 4b が数えるので、ここで二重に warn を出さない
      if (href === "REPORT_URL") continue;
      warn(f, `相対パスのリンク: ${href}（ルート相対に揃える）`); continue;
    }
    const target = resolveTarget(href);
    if (!target) { err(f, `リンク先が存在しない: ${href}`); continue; }
    const hash = href.includes("#") ? href.split("#")[1] : null;
    if (hash) {
      const tTheme = relative(ROOT, target).split("/")[0];
      const known = (anchorsOf.get(target)?.has(hash) ?? false) || (termIds.get(tTheme)?.has(hash) ?? false);
      if (!known) err(f, `リンク先にアンカーが無い: ${href}`);
    }
  }
}

// ---- 2. 章テンプレの必須要素 ----
const count = (h, re) => (h.match(re) ?? []).length;
for (const f of htmls) {
  const html = readFileSync(f, "utf8");
  const isChapter = /<body[^>]*data-ch="\d+"/.test(html);
  if (!isChapter) continue;

  // たとえの上限は章の長さに比例させる。固定値（6個）にすると、
  // 解説を厚くした長い章で必ず warn が出て、検査が信用されなくなる。
  // 目安は 60行に1個まで（下限は 6個）。
  const lines = html.split("\n").length;
  const analogyMax = Math.max(6, Math.ceil(lines / 60));

  const need = [
    ["div.goal", count(html, /class="goal"/g), 1, Infinity],
    ["div.skip", count(html, /class="skip"/g), 1, Infinity],
    ["div.analogy", count(html, /class="analogy"/g), 3, analogyMax],
    ["div.quiz", count(html, /class="quiz"/g), 2, Infinity],
    ["div.note try", count(html, /class="note try"/g), 1, Infinity],
    ["div.verified", count(html, /class="verified"/g), 1, Infinity],
    ["div.naive", count(html, /class="naive"/g), 1, 1],
  ];
  for (const [name, n, lo, hi] of need) {
    if (n < lo) err(f, `${name} が ${n} 個（${lo} 以上が必要）`);
    else if (n > hi) warn(f, `${name} が ${n} 個（${hi} 以下を想定）`);
  }
  // h2 の数と sgoal の数（まとめの h2 は sgoal を持たないので -1 まで許容）
  const h2 = count(html, /<h2\b/g), sgoal = count(html, /class="sgoal"/g);
  if (sgoal < h2 - 1) warn(f, `h2 が ${h2} 個に対し sgoal が ${sgoal} 個`);
  // たとえに崩れる点があるか
  const analogies = [...html.matchAll(/class="analogy"[\s\S]*?<\/div>/g)].map((m) => m[0]);
  const noBreak = analogies.filter((a) => !/崩れる|成立しない|ただし/.test(a)).length;
  if (noBreak > 0) err(f, `たとえ ${noBreak} 個に「崩れる点」が書かれていない`);
  // 確認問題の答えが折りたたまれているか
  const quizzes = [...html.matchAll(/class="quiz"[\s\S]*?<\/div>\s*<\/div>|class="quiz"[\s\S]*?<\/div>/g)].map((m) => m[0]);
  const noDetails = quizzes.filter((q) => !/<details/.test(q)).length;
  if (noDetails > 0) warn(f, `確認問題 ${noDetails} 個に details が無い`);
  // 章ナビが動く前提（chapters.js と theory.js を読んでいるか）
  if (!/chapters\.js/.test(html)) err(f, "chapters.js を読み込んでいない（進捗バーが出ない）");
  if (!/shared\/theory\.js/.test(html)) err(f, "shared/theory.js を読み込んでいない");
  if (!/data-theme="[a-z]+"/.test(html)) err(f, "body に data-theme が無い（用語リンク先が解決できない）");
}

// ---- 3. 本文と実物がずれる書き方 ----
for (const f of htmls) {
  const html = readFileSync(f, "utf8");
  if (/:latest\b/.test(html)) err(f, ":latest が本文にある（半年後に本文と実物がずれる）");
  if (/\bTBD\b/.test(html)) err(f, "TBD が残っている");
  // 検証環境ブロックに検証日があるか
  const v = html.match(/class="verified"[\s\S]*?<\/div>/);
  if (v && !/検証日\s*\d{4}-\d{2}-\d{2}/.test(v[0])) err(f, "検証環境ブロックに検証日が無い");
}

// ---- 4. 辞書ページが自動リンクを走らせていないか（自己参照になる） ----
for (const f of htmls.filter((f) => /glossary\.html$/.test(f))) {
  if (/shared\/theory\.js/.test(readFileSync(f, "utf8")))
    err(f, "辞書ページが shared/theory.js を読んでいる（辞書の中で自動リンクが走る）");
}

// ---- 4b. 公開前に残っていてはいけないプレースホルダ ----
// 置換漏れは文字列の完全一致で判定できるので誤報しない。
// ただし制作中は残っているのが正常なので、--publish を付けたときだけ error にする。
const PUBLISH = process.argv.includes("--publish");
// 長いものから順に数える。GISCUS_REPO は GISCUS_REPO_ID の接頭辞なので、
// 素朴に数えると後者が両方にカウントされて数が合わなくなる。
const PLACEHOLDERS = [
  "ghcr.io/OWNER",
  "ghcr.io/&lt;owner&gt;",   // HTML エスケープされた綴り。別物として数える
  "REPORT_URL",
  "chai0204/REPO",
  "<REPO>",
  "GISCUS_CATEGORY_ID",
  "GISCUS_REPO_ID",
  "GISCUS_REPO",
].sort((a, b) => b.length - a.length);

let phTotal = 0;
// 対象は HTML だけでなく JS も見る。giscus の設定は shared/comments.js にある。
const phTargets = [...htmls, ...files.filter((f) => f.endsWith(".js"))];
for (const f of phTargets) {
  let rest = readFileSync(f, "utf8");
  for (const ph of PLACEHOLDERS) {
    const n = rest.split(ph).length - 1;
    if (n > 0) {
      phTotal += n;
      (PUBLISH ? err : warn)(f, `プレースホルダが残っている: ${ph} ×${n}`);
      // 数えた箇所を潰してから次へ進む（接頭辞の二重カウントを防ぐ）
      rest = rest.split(ph).join("\u0000".repeat(ph.length));
    }
  }
}
if (phTotal > 0 && !PUBLISH) {
  console.log(`\n  ※ プレースホルダ ${phTotal} 箇所。公開前に \`--publish\` を付けて走らせると error になります`);
}

// ---- 4c. ドラフト指定の整合 ----
// 「著者が読者として通していないテーマ」には全ページに警告が要る。
// 検索経由で章に直接来る読者がいるため、1ページ抜けると警告を見ない読者が発生する。
// 指定（body の data-draft）と表示（div.draftbar）が1対1であることを機械で保証する。
const themeDirs = [...new Set(
  htmls.map((f) => relative(ROOT, f)).filter((r) => r.includes("/")).map((r) => r.split("/")[0])
)];
const draftThemes = new Set();
for (const theme of themeDirs) {
  const pages = htmls.filter((f) => relative(ROOT, f).startsWith(theme + "/"));
  if (!pages.length) continue;
  const drafted = [];
  for (const f of pages) {
    const h = readFileSync(f, "utf8");
    const d = /<body[^>]*\bdata-draft="1"/.test(h);
    const b = /class="draftbar/.test(h);
    if (d) drafted.push(f);
    if (d && !b) err(f, 'data-draft="1" があるのに draftbar の警告が本文に無い');
    if (b && !d) err(f, 'draftbar があるのに body に data-draft="1" が無い');
  }
  if (drafted.length === pages.length && pages.length > 0) draftThemes.add(theme);
  else if (drafted.length > 0) {
    const missing = pages.filter((f) => !drafted.includes(f)).map((f) => relative(ROOT, f));
    err(drafted[0], `テーマ ${theme} のドラフト指定が ${drafted.length}/${pages.length} ページしか無い。抜け: ${missing.join(", ")}`);
    draftThemes.add(theme);
  }
}

// ポータルの印が、実際のドラフト状態と一致しているか
const topPage = join(ROOT, "index.html");
if (existsSync(topPage)) {
  const h = readFileSync(topPage, "utf8");
  for (const theme of themeDirs) {
    if (!htmls.some((f) => relative(ROOT, f).startsWith(theme + "/"))) continue;
    const isDraft = draftThemes.has(theme);
    const links = [...h.matchAll(/<a\s[^>]*href="\/([^/"]+)\/[^"]*"[\s\S]*?<\/a>/g)].filter((m) => m[1] === theme);
    for (const m of links) {
      const tagged = /class="tag draft"/.test(m[0]);
      if (isDraft && !tagged) err(topPage, `ドラフトのテーマ ${theme} へのリンクに「ドラフト」の印が無い`);
      if (!isDraft && tagged) err(topPage, `ドラフトでないテーマ ${theme} に「ドラフト」の印が付いている`);
    }
  }
}
if (draftThemes.size) console.log(`  ドラフト扱いのテーマ: ${[...draftThemes].join(", ")}`);

// ---- 4d. wrangler.jsonc の設定 ----
// jsonc なので JSON.parse は使えない（コメントがある）。文字列で見る。
// ここで止めたいのは、デプロイしてからでないと分からない事故。
const wranglerPath = resolve(ROOT, "..", "wrangler.jsonc");
if (existsSync(wranglerPath)) {
  const w = readFileSync(wranglerPath, "utf8");
  const name = "../wrangler.jsonc";
  const say = (m) => (PUBLISH ? errors : warns).push(`${name}: ${m}`);
  if (/"name"\s*:\s*"<[^"]*>"/.test(w)) say("name がプレースホルダのまま（wrangler が弾く）");
  if (/^\s*"main"\s*:/m.test(w))
    errors.push(`${name}: "main" がある。静的アセットのみなら書かない（存在しないファイルを指すとデプロイが落ちる）`);
  if (!/"not_found_handling"\s*:\s*"404-page"/.test(w))
    errors.push(`${name}: not_found_handling が "404-page" でない。public/404.html が使われない`);
  if (!/"html_handling"\s*:\s*"auto-trailing-slash"/.test(w))
    warns.push(`${name}: html_handling が auto-trailing-slash でない。本文のリンクは拡張子なしで書いてある`);
  const dir = w.match(/"directory"\s*:\s*"([^"]+)"/)?.[1];
  if (dir && resolve(dirname(wranglerPath), dir) !== ROOT)
    errors.push(`${name}: assets.directory (${dir}) が検査したディレクトリ (${ROOT}) と違う`);
  if (/"not_found_handling"\s*:\s*"404-page"/.test(w) && !existsSync(join(ROOT, "404.html")))
    errors.push(`${name}: not_found_handling が 404-page なのに public/404.html が無い`);
}

// ---- 4e. コメント欄の整合 ----
// <div id="giscus"> を置いただけでは何も出ない。comments.js が挿入する。
// 片方だけ入った状態は、ページを開くまで気づけない。
for (const f of htmls) {
  const h = readFileSync(f, "utf8");
  const slot = /id="giscus"/.test(h);
  const script = /shared\/comments\.js/.test(h);
  if (slot && !script) err(f, 'id="giscus" があるのに shared/comments.js を読んでいない（コメント欄が空のまま）');
  if (script && !slot) err(f, 'shared/comments.js を読んでいるのに id="giscus" が無い');
}
const noComments = htmls.filter((f) => !/id="giscus"/.test(readFileSync(f, "utf8")))
  .map((f) => relative(ROOT, f)).filter((r) => r !== "404.html");
if (noComments.length) warn(htmls[0], `コメント欄が無いページ: ${noComments.join(", ")}`);

// ---- 5. 用語の自動リンクが実際に発火するか ----
// shared/theory.js は pre / code / h1-h4 / a / summary / nav と .no-term を走査しない。
// 辞書に登録したのに、本文では常に <code> の中にしか出てこない語はリンクされない。
// 「辞書に足したのに点線が出ない」を公開前に見つけるための検査。
const SKIP_TAGS = "pre|code|h1|h2|h3|h4|a|summary|nav|script|style";
const plainText = (h) =>
  h.replace(new RegExp(`<(${SKIP_TAGS})\\b[^>]*>[\\s\\S]*?</\\1>`, "g"), " ")
   .replace(/<[^>]+>/g, " ");

for (const [theme, _ids] of termIds) {
  const termsFile = join(ROOT, theme, "theory", "terms.js");
  if (!existsSync(termsFile)) continue;
  const src = readFileSync(termsFile, "utf8");
  // 各語の表記（t と alt）を集める
  const entries = [];
  for (const m of src.matchAll(/\{\s*t\s*:\s*"([^"]+)"([\s\S]*?)\bid\s*:\s*"([^"]+)"/g)) {
    const names = [m[1]];
    const altBlock = m[2].match(/alt\s*:\s*\[([^\]]*)\]/);
    if (altBlock) for (const a of altBlock[1].matchAll(/"([^"]+)"/g)) names.push(a[1]);
    entries.push({ names, id: m[3] });
  }
  const chapters = htmls.filter((f) => f.includes(`/${theme}/`) && /data-ch="\d+"/.test(readFileSync(f, "utf8")));
  const body = chapters.map((f) => plainText(readFileSync(f, "utf8"))).join("\n");
  const raw = chapters.map((f) => readFileSync(f, "utf8")).join("\n");

  const never = entries.filter((e) => !e.names.some((n) => body.includes(n)));
  const onlyCode = never.filter((e) => e.names.some((n) => raw.includes(n)));
  const absent = never.filter((e) => !e.names.some((n) => raw.includes(n)));

  if (onlyCode.length)
    warn(termsFile, `本文では常に code/pre の中にしか出ないためリンクされない語 ${onlyCode.length} 件: ${onlyCode.map((e) => e.names[0]).join(", ")}`);
  if (absent.length)
    warn(termsFile, `どの章の本文にも出てこない語 ${absent.length} 件: ${absent.map((e) => e.names[0]).join(", ")}`);
  const linked = entries.length - never.length;
  console.log(`  ${theme}: 用語 ${entries.length} 語のうち ${linked} 語が本文でリンクされる`);
}

// ---- 出力 ----
const label = (n) => (n === 0 ? "なし" : `${n} 件`);
console.log(`検査対象: ${htmls.length} ページ / 用語辞書 ${termIds.size} 本`);
console.log(`\n■ error: ${label(errors.length)}`);
for (const e of errors) console.log("  ✗ " + e);
console.log(`\n■ warn: ${label(warns.length)}`);
for (const w of warns) console.log("  ⚠ " + w);
process.exit(errors.length > 0 ? 1 : 0);
