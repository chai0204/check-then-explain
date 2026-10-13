#!/usr/bin/env node
// LinuC 出題範囲マップ（public/linuc/index.html）を、各コースの実物から作り直す。
//
//   node tools/linuc-hub.mjs           作り直して書き込む
//   node tools/linuc-hub.mjs --check   書き込まず、いまのファイルと違えば exit 1
//
// 表を手で書くと、章を足したり番号を変えたりしたときに表と実物がずれる。そこで次の3つから毎回組み立てる:
//   - tools/linuc-syllabus.json          副題・重要度・担当コース（公式から抜き出したもの）
//   - public/<course>/theory/NN-*.html   章のバッジ「出題範囲 1.0x.y」= その章が扱う副題
//   - containers/<course>/**/verify/NN.meta の chapter=N = その演習が手で確かめる章
// 副題の状態:
//   手を動かせる … その副題を扱う章があり、その章に対応する演習が1本以上ある
//   理論のみ     … 章はあるが、対応する演習が無い（檻で再現できない・知識問題）
//   —            … まだ章が無い
import { readFileSync, writeFileSync, readdirSync, existsSync, statSync } from "node:fs";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const repo = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const out = join(repo, "public", "linuc", "index.html");
const syl = JSON.parse(readFileSync(join(repo, "tools", "linuc-syllabus.json"), "utf8"));
const CHECK = process.argv.includes("--check");

const COURSE_TITLE = {
  "linuc-boot": "Linux の起動・仮想化・プロセス",
  "linuc-files": "ファイルとパーミッション",
  "linuc-text": "コマンドラインとテキスト処理",
  "linuc-packages": "パッケージ管理（apt と yum）",
  "linuc-disks": "ハードウェアとディスク",
  "linuc-shell": "シェルとスクリプト",
  "linuc-network": "ネットワークの基礎",
  "linuc-admin": "アカウント・ジョブ・ロケール",
  "linuc-services": "時刻・ログ・メール",
  "linuc-security": "セキュリティ",
  "linuc-oss": "オープンソースの文化",
};
const THEME_TITLE = {
  "1.01": "Linuxのインストールと仮想マシン・コンテナの利用",
  "1.02": "ファイル・ディレクトリの操作と管理",
  "1.03": "GNUとUnixのコマンド",
  "1.04": "リポジトリとパッケージ管理",
  "1.05": "ハードウェア、ディスク、パーティション、ファイルシステム",
  "1.06": "シェルおよびスクリプト",
  "1.07": "ネットワークの基礎",
  "1.08": "システム管理",
  "1.09": "重要なシステムサービス",
  "1.10": "セキュリティ",
  "1.11": "オープンソースの文化",
};

// 檻のディレクトリがコース名と違うもの（主題1.09 は最初の LinuC の檻として containers/linuc に作った）
const CAGE_DIR = { "linuc-services": "linuc" };

const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

function walk(d) {
  if (!existsSync(d)) return [];
  return readdirSync(d).flatMap((n) => {
    const p = join(d, n);
    return statSync(p).isDirectory() ? walk(p) : [p];
  });
}

// ---- コースごとの章と演習を集める ----
const courses = {};
for (const slug of new Set(syl.topics.map((t) => t.course))) {
  const dir = join(repo, "public", slug, "theory");
  const c = { slug, chapters: [], exercises: [], exists: existsSync(dir) };
  courses[slug] = c;
  if (!c.exists) continue;
  for (const f of readdirSync(dir).filter((f) => /^\d\d-.*\.html$/.test(f)).sort()) {
    const h = readFileSync(join(dir, f), "utf8");
    const n = +(h.match(/<body[^>]*data-ch="(\d+)"/)?.[1] ?? 0);
    if (!n) continue;
    const title = (h.match(/<h1>([\s\S]*?)<\/h1>/)?.[1] ?? "").replace(/<[^>]+>/g, "").replace(/^\d+\.\s*/, "");
    const badges = [...h.matchAll(/<span[^>]*>([^<]*出題範囲[^<]*)<\/span>/g)].map((m) => m[1]).join(" ");
    const topics = [...new Set([...badges.matchAll(/1\.\d\d\.\d/g)].map((m) => m[0]))];
    c.chapters.push({ n, file: f.replace(/\.html$/, ""), title, topics });
  }
  // 演習: containers/<slug>/ の下の verify/NN.meta（檻が2つあるコースは deb/ rpm/ の下に分かれる）
  for (const m of walk(join(repo, "containers", CAGE_DIR[slug] || slug)).filter((p) => /\/verify\/\d\d\.meta$/.test(p))) {
    const meta = Object.fromEntries(readFileSync(m, "utf8").split("\n")
      .map((l) => l.match(/^([a-z_]+)=(.*)$/)).filter(Boolean).map((x) => [x[1], x[2]]));
    c.exercises.push({ id: m.match(/(\d\d)\.meta$/)[1], chapter: +(meta.chapter || 0), title: meta.title || "" });
  }
  // 制作中でディレクトリだけあるものは、まだコースとして扱わない（リンク先が無いページを作らない）
  if (c.chapters.length === 0) { c.exists = false; c.exercises = []; }
}

