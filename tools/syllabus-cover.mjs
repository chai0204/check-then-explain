#!/usr/bin/env node
// LinuC の出題範囲が名指ししている語が、担当コースの章本文に出てくるかを数える。
//
//   node tools/syllabus-cover.mjs              全コース
//   node tools/syllabus-cover.mjs linuc-files  1コースだけ
//
// 「このサイトだけで合格を目指す」と書く以上、副題の詳細に並ぶコマンド・ファイル・用語が
// 本文に1回も出てこないなら、その副題は教えていない。それを機械で数える（2026-10-13 追加）。
// 語の一覧は tools/linuc-syllabus.json（公式ページから抜き出したもの）。
// 照合は章ページ（data-ch を持つ）のテキスト全体。code の中に出てきても数える。
// 終了コード: 1語でも欠けていれば 1。コースのディレクトリがまだ無い副題は「未着手」として数えない。
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const repo = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const only = process.argv[2];
const syl = JSON.parse(readFileSync(join(repo, "tools", "linuc-syllabus.json"), "utf8"));

const text = (h) =>
  h.replace(/<(script|style)\b[\s\S]*?<\/\1>/g, " ")
   .replace(/<[^>]+>/g, " ")
   .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"')
   .replace(/&#39;/g, "'").replace(/&amp;/g, "&");

const cache = new Map();
function courseText(slug) {
  if (cache.has(slug)) return cache.get(slug);
  const dir = join(repo, "public", slug, "theory");
  if (!existsSync(dir)) { cache.set(slug, null); return null; }
  const body = readdirSync(dir)
    .filter((f) => f.endsWith(".html"))
    .map((f) => readFileSync(join(dir, f), "utf8"))
    .filter((h) => /<body[^>]*data-ch="\d+"/.test(h))
    .map(text).join("\n");
  cache.set(slug, body);
  return body;
}

let missingTotal = 0, done = 0, pending = 0;
for (const t of syl.topics) {
  if (only && t.course !== only) continue;
  const body = courseText(t.course);
  if (body === null) { pending += t.w; console.log(`  · ${t.id}（${t.w}）${t.course} はまだ無い`); continue; }
  const missing = t.terms.filter((w) => !body.includes(w));
  if (missing.length === 0) { done += t.w; console.log(`  ✔ ${t.id}（${t.w}）${t.terms.length} 語すべて本文にある`); }
  else { missingTotal += missing.length; console.log(`  ✗ ${t.id}（${t.w}）欠け ${missing.length}/${t.terms.length}: ${missing.join(", ")}`); }
}
console.log(`\n網羅: 重要度 ${done} ぶんの副題で全語が本文にある / 未着手 ${pending} / 欠けた語 ${missingTotal}`);
process.exit(missingTotal > 0 ? 1 : 0);
