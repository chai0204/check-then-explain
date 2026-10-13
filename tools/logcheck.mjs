#!/usr/bin/env node
// 本文の端末表示が、実機の記録（logs/）に本当にあるかを照合する。
//
//   node tools/logcheck.mjs <theme> [ログ ...]
//   例: node tools/logcheck.mjs linuc-services logs/linuc-services-probe.log
//   ログを省略すると logs/<theme>-*.log を全部読む。
//
// 憲章 §3「本文のコマンドは実機完走の記録から引く。ここに無いものは書かない」を機械で担保する。
// 2026-10-13 に LinuC の全範囲を並列で書くことになり、人の目だけでは追えなくなったので作った。
//
// 照合の規則（誤報しない側に倒してある。鳴ったら本文かログのどちらかが違う）:
//   - 対象は章ページ（body に data-ch がある）の <pre …><code> のうち、"$ " で始まる行を含むものだけ。
//     <pre data-where="…"> のように属性が付いていても対象にする（属性で検査をすり抜けさせない）。
//     設定ファイルの中身や説明用の表は端末の記録ではないので見ない。
//   - "$ コマンド" 行: ログのコマンド行（"$ " で始まる行）のどれかに、部分文字列として含まれること。
//     ログで `a; b` とまとめて打ったものを本文で2行に分けて見せるのは許す。
//   - 出力行: ログのどこかに**行として完全一致**で現れること（前後の空白は無視）。
//     数字や時刻を1文字でも書き換えると鳴る。
//   - 省略の印だけの行（"..." / "…" / "（略）" のように全体が括弧書き）は照合しない。
//   - 行末の注釈は "   ← " 以降を落としてから照合する（本文で矢印を足して説明するため）。
//   - コマンドの引用符は ' と " を同じものとして比べる（シェルの意味が同じで、本文で揃えることがあるため）。
//   - "> " で始まる行は直前のコマンドの続き（複数行のコマンド）。"> " を除いた中身がログの行にあればよい。
//
// --strict を付けると、さらに「出力行が、直前の $ 行と同じコマンドのログ項目の出力の中に、順番どおりにある」ことを見る。
//   行がログのどこかにあるだけでは、別のコマンドの出力を取り違えても通ってしまう（取り直しの書き換えで実際に起きた。
//   linuc-files の制作中に発見、2026-10-13）。本文の「コマンド＋直後の出力」の組ごとに、コマンドが一致するログ項目の
//   どれか1つの出力に、その出力行が順番どおりに含まれていればよい（ログが複数あっても、章の順とログの順が違っても判定できる）。
//
// 終了コード: 不一致が1件でもあれば 1。
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const repo = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const STRICT = process.argv.includes("--strict");
const [theme, ...logArgs] = process.argv.slice(2).filter((a) => a !== "--strict");
if (!theme) {
  console.error("使い方: node tools/logcheck.mjs <theme> [ログ ...]");
  process.exit(2);
}

const logs = logArgs.length
  ? logArgs.map((p) => resolve(p))
  : readdirSync(join(repo, "logs"))
      .filter((f) => f.startsWith(theme + "-") && f.endsWith(".log"))
      .map((f) => join(repo, "logs", f));
if (logs.length === 0) {
  console.error(`ログがありません: logs/${theme}-*.log`);
  process.exit(2);
}