// ---- 副題ごとの状態 ----
const rows = syl.topics.map((t) => {
  const c = courses[t.course];
  const chs = c.chapters.filter((ch) => ch.topics.includes(t.id));
  const exs = c.exercises.filter((e) => chs.some((ch) => ch.n === e.chapter));
  const state = chs.length === 0 ? "none" : exs.length > 0 ? "hands" : "theory";
  return { ...t, chs, exs, state };
});
const sum = (f) => rows.filter(f).reduce((a, r) => a + r.w, 0);
const wHands = sum((r) => r.state === "hands");
const wTheory = sum((r) => r.state === "theory");
const wNone = sum((r) => r.state === "none");
const nHands = rows.filter((r) => r.state === "hands").length;
const nTheory = rows.filter((r) => r.state === "theory").length;
const nNone = rows.filter((r) => r.state === "none").length;
const pct = (w) => ((w / 120) * 100).toFixed(1);

function stateCell(r) {
  if (r.state === "hands") return `<span class="tag draft">ドラフト</span> 手を動かせる`;
  if (r.state === "theory") return `<span class="tag draft">ドラフト</span> 理論のみ`;
  return "—";
}
function courseCell(r) {
  if (r.state === "none") return `${esc(COURSE_TITLE[r.course] || r.course)}（予定）`;
  const links = r.chs.map((ch) => `<a href="/${r.course}/theory/${ch.file}">第${ch.n}章</a>`).join(" · ");
  const ex = r.exs.length ? `<br><span class="detail">演習 ${r.exs.map((e) => e.id).join(" / ")}</span>` : "";
  return `<a href="/${r.course}/">${esc(COURSE_TITLE[r.course] || r.course)}</a>: ${links}${ex}`;
}
function table(exam) {
  const lines = [`<div class="scroll"><table>`, `<tr><th>副題</th><th>重要度</th><th>状態</th><th>どこで学ぶか</th></tr>`];
  let theme = "";
  for (const r of rows) {
    const th = r.id.slice(0, 4);
    const inExam = exam === "101" ? +th.slice(2) <= 5 : +th.slice(2) >= 6;
    if (!inExam) continue;
    if (th !== theme) {
      theme = th;
      lines.push(`<tr><td colspan="4"><b>主題${th} ${esc(THEME_TITLE[th])}</b></td></tr>`);
    }
    lines.push(`<tr><td>${r.id} ${esc(r.title)}</td><td>${r.w}</td><td>${stateCell(r)}</td><td>${courseCell(r)}</td></tr>`);
  }
  lines.push(`</table></div>`);
  return lines.join("\n");
}

const theoryRows = rows.filter((r) => r.state === "theory");
const courseRows = Object.values(courses).filter((c) => c.exists).map((c) => {
  const ids = [...new Set(c.chapters.flatMap((ch) => ch.topics))].sort();
  const themes = [...new Set(ids.map((i) => i.slice(0, 4)))];
  return { c, ids, themes };
}).sort((a, b) => (a.themes[0] || "").localeCompare(b.themes[0] || ""));

