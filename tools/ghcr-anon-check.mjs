#!/usr/bin/env node
// 本文が案内しているイメージを、ログインしていない読者と同じ条件で取れるかを確かめる。
//
//   node tools/ghcr-anon-check.mjs              public/ の全部
//   node tools/ghcr-anon-check.mjs kvm qemu     その記事（public/<slug>/）だけ
//
// GHCR のパッケージは作られたときは非公開で、公開への切り替えはブラウザでしかできない（publish.md §6）。
// 切り替え忘れは check.mjs では分からず、手元の docker はログイン済みなので pull も通ってしまう。
// 2026-10-14 に、道具の記事の lab と LinuC の lab-linuc が非公開のまま本文に載っていたのが見つかったので作った。
// docker logout をしなくて済むように、認証情報を使わずにレジストリの API を直接引く。
//
// 見るもの（本文の「ghcr.io/<owner>/<repo>:<tag>@sha256:…」ごと）:
//   - 匿名のトークンでマニフェストが取れ、中身の sha256 が本文の digest と一致する（index なら中の各マニフェストも）
//   - config と全レイヤの blob を取り出せる（先頭の1バイトだけ読む。転送先のストレージには認証を付けない）
//   - タグが同じ digest を指している（ずれていても本文の digest で取れるが、タグだけで打った読者と別物になる）
// 取れないパッケージがあれば、切り替える画面の URL を出す。1つでも問題があれば終了コード 1。
import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "public");
const slugs = process.argv.slice(2);
const dirs = slugs.length ? slugs.map((s) => join(root, s)) : [root];

function* htmlFiles(dir) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) yield* htmlFiles(p);
    else if (name.endsWith(".html")) yield p;
  }
}

const refs = new Map();
for (const d of dirs) {
  if (!existsSync(d)) { console.error(`✗ ${d} が無い`); process.exit(1); }
  for (const f of htmlFiles(d))
    for (const m of readFileSync(f, "utf8").matchAll(/ghcr\.io\/([a-z0-9-]+)\/([a-z0-9._-]+):([A-Za-z0-9._-]+)@(sha256:[0-9a-f]{64})/g))
      refs.set(m[0], { owner: m[1], repo: m[2], tag: m[3], digest: m[4] });
}

const ACCEPT = [
  "application/vnd.oci.image.index.v1+json",
  "application/vnd.docker.distribution.manifest.list.v2+json",
  "application/vnd.oci.image.manifest.v1+json",
  "application/vnd.docker.distribution.manifest.v2+json",
].join(", ");
const tokens = new Map();
async function auth(ref) {
  const key = `${ref.owner}/${ref.repo}`;
  if (!tokens.has(key)) {
    const r = await fetch(`https://ghcr.io/token?scope=repository:${key}:pull`);
    tokens.set(key, r.ok ? (await r.json()).token : null);
  }
  const t = tokens.get(key);
  return t ? { Authorization: `Bearer ${t}` } : {};
}
async function manifest(ref, what) {
  const r = await fetch(`https://ghcr.io/v2/${ref.owner}/${ref.repo}/manifests/${what}`, { headers: { Accept: ACCEPT, ...(await auth(ref)) } });
  if (!r.ok) { await r.body?.cancel(); throw Object.assign(new Error(`HTTP ${r.status}`), { status: r.status }); }
  const body = Buffer.from(await r.arrayBuffer());
  return { json: JSON.parse(body), digest: "sha256:" + createHash("sha256").update(body).digest("hex") };
}
async function blob(ref, digest) {
  const url = `https://ghcr.io/v2/${ref.owner}/${ref.repo}/blobs/${digest}`;
  let r = await fetch(url, { headers: { Range: "bytes=0-0", ...(await auth(ref)) }, redirect: "manual" });
  const loc = r.headers.get("location");
  if (r.status >= 300 && r.status < 400 && loc) {
    await r.body?.cancel();
    r = await fetch(new URL(loc, url), { headers: { Range: "bytes=0-0" } });
  }
  await r.body?.cancel();
  return r.status;
}

let bad = 0;
const closed = new Set();
for (const ref of [...refs.values()].sort((a, b) => `${a.repo}:${a.tag}`.localeCompare(`${b.repo}:${b.tag}`))) {
  const name = `${ref.repo}:${ref.tag}`;
  let top;
  try { top = await manifest(ref, ref.digest); } catch (e) {
    // トークンが出ない・401・403 はパッケージが非公開（か無い）。トークンが出て 404 なら、その digest がレジストリに無い
    const shut = tokens.get(`${ref.owner}/${ref.repo}`) === null || e.status === 401 || e.status === 403;
    console.log(`✗ ${name}: マニフェストを取れない（${e.message}。${shut ? "パッケージが非公開か、無い" : "その digest はレジストリに無い"}）`);
    if (shut) closed.add(`${ref.owner}/${ref.repo}`);
    bad++;
    continue;
  }
  const problems = [];
  if (top.digest !== ref.digest) problems.push("マニフェストの中身が digest と合わない");
  const mans = top.json.manifests ? [] : [top.json];
  for (const m of top.json.manifests ?? []) {
    const sub = await manifest(ref, m.digest);
    if (sub.digest !== m.digest) problems.push(`中のマニフェスト ${m.digest.slice(0, 19)}… の中身が合わない`);
    mans.push(sub.json);
  }
  const blobs = new Map();
  for (const m of mans) for (const b of [m.config, ...(m.layers ?? [])]) if (b) blobs.set(b.digest, b.size ?? 0);
  const codes = await Promise.all([...blobs.keys()].map(async (d) => [d, await blob(ref, d)]));
  const failed = codes.filter(([, s]) => s !== 200 && s !== 206);
  if (failed.length) problems.push(`取り出せない blob: ${failed.map(([d, s]) => `${d.slice(0, 19)}…（HTTP ${s}）`).join(", ")}`);
  try {
    const tg = await manifest(ref, ref.tag);
    if (tg.digest !== ref.digest) problems.push(`タグ ${ref.tag} は別の digest（${tg.digest.slice(0, 19)}…）を指している`);
  } catch (e) { problems.push(`タグ ${ref.tag} を引けない（${e.message}）`); }
  const mb = [...blobs.values()].reduce((a, b) => a + b, 0) / 1e6;
  if (problems.length) bad++;
  console.log(`${problems.length ? "✗" : "✓"} ${name.padEnd(28)} blob ${blobs.size - failed.length}/${blobs.size} ${mb.toFixed(1).padStart(7)} MB${problems.length ? "  " + problems.join(" / ") : ""}`);
}
for (const p of closed) {
  const [o, r] = p.split("/");
  console.log(`  → ${p} は匿名では取れない。https://github.com/users/${o}/packages/container/${r}/settings の Danger Zone → Change visibility → Public`);
}
console.log(`確かめたイメージ ${refs.size} 個 / 問題 ${bad} 個`);
process.exit(bad ? 1 : 0);