const norm = (s) => s.replace(/\s+$/, "").replace(/^\s+/, "");
const q = (s) => s.replace(/"/g, "'");
const logLines = new Set();
const logCmds = [];
const entries = [];   // --strict 用: { cmd, outs[] }（ログの "$ " 行ごとの項目）
for (const p of logs) {
  let cur = null;
  for (const raw of readFileSync(p, "utf8").split("\n")) {
    const l = norm(raw);
    if (raw.startsWith("$ ")) {
      cur = { cmd: q(raw.slice(2).trim()), outs: [] };
      entries.push(cur);
    } else if (cur && l) {
      cur.outs.push(l);
    }
    if (!l) continue;
    logLines.add(l);
    if (raw.startsWith("$ ")) logCmds.push(q(raw.slice(2).trim()));
  }
}
// 出力行の並び outs が、ログ項目の出力の中に順番どおりにあるか（部分列）
const isSubseq = (outs, hay) => {
  let i = 0;
  for (const h of hay) if (i < outs.length && h === outs[i]) i++;
  return i === outs.length;
};

const unescape = (s) =>
  s.replace(/<[^>]+>/g, "")
   .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"')
   .replace(/&#39;/g, "'").replace(/&#x27;/g, "'").replace(/&nbsp;/g, " ")
   .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(+n))
   .replace(/&amp;/g, "&");

const skipLine = (l) => /^(\.\.\.|…|（[^）]*）|\([^)]*略[^)]*\))$/.test(l);
const dropNote = (l) => l.replace(/\s{2,}←.*$/, "");

const dir = join(repo, "public", theme, "theory");
if (!existsSync(dir)) {
  console.error(`章ディレクトリがありません: public/${theme}/theory`);
  process.exit(2);
}
let blocks = 0, cmds = 0, outs = 0;
const bad = [];
for (const f of readdirSync(dir).filter((f) => f.endsWith(".html")).sort()) {
  const html = readFileSync(join(dir, f), "utf8");
  if (!/<body[^>]*data-ch="\d+"/.test(html)) continue;
  for (const m of html.matchAll(/<pre\b[^>]*><code>([\s\S]*?)<\/code><\/pre>/g)) {
    const lines = unescape(m[1]).split("\n");
    if (!lines.some((l) => l.startsWith("$ "))) continue;
    blocks++;
    if (STRICT) {
      // 「コマンド＋直後の出力」の組に分ける
      const groups = [];
      for (const raw of lines) {
        if (raw.startsWith("$ ")) { groups.push({ cmd: q(raw.slice(2).trim()), outs: [] }); continue; }
        if (raw.startsWith("> ")) continue;
        const l = norm(dropNote(raw));
        if (!l || skipLine(l) || !groups.length) continue;
        groups[groups.length - 1].outs.push(l);
      }
      for (const g of groups) {
        if (!g.outs.length) continue;
        const cands = entries.filter((e) => e.cmd === g.cmd || e.cmd.includes(g.cmd));
        if (cands.length && !cands.some((e) => isSubseq(g.outs, e.outs))) {
          // どの行から崩れるかを示す（いちばん長く一致した候補で）
          let best = 0;
          for (const e of cands) { let i = 0; for (const h of e.outs) if (i < g.outs.length && h === g.outs[i]) i++; best = Math.max(best, i); }
          bad.push(`${f}: [$ ${g.cmd}] の出力に順番どおりに無い（${best + 1} 行目から）: ${g.outs[best]}`);
        }
      }
    }
    for (const raw of lines) {
      const l = norm(dropNote(raw));
      if (!l || skipLine(l)) continue;
      if (raw.startsWith("$ ")) {
        cmds++;
        const c = q(raw.slice(2).trim());
        if (!logCmds.some((lc) => lc === c || lc.includes(c)))
          bad.push(`${f}: コマンドがログに無い: $ ${raw.slice(2).trim()}`);
      } else if (raw.startsWith("> ")) {
        cmds++;
        const c = norm(raw.slice(2));
        if (![...logLines].some((ll) => q(ll) === q(c) || q(ll).includes(q(c))))
          bad.push(`${f}: 複数行コマンドの続きがログに無い: > ${c}`);
      } else {
        outs++;
        if (!logLines.has(l)) bad.push(`${f}: 出力がログに無い: ${l}`);
      }
    }
  }
}

console.log(`${theme}: 端末ブロック ${blocks} / コマンド ${cmds} 行 / 出力 ${outs} 行 を ${logs.length} 本のログと照合${STRICT ? "（厳密: 出力は同じコマンドの出力の中に順番どおり）" : ""}`);
if (bad.length) {
  console.log(`✗ 不一致 ${bad.length} 件`);
  for (const b of bad) console.log("  " + b);
  process.exit(1);
}
console.log("✔ 本文の端末表示はすべてログにある");