const html = `<!doctype html>
<html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>LinuC 出題範囲マップ — 確かめて説明する</title>
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="/shared/style.css"></head>
<body data-theme="linuc">
<div class="wrap">
<nav class="top"><a href="/">トップ</a> › <strong>LinuC</strong></nav>
<!-- このページは tools/linuc-hub.mjs が各コースの実物（章のバッジと演習の meta）から生成する。手で編集しない。 -->

<h1>LinuC レベル1 出題範囲マップ</h1>
<p class="lead">LinuC レベル1（<a href="https://linuc.org/linuc1/range/101.html">101</a> /
<a href="https://linuc.org/linuc1/range/102.html">102</a>・Version 10.0）の出題範囲を、
<strong>副題ごとに</strong>並べたものです。
どの副題をどの章で学び、どの演習で手を動かすかが分かります。</p>

<div class="promise">
<p>目標は「教材を他に買わなくても、このサイトだけで合格できる」状態です。
<b>届いていない部分をこの表で隠さずに出します。</b>
表は各コースの章と演習から自動で作っているので、表と中身がずれることはありません。</p>
</div>

<h2 id="now">いまの進み</h2>
<div class="goal">
<p><b>39 副題のうち ${nHands + nTheory} 副題に章があります（重要度の合計 120 のうち ${wHands + wTheory} ぶん・${pct(wHands + wTheory)}%）</b></p>
<ul>
<li>手を動かせる: ${nHands} 副題・重要度 ${wHands}（${pct(wHands)}%）— 章と、それを手で確かめる演習がある</li>
<li>理論のみ: ${nTheory} 副題・重要度 ${wTheory}（${pct(wTheory)}%）— 章はあるが、檻で再現できないか知識問題なので演習が無い</li>
<li>まだ無い: ${nNone} 副題・重要度 ${wNone}（${pct(wNone)}%）</li>
</ul>
<p>副題の数ではなく<b>重要度の合計</b>で数えています。公式が副題ごとに付けている重要度は
出題の比重の目安なので、こちらのほうが「合格までどれくらいか」に近いためです。</p>
<div class="skip"><b>この表で分からないこと</b>:
出題の実際の配点、合格点、問題の形式。それは公式ページで確認してください。
この表は「教材が在るか、手を動かせるか」だけを示します。</div>
</div>

<h2 id="status">印の意味</h2>
<div class="scroll"><table>
<tr><th>印</th><th>意味</th></tr>
<tr><td><span class="tag draft">ドラフト</span> 手を動かせる</td><td>章と演習がある。本文の出力はすべて実機の記録。著者が読者として通していない</td></tr>
<tr><td><span class="tag draft">ドラフト</span> 理論のみ</td><td>章はある（記録で確かめられる部分は確かめてある）。演習は無い</td></tr>
<tr><td><span class="tag real">著者が通った</span></td><td>著者が読者として最後まで通し、出た不備を直した</td></tr>
<tr><td>—</td><td>まだ無い。右端にどのコースで作る予定かを書いてあります</td></tr>
</table></div>

<h2 id="t101">101 試験</h2>
${table("101")}

<h2 id="t102">102 試験</h2>
${table("102")}

<h2 id="theory-only">理論のみの副題について</h2>
<p>この教材の作り方は「実機で打った出力だけを本文に載せる」です。
打つものが無い副題、檻（コンテナや仮想マシン）では再現できない副題は、演習を作らず理論として説明しています。</p>
${theoryRows.length ? `<div class="scroll"><table>
<tr><th>副題</th><th>重要度</th><th>章</th></tr>
${theoryRows.map((r) => `<tr><td>${r.id} ${esc(r.title)}</td><td>${r.w}</td><td>${r.chs.map((ch) => `<a href="/${r.course}/theory/${ch.file}">第${ch.n}章 ${esc(ch.title)}</a>`).join("<br>")}</td></tr>`).join("\n")}
</table></div>
<p>理由は各コースの地形図（理論編の目次）に書いてあります。</p>` : "<p>いまは該当なし。</p>"}

<h2 id="how">このサイトの使い方</h2>
<ol>
<li>公式の出題範囲を1回読む（<a href="https://linuc.org/linuc1/range/101.html">101</a> /
    <a href="https://linuc.org/linuc1/range/102.html">102</a>）。読むだけで頭に入らなくて構いません</li>
<li>上の表から副題を選んで、理論編の章を開く</li>
<li>理論編を読んだら<b>必ず実践編の演習をやる</b>。読むだけでは出題範囲のコマンド名は定着しません</li>
<li>各コースの地形図にある「試験の直前に見る表」で、出題範囲の語を一通り確かめる</li>
<li>本文と違う出力が出たら報告する。それが教材の改善になります</li>
</ol>
<p>コースは<b>主題ごと</b>、章は<b>副題より細かく</b>切ってあります。空いた時間に1章ずつ進められます。</p>

<h2 id="courses">コース</h2>
<div class="cages"><div class="scroll"><table>
<tr><th>コース</th><th>範囲</th><th>章</th><th>演習</th><th>状態</th></tr>
${courseRows.map(({ c, ids, themes }) => `<tr><td><a href="/${c.slug}/">主題${themes.join("・")} ${esc(COURSE_TITLE[c.slug] || c.slug)}</a></td>
    <td>${ids.join(" / ")}</td><td>${c.chapters.length}</td><td>${c.exercises.length || "—"}</td><td><span class="tag draft">ドラフト</span></td></tr>`).join("\n")}
</table></div></div>

<section id="comments">
<h2>コメント</h2>
<p class="detail">分かりにくかった副題や、足りない説明があれば書いてください。直す順番の判断に使います。<br>
   <b>本文と違う出力が出た場合</b>は <a href="https://github.com/chai0204/check-then-explain/issues/new/choose">Issue</a> のほうが、
   添える情報が決まっているので速く直せます。</p>
<div id="giscus"></div>
</section>
<footer><a href="/">トップ</a></footer>
</div>
<script src="/shared/comments.js"></script>
</body></html>
`;

