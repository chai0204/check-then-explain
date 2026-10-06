#!/usr/bin/env node
// ローカル確認用の簡易サーバ。依存0。
// Cloudflare Workers の静的アセット配信と同じ解決規則を再現する:
//   /a/b  → public/a/b → public/a/b.html → public/a/b/index.html
// 本番は wrangler が同じことをするので、この差でリンクが壊れないことを先に確かめる。
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { join, extname, resolve } from "node:path";

const ROOT = resolve(process.argv[2] ?? "public");
const PORT = Number(process.argv[3] ?? 8788);
const TYPES = {
  ".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8", ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json", ".svg": "image/svg+xml", ".txt": "text/plain; charset=utf-8",
  ".wasm": "application/wasm",
};

async function pick(p) {
  for (const cand of [p, p + ".html", join(p, "index.html")]) {
    try { if ((await stat(cand)).isFile()) return cand; } catch {}
  }
  return null;
}

createServer(async (req, res) => {
  const path = decodeURIComponent(new URL(req.url, "http://x").pathname);
  if (path.includes("..")) { res.writeHead(400).end("bad path"); return; }
  const found = await pick(join(ROOT, path));
  if (!found) {
    // 本番は wrangler の not_found_handling: "404-page" が public/404.html を返す。
    // ここで text/plain を返すと、404 ページの見た目をローカルで確認できなくなる。
    const page = join(ROOT, "404.html");
    try {
      const body = await readFile(page);
      res.writeHead(404, { "content-type": TYPES[".html"] });
      res.end(body);
    } catch {
      res.writeHead(404, { "content-type": "text/plain; charset=utf-8" }).end("404 " + path);
    }
    return;
  }
  res.writeHead(200, { "content-type": TYPES[extname(found)] ?? "application/octet-stream" });
  res.end(await readFile(found));
}).listen(PORT, "127.0.0.1", () => console.log(`serving ${ROOT} on http://127.0.0.1:${PORT}`));
