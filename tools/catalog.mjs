#!/usr/bin/env node
// 記事の台帳（catalog/schema.sql + catalog/articles.sql）から、トップの記事一覧と各記事のホームを焼き出し、
// 記事の中の全ページの道しるべ（パンくず・フッター・最後の章の「次」・地形図と実践編の末尾の前後）を揃える。
//
//   node tools/catalog.mjs          書き込む
//   node tools/catalog.mjs --check  書き込まず、台帳や道しるべとずれたページがあれば exit 1
//
// なぜこの形か（2026-10-13、オーナーの指摘）:
//   トップ → 資格の出題範囲マップ → 各コース、と層が連なっていて、どこに何があるか分かりにくかった。
//   全記事を1つの表に並べ、各記事にホームを置いて理論編（/slug/theory/）と実践編（/slug/practice/）へ降りる形にする。
// 台帳は SQLite で引く（Node 組み込みの node:sqlite）。書くのは管理者だけ・読者は読み取り専用なので、
// 公開するのは焼き出した静的なページだけで、検索と絞り込みはブラウザの中（shared/catalog.js）で動く。
// 完了推定時間は台帳に持たない。章の「所要 N分」と演習の est_min を毎回数える。
import { readFileSync, writeFileSync, existsSync, readdirSync, statSync, mkdirSync } from "node:fs";
import { join, resolve, dirname, relative } from "node:path";
import { fileURLToPath } from "node:url";
process.removeAllListeners("warning"); // node:sqlite の ExperimentalWarning（Node 22）を出さない
const { DatabaseSync } = await import("node:sqlite");

const repo = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const CHECK = process.argv.includes("--check");
const pub = (...p) => join(repo, "public", ...p);
const esc = (s) => String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

// ---- 台帳を読む ----
const db = new DatabaseSync(":memory:");
db.exec("PRAGMA foreign_keys = ON");
db.exec(readFileSync(join(repo, "catalog", "schema.sql"), "utf8"));
db.exec(readFileSync(join(repo, "catalog", "articles.sql"), "utf8"));
const DOMAINS = ["サーバー", "ネットワーク", "セキュリティ", "DB", "ウェブ", "OSS"];
const arts = db.prepare("SELECT * FROM article").all();
const bySlug = Object.fromEntries(arts.map((a) => [a.slug, a]));
for (const a of arts) {
  a.domains = db.prepare("SELECT domain FROM article_domain WHERE slug = ?").all(a.slug).map((r) => r.domain)
    .sort((x, y) => DOMAINS.indexOf(x) - DOMAINS.indexOf(y));
  a.related = db.prepare("SELECT related FROM article_related WHERE slug = ? ORDER BY related").all(a.slug).map((r) => r.related);
}
const certMap = Object.fromEntries(db.prepare("SELECT name, map_url FROM cert").all().map((r) => [r.name, r.map_url]));

const problems = [];
const problem = (m) => problems.push(m);