// ---- トップページ（public/index.html）の LinuC コース一覧 ----
// 目印 <!-- linuc-courses:start …--> と <!-- linuc-courses:end --> の間だけを置き換える。
const portal = join(repo, "public", "index.html");
function cageKind(slug) {
  const dir = join(repo, "containers", CAGE_DIR[slug] || slug);
  const dfs = walk(dir).filter((p) => /Dockerfile$/.test(p)).map((p) => readFileSync(p, "utf8"));
  if (!dfs.length) return "理論のみ（演習なし）";
  if (dfs.some((d) => /^FROM lab-linuc-machine:/m.test(d))) return "特権なし（仮想マシンの練習機）";
  if (dfs.some((d) => /cap-add|SYS_ADMIN|systemd/.test(d)) && slug === "linuc-services") return "<code>CAP_SYS_ADMIN</code> 1ビットのみ";
  return dfs.length > 1 ? `特権なし（コンテナ ${dfs.length} 種）` : "特権なし（コンテナ）";
}
function minutes(slug) {
  const c = courses[slug];
  let m = 0;
  for (const ch of c.chapters) {
    const h = readFileSync(join(repo, "public", slug, "theory", ch.file + ".html"), "utf8");
    m += +(h.match(/所要\s*(\d+)\s*分/)?.[1] ?? 0);
  }
  for (const p of walk(join(repo, "containers", CAGE_DIR[slug] || slug)).filter((p) => /\/verify\/\d\d\.meta$/.test(p)))
    m += +(readFileSync(p, "utf8").match(/^est_min=(\d+)/m)?.[1] ?? 0);
  return m;
}
const hm = (m) => (m >= 60 ? `約${Math.floor(m / 60)}時間${m % 60 ? `${m % 60}分` : ""}` : `約${m}分`);
function lead(slug) {
  const f = join(repo, "public", slug, "theory", "index.html");
  if (!existsSync(f)) return "";
  const t = (readFileSync(f, "utf8").match(/<p class="lead">([\s\S]*?)<\/p>/)?.[1] ?? "").replace(/\s+/g, " ").trim();
  const first = t.split("。")[0];
  return first ? first + "。" : "";
}
const portalBlock = `<!-- linuc-courses:start（ここから下は tools/linuc-hub.mjs が各コースの実物から生成する。手で編集しない） -->
<div class="toc">
${courseRows.map(({ c, ids, themes }) => {
  const ex = c.exercises.length;
  return `  <a href="/${c.slug}/theory/"><b><span class="tag draft">ドラフト</span>LinuC 主題${themes.join("・")} ${esc(COURSE_TITLE[c.slug] || c.slug)}</b>
    <span>${lead(c.slug)}<br>
      ${ids.join(" / ")} ／ 理論${c.chapters.length}章${ex ? ` ＋ 演習${ex}本` : ""} ／ ${hm(minutes(c.slug))} ／ ${cageKind(c.slug)}</span></a>`;
}).join("\n")}
</div>
<!-- linuc-courses:end -->`;
let portalHtml = existsSync(portal) ? readFileSync(portal, "utf8") : "";
const pm = portalHtml.match(/<!-- linuc-courses:start[\s\S]*?<!-- linuc-courses:end -->/);
if (!pm) { console.error("✗ public/index.html に linuc-courses の目印が無い"); process.exit(1); }
const newPortal = portalHtml.replace(pm[0], portalBlock);

if (CHECK) {
  if (newPortal !== portalHtml) { console.log("✗ public/index.html の LinuC 一覧が実物と合っていない（node tools/linuc-hub.mjs で作り直す）"); process.exit(1); }
}
if (CHECK) {
  const cur = existsSync(out) ? readFileSync(out, "utf8") : "";
  if (cur !== html) { console.log("✗ public/linuc/index.html が実物と合っていない（node tools/linuc-hub.mjs で作り直す）"); process.exit(1); }
  console.log("✔ 出題範囲マップは実物と一致"); process.exit(0);
}
writeFileSync(out, html);
writeFileSync(portal, newPortal);
console.log(`書き込み: public/linuc/index.html と public/index.html（LinuC コース一覧）`);
console.log(`  手を動かせる ${nHands} 副題（重要度 ${wHands}）/ 理論のみ ${nTheory}（${wTheory}）/ まだ無い ${nNone}（${wNone}）`);