// ---- 実物から数える ----
function walk(d) {
  if (!existsSync(d)) return [];
  return readdirSync(d).flatMap((n) => { const p = join(d, n); return statSync(p).isDirectory() ? walk(p) : [p]; });
}
const CAGES = { "linuc-services": ["linuc"], "linuc-packages": ["linuc-packages/deb", "linuc-packages/rpm"] };
for (const a of arts) {
  if (!existsSync(pub(a.slug, "theory"))) { problem(`台帳の ${a.slug} に理論編（public/${a.slug}/theory/）が無い`); continue; }
  if (!existsSync(pub(a.slug, "practice", "index.html"))) problem(`台帳の ${a.slug} に実践編（public/${a.slug}/practice/index.html）が無い`);
  const cj = readFileSync(pub(a.slug, "chapters.js"), "utf8");
  a.chapters = [...cj.matchAll(/\{\s*n:\s*(\d+),\s*url:\s*"([^"]+)",\s*t:\s*"([^"]*)"/g)].map((m) => ({ n: +m[1], url: m[2], t: m[3] }));
  a.theoryMin = 0;
  a.topics = new Set();
  for (const c of a.chapters) {
    const f = pub(...c.url.replace(/^\//, "").split("/")) + ".html";
    if (!existsSync(f)) { problem(`${a.slug}: chapters.js の ${c.url} が無い`); continue; }
    const h = readFileSync(f, "utf8");
    a.theoryMin += +(h.match(/所要\s*(\d+)\s*分/)?.[1] ?? 0);
    for (const m of h.matchAll(/出題範囲\s*(1\.\d\d\.\d)/g)) a.topics.add(m[1]);
  }
  const metas = (CAGES[a.slug] || [a.slug]).flatMap((d) => walk(join(repo, "containers", d, "lab", "verify")))
    .filter((p) => /\/\d\d\.meta$/.test(p));
  a.exercises = metas.length;
  a.practiceMin = metas.reduce((s, p) => s + +(readFileSync(p, "utf8").match(/^est_min=(\d+)/m)?.[1] ?? 0), 0);
  a.minutes = a.theoryMin + a.practiceMin;
  if (a.method !== "読むだけ" && a.exercises === 0) problem(`${a.slug}: 学習方式が「${a.method}」なのに演習（verify/NN.meta）が無い`);
  if (a.method === "読むだけ" && a.exercises > 0) problem(`${a.slug}: 学習方式が「読むだけ」なのに演習が ${a.exercises} 本ある`);
  // 状態とページのドラフト指定（data-draft）が合っているか
  const pages = walk(pub(a.slug)).filter((p) => p.endsWith(".html") && p !== pub(a.slug, "index.html"));
  const drafted = pages.filter((p) => /<body[^>]*\bdata-draft="1"/.test(readFileSync(p, "utf8"))).length;
  if (a.status === "ドラフト" && drafted !== pages.length) problem(`${a.slug}: 台帳はドラフトなのに、ドラフト指定のページが ${drafted}/${pages.length}`);
  if (a.status === "確認済み" && drafted > 0) problem(`${a.slug}: 台帳は確認済みなのに、ドラフト指定のページが ${drafted} ある`);
}
for (const d of readdirSync(pub())) {
  if (existsSync(pub(d, "theory")) && !bySlug[d]) problem(`public/${d}/ に理論編があるのに台帳に行が無い`);
}
const hm = (m) => (m >= 60 ? `約${Math.floor(m / 60)}時間${m % 60 ? `${m % 60}分` : ""}` : `約${m}分`);
const syl = JSON.parse(readFileSync(join(repo, "tools", "linuc-syllabus.json"), "utf8"));
const topicInfo = Object.fromEntries(syl.topics.map((t) => [t.id, t]));

// 資格の中の並び（前後の記事）
const certSeq = (a) => a.cert ? arts.filter((b) => b.cert === a.cert).sort((x, y) => x.cert_order.localeCompare(y.cert_order)) : [];
const neighbors = (a) => { const s = certSeq(a); const i = s.indexOf(a); return { prev: i > 0 ? s[i - 1] : null, next: i >= 0 && i < s.length - 1 ? s[i + 1] : null }; };
const certLabel = (a) => a.cert ? `${a.cert}${a.cert_exam ? ` ${a.cert_exam}` : ""} 主題${a.cert_order}` : "";
const statusTag = (s) => `<span class="tag ${s === "確認済み" ? "real" : s === "ドラフト" ? "draft" : "rev"}">${s}</span>`;

// 既定の並び: 最終更新の新しい順 → 資格の順 → 記事名
const order = [...arts].sort((x, y) => y.updated.localeCompare(x.updated)
  || (x.cert_order ?? "~").localeCompare(y.cert_order ?? "~") || x.title.localeCompare(y.title, "ja"));

// ---- 道しるべ（全ページ共通の形） ----
const crumbs = (a, type, n) => {
  const top = `<a href="/">トップ</a>`, home = `<a href="/${a.slug}/">${esc(a.title)}</a>`, th = `<a href="/${a.slug}/theory/">理論編</a>`;
  return `<nav class="top">${top} › ` + ({
    home: `<strong>${esc(a.title)}</strong>`,
    practice: `${home} › <strong>実践編</strong>`,
    theory: `${home} › <strong>理論編</strong>`,
    glossary: `${home} › ${th} › <strong>用語辞書</strong>`,
    chapter: `${home} › ${th} › 第${n}章`,
  })[type] + `</nav>`;
};
const footer = (a) => `<footer><a href="/">トップ</a> · <a href="/${a.slug}/">${esc(a.title)}</a> · <a href="/${a.slug}/theory/">理論編 目次</a> · <a href="/${a.slug}/practice/">実践編</a> · <a href="/${a.slug}/theory/glossary">用語辞書</a></footer>`;
const practiceLabel = (a) => a.method === "読むだけ" ? "手元で確かめる（演習なし）" : "実践編";
const nextOf = (a) => {
  const { next } = neighbors(a);
  return next ? { href: `/${next.slug}/`, label: `次の記事: 主題${next.cert_order} ${next.title}` } : { href: "/", label: "記事の一覧へ" };
};
// 目印の間だけを置き換える。無ければ <section id="comments"> の直前（無ければ <footer> の直前）に足す
function setBlock(html, name, inner) {
  const block = `<!-- catalog:${name}（tools/catalog.mjs が台帳から作る。手で編集しない） -->\n${inner}\n<!-- /catalog:${name} -->`;
  const re = new RegExp(`<!-- catalog:${name}[\\s\\S]*?<!-- /catalog:${name} -->`);
  if (re.test(html)) return html.replace(re, block);
  const at = html.indexOf('<section id="comments">') >= 0 ? html.indexOf('<section id="comments">') : html.indexOf("<footer>");
  return at < 0 ? html : html.slice(0, at) + block + "\n\n" + html.slice(at);
}
function normalize(html, a, type, n, where) {
  let h = html;
  if (!/<nav class="top">[\s\S]*?<\/nav>/.test(h)) problem(`${where}: パンくず（nav.top）が無い`);
  h = h.replace(/<nav class="top">[\s\S]*?<\/nav>/, crumbs(a, type, n));
  if (!/<footer>[\s\S]*?<\/footer>/.test(h)) problem(`${where}: footer が無い`);
  h = h.replace(/<footer>[\s\S]*?<\/footer>/, footer(a));
  if (type === "chapter" && n === Math.max(...a.chapters.map((c) => c.n))) {
    // 最後の章の「次」は実践編へ
    h = h.replace(/<nav class="pager">([\s\S]*?)<\/nav>/, (m, inner) => {
      const prev = inner.match(/<a\b[^>]*>[\s\S]*?<\/a>/)?.[0] ?? "";
      return `<nav class="pager">${prev}<a href="/${a.slug}/practice/">${practiceLabel(a)}へ →</a></nav>`;
    });
  }
  if (type === "theory") {
    const first = a.chapters[0];
    h = setBlock(h, "pager", `<nav class="pager"><a href="/${a.slug}/">← ${esc(a.title)}（記事のホーム）</a>` +
      (first ? `<a href="${first.url}">第1章から読む →</a>` : "") + `</nav>`);
  }
  if (type === "practice") {
    const nx = nextOf(a);
    h = setBlock(h, "pager", `<nav class="pager"><a href="/${a.slug}/theory/">← 理論編</a><a href="${nx.href}">${esc(nx.label)} →</a></nav>`);
  }
  // 記事の中から記事ホームへのリンクは、道しるべ（パンくず・フッター・目印の中）だけに置く。
  // 本文の「実践編」「演習NN」は /slug/practice/ を指す（入口を practice/ に移したときの取り違えを止める）
  const body = h.replace(/<nav class="top">[\s\S]*?<\/nav>/, "").replace(/<footer>[\s\S]*?<\/footer>/, "")
    .replace(/<!-- catalog:[\s\S]*?<!-- \/catalog:[a-z]+ -->/g, "");
  const stray = (body.match(new RegExp(`href="/${a.slug}/"`, "g")) || []).length;
  if (stray) problem(`${where}: 本文に記事ホーム（/${a.slug}/）へのリンクが ${stray} 個ある（実践編なら /${a.slug}/practice/）`);
  return h;
}

// ---- 書き出し（--check のときは比べるだけ） ----
const changed = [];
function emit(file, content) {
  const cur = existsSync(file) ? readFileSync(file, "utf8") : null;
  if (cur === content) return;
  changed.push(relative(repo, file));
  if (!CHECK) { mkdirSync(dirname(file), { recursive: true }); writeFileSync(file, content); }
}

// 記事の中のページ
for (const a of arts) {
  if (!a.chapters) continue;
  for (const f of walk(pub(a.slug)).filter((p) => p.endsWith(".html") && p !== pub(a.slug, "index.html"))) {
    const r = relative(pub(a.slug), f);
    let type, n;
    if (r === "practice/index.html") type = "practice";
    else if (r === "theory/index.html") type = "theory";
    else if (r === "theory/glossary.html") type = "glossary";
    else if (/^theory\/\d\d-/.test(r)) { type = "chapter"; n = +r.match(/^theory\/(\d\d)/)[1]; }
    else continue;
    emit(f, normalize(readFileSync(f, "utf8"), a, type, n, relative(repo, f)));
  }
}
// 雛形（生成器が章を作り直したときに、古い道しるべへ戻さないため）
const TEMPLATES = [["linuc-text", "probe/linuc-text-tpl"], ["linuc-admin", "probe/linuc-admin-tpl"], ["linuc-security", "probe/linuc-security-tpl"]];
for (const [slug, dir] of TEMPLATES) {
  const a = bySlug[slug];
  if (!a || !existsSync(join(repo, dir))) continue;
  for (const f of readdirSync(join(repo, dir))) {
    let type, n;
    if (/^00-/.test(f)) type = "practice";
    else if (/^\d\d-/.test(f)) { type = "chapter"; n = +f.slice(0, 2); }
    else continue;
    const p = join(repo, dir, f);
    emit(p, normalize(readFileSync(p, "utf8"), a, type, n, relative(repo, p)));
  }
}

// ---- 記事ホーム ----
const head = (title, desc) => `<!doctype html>
<html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)}</title>
<meta name="description" content="${esc(desc)}">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="/shared/style.css"></head>`;
const draftbar = `<div class="draftbar compact"><p><b>ドラフト</b>: この記事は<b>著者が読者として通していません</b>。本文の出力はすべて実機の記録で、演習は模範解答で通ること・未達のときに判定が鳴ることを確かめてあります。それでも導線の不備は残っている可能性があります。詰まったら各ページ下のコメントか <a href="https://github.com/chai0204/check-then-explain/issues/new/choose">Issue</a> へ。</p></div>`;
const comments = `<section id="comments">
<h2>コメント</h2>
<p class="detail">不具合でも感想でも、一言で構いません。GitHub アカウントでそのまま書けます。<br>
   <b>本文と違う出力が出た場合</b>は <a href="https://github.com/chai0204/check-then-explain/issues/new/choose">Issue</a> のほうが、
   添える情報が決まっているので速く直せます。</p>
<div id="giscus"></div>
</section>`;
const methodNote = (a) => ({
  "読むだけ": "演習は無い。手元で確かめたいときだけ、素のイメージで本文の記録を打ち直せる",
  "演習あり（コンテナ）": "docker か podman で檻（コンテナ）を1つ起動する。特権は渡さない",
  "演習あり（仮想マシン）": "docker か podman で、練習機（仮想マシン）入りの檻を1つ起動する。イメージ約2GB・起動から ssh まで約30秒。KVM も特権も要らない",
})[a.method];
for (const a of arts) {
  if (!a.chapters) continue;
  const { prev, next } = neighbors(a);
  const topics = [...a.topics].sort().map((id) => topicInfo[id]).filter(Boolean);
  const html = `${head(`${a.title} — 確かめて説明する`, a.summary)}
<body${a.status === "ドラフト" ? ' data-draft="1"' : ""} data-theme="${a.slug}">
<div class="wrap">
${crumbs(a, "home")}
${a.status === "ドラフト" ? draftbar + "\n" : ""}<h1>${esc(a.title)}</h1>
<div class="badges">${a.cert ? `<span>${esc(certLabel(a))}</span>` : ""}<span>${esc(a.difficulty)}</span><span>${esc(a.method)}</span><span>${hm(a.minutes)}</span><span>状態: ${esc(a.status)}</span></div>
<p class="lead">${esc(a.summary)}</p>

<div class="card"><h3>想定読者</h3><p>${esc(a.audience)}</p></div>

<h2 id="outcomes">得られるもの</h2>
<ul>
${a.outcomes.split("\n").filter(Boolean).map((o) => `<li>${esc(o)}</li>`).join("\n")}
</ul>

<h2 id="start">進め方</h2>
<div class="toc">
  <a href="/${a.slug}/theory/"><b>理論編</b><span>全${a.chapters.length}章・${hm(a.theoryMin)}。1章ごとに「実際に打つと何が出るか」を先に置いてある。</span></a>
  <a href="/${a.slug}/practice/"><b>${practiceLabel(a)}</b><span>${a.exercises ? `演習${a.exercises}本・${hm(a.practiceMin)}。` : ""}${esc(methodNote(a))}。</span></a>
</div>
<p class="detail">完了推定時間（${hm(a.minutes)}）は、各章の所要時間と演習の目安の合計です。</p>

<h2 id="chapters">章</h2>
<ol class="chlist">
${a.chapters.map((c) => `<li><a href="${c.url}">${esc(c.t)}</a></li>`).join("\n")}
</ol>
${topics.length ? `
<h2 id="syllabus">出題範囲（${esc(a.cert)}${a.cert_exam ? ` ${esc(a.cert_exam)} 試験` : ""}）</h2>
<ul>
${topics.map((t) => `<li>${esc(t.id)} ${esc(t.title)}（重要度 ${t.w}）</li>`).join("\n")}
</ul>
${certMap[a.cert] ? `<p class="detail">どの副題を、どの記事で手を動かせるかの一覧: <a href="${esc(certMap[a.cert])}">${esc(a.cert)} 出題範囲マップ</a></p>` : ""}` : ""}
${a.cert ? `
<h2 id="neighbors">前後の記事（${esc(a.cert)}）</h2>
<nav class="pager plain">${prev ? `<a href="/${prev.slug}/">← 主題${prev.cert_order} ${esc(prev.title)}</a>` : "<span></span>"}${next ? `<a href="/${next.slug}/">主題${next.cert_order} ${esc(next.title)} →</a>` : ""}</nav>` : ""}
${a.related.length ? `
<h2 id="related">関連記事</h2>
<ul>
${a.related.map((s) => bySlug[s]).map((r) => `<li><a href="/${r.slug}/">${esc(r.title)}</a>${r.cert ? `（${esc(certLabel(r))}）` : ""}</li>`).join("\n")}
</ul>` : ""}

<p class="detail">作成 ${a.created} ／ 最終更新 ${a.updated} ／ 関連領域: ${a.domains.map(esc).join("・")}</p>

${comments}
${footer(a)}
</div>
<script src="/shared/comments.js"></script>
</body></html>
`;
  emit(pub(a.slug, "index.html"), html);
}

// ---- トップ（記事の一覧） ----
const opt = (v, label = v) => `<option value="${esc(v)}">${esc(label)}</option>`;
const certs = [...new Set(arts.map((a) => a.cert).filter(Boolean))];
const rows = order.filter((a) => a.chapters).map((a) => {
  const q = [a.title, a.summary, a.cert ?? "", a.cert_order ?? "", a.domains.join(" "), a.method, ...a.chapters.map((c) => c.t)].join(" ");
  return `<tr data-slug="${a.slug}" data-status="${esc(a.status)}" data-cert="${esc(a.cert ?? "")}" data-cert-order="${esc(a.cert_order ?? "")}" data-domain="${esc(a.domains.join(" "))}" data-method="${esc(a.method)}" data-diff="${esc(a.difficulty)}" data-created="${a.created}" data-updated="${a.updated}" data-min="${a.minutes}" data-title="${esc(a.title)}" data-q="${esc(q)}">
  <td class="ttl"><a href="/${a.slug}/">${esc(a.title)}</a><span class="sum">${esc(a.summary.split("。")[0])}。</span></td>
  <td data-label="状態">${statusTag(a.status)}</td>
  <td data-label="関連資格">${a.cert ? `${esc(a.cert)}${a.cert_exam ? ` <span class="cx">${esc(a.cert_exam)}・主題${esc(a.cert_order)}</span>` : ""}` : "—"}</td>
  <td data-label="作成日">${a.created}</td>
  <td data-label="最終更新日">${a.updated}</td>
  <td data-label="難易度">${esc(a.difficulty)}</td>
  <td data-label="完了推定時間">${hm(a.minutes)}</td>
  <td data-label="学習方式" class="wrap2">${esc(a.method).replace("（", "<br>（")}</td>
  <td data-label="関連領域" class="wrap2">${a.domains.map(esc).join("・")}</td>
</tr>`;
}).join("\n");
const top = `${head("確かめて説明する — 出力を根拠に、仕組みを人に説明できるまで", "画面に出た出力を自分で確かめ、なぜそうなるかを人に説明できるようになるまでを引き受ける技術の教材。")}
<body data-theme="">
<div class="wrap">

<h1>確かめて説明する</h1>
<p class="lead">画面に出た出力を自分で確かめ、<b>なぜそうなるかを人に説明できる</b>ようになるまでを引き受けます。<br>
   配った檻の中でわざと壊して壊れ方も見せるので、成功例の写経では終わりません。</p>

<div class="promise">
  <h4>このシリーズの約束</h4>
  <p>本文のコマンドは、<b>あなたの画面に本文と同じ文字を出します。</b>
     出なければ教材のバグとして直します。</p>
  <p>そのためにイメージのダイジェストと apt の時刻を固定し、
     載せる出力はすべて<b>そのイメージの中で実際に打った記録</b>にしています。
     AI の回答は毎回違い、公式ドキュメントはあなたの環境を知りません。</p>
</div>

<div class="notfor">
  <b>向く人</b>: コマンドは打てる。写経すれば動く。でも「なぜ動くのか」を人に説明できない人。<br>
  <b>向かない人</b>: いま動かしたいだけの人（公式の Getting Started のほうが速い）／
  答えだけ欲しい人（AI に聞いたほうが速い）。
</div>

<h2 id="articles">記事の一覧</h2>
<p>いま読めるものを、最終更新の新しい順に並べています。記事名から、その記事のホーム（概要・想定読者・進め方）へ進みます。</p>
<form class="catalog-controls" hidden>
  <input type="search" id="cq" placeholder="記事名・概要・章の題・コマンドで探す" aria-label="記事を探す">
  <select id="c-status" aria-label="状態">${opt("", "状態: すべて")}${["確認済み", "ドラフト", "修正中"].map((s) => opt(s)).join("")}</select>
  <select id="c-cert" aria-label="関連資格">${opt("", "資格: すべて")}${certs.map((c) => opt(c)).join("")}${opt("none", "資格なし")}</select>
  <select id="c-domain" aria-label="関連領域">${opt("", "領域: すべて")}${DOMAINS.filter((d) => arts.some((a) => a.domains.includes(d))).map((d) => opt(d)).join("")}</select>
  <select id="c-method" aria-label="学習方式">${opt("", "方式: すべて")}${["読むだけ", "演習あり（コンテナ）", "演習あり（仮想マシン）"].map((m) => opt(m)).join("")}</select>
  <select id="c-diff" aria-label="難易度">${opt("", "難易度: すべて")}${["入門", "初級", "中級", "上級"].filter((d) => arts.some((a) => a.difficulty === d)).map((d) => opt(d)).join("")}</select>
  <select id="c-sort" aria-label="並べ方">${opt("updated", "新しい順")}${opt("cert", "資格の順")}${opt("time", "短い順")}${opt("title", "記事名の順")}</select>
</form>
<p id="c-count" class="detail"></p>
<div class="catalog-wide scroll"><table class="catalog">
<thead><tr><th>記事名</th><th>状態</th><th>関連資格</th><th>作成日</th><th>最終更新日</th><th>難易度</th><th>完了推定時間</th><th>学習方式</th><th>関連領域</th></tr></thead>
<tbody>
${rows}
</tbody>
</table></div>

<h3>状態の意味</h3>
<ul class="detail">
  <li>${statusTag("確認済み")} 著者が読者として最初から最後まで通したもの。</li>
  <li>${statusTag("ドラフト")} 著者がまだ読者として通していないもの。本文の出力はすべて実機の記録で、演習の判定が通ることも確かめてありますが、人が通さないと見つからない不備（説明の順序・前提の省略など）が残っている可能性があります。SQLite は著者が通した時点で4箇所の不備が出ました。</li>
  <li>${statusTag("修正中")} 不備が見つかって直している途中のもの。</li>
</ul>
${Object.entries(certMap).filter(([, u]) => u).map(([c, u]) => `<p>資格から探す: <a href="${esc(u)}">${esc(c)} 出題範囲マップ</a>（副題ごとに、どの記事で手を動かせるか）</p>`).join("\n")}

${comments}
<footer>確かめて説明する ／ 各記事の検証環境とイメージのダイジェストは、それぞれの実践編に書いてあります。 · <a href="https://github.com/chai0204/check-then-explain">ソース（GitHub）</a></footer>
</div>
<script src="/shared/catalog.js"></script>
<script src="/shared/comments.js"></script>
</body></html>
`;
emit(pub("index.html"), top);

// ---- 結果 ----
if (problems.length) { console.log(`✗ 台帳と実物のずれ ${problems.length} 件`); for (const p of problems) console.log("  " + p); }
if (CHECK) {
  if (changed.length) { console.log(`✗ 台帳から作り直すと変わるファイル ${changed.length} 件（node tools/catalog.mjs で作り直す）`); for (const c of changed.slice(0, 20)) console.log("  " + c); }
  if (!changed.length && !problems.length) console.log(`✔ 台帳と ${arts.length} 記事のページは一致`);
  process.exit(changed.length || problems.length ? 1 : 0);
}
console.log(`書き込み: ${changed.length} ファイル（トップ・記事ホーム ${arts.length}・道しるべ）`);
for (const a of order) console.log(`  ${a.updated} ${a.status.padEnd(4, "　")} ${(a.cert_order ?? "—").padEnd(5)} ${a.title}（理論${a.chapters?.length ?? 0}章・演習${a.exercises ?? 0}本・${hm(a.minutes ?? 0)}）`);
process.exit(problems.length ? 1 : 0);
