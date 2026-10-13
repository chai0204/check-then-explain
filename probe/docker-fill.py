#!/usr/bin/env python3
"""docker / podman の記事: 章のひな形（probe/<slug>-tpl/NN-*.html）の @@ 行を、通しの記録（logs/<slug>-seq.log）から
埋めて public/<slug>/theory/ に書き出す。端末表示を手で写さないための道具（写し間違いを構造的に無くす）。

  python3 -I probe/docker-fill.py --slug docker [--log logs/docker-seq.log]

通しの記録は、同じひな形の @@ 行を同じ順に打って取ったもの（probe/docker-seq.py --src tpl）なので、
ひな形の k 番目の @@ 行と、記録の k 番目の "$ " 項目を組にする（文字列が一致しなければ止める）。

ひな形の書き方（<pre …><code> の中の行頭が @@ の行が置き換わる。ほかの行はそのまま出る）:
  @@ <コマンド>                     → "$ <コマンド>" と、記録にあるその出力を全部
  @@ <コマンド>  ## noout           → "$ <コマンド>" だけ（出力は出さない。出力が無いことを示すときは使わない）
  @@ <コマンド>  ## elide           → "$ <コマンド>" と "..." 1行（出力を略したことを示す。ログインの案内など）
  @@ <コマンド>  ## lines=3-8       → 出力の3〜8行目だけ（前後を削ったら "..." を入れる）
  @@ <コマンド>  ## head=5          → 出力の先頭5行（残りがあれば "..."）
  @@ <コマンド>  ## grep=正規表現   → 出力のうち一致する行だけ（間を削ったら "..."）
  @@ <コマンド>  ## id=名前         → 地の文の {{名前:正規表現}} を、この出力から抜いた値（最初の括弧）で置き換える
  @@> <続き>                        → 複数行のコマンドの続きの行（"> <続き>" になる）
  @@note <部分文字列> => <注記>      → 直前に出した行のうち、部分文字列を含む最後の行の末尾に "   ← 注記"
指定はスペース区切りで並べられる（例: ## id=pid head=3）。
"""
import argparse, html, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def parse_log(text):
    recs, cur = [], None
    for line in text.split("\n"):
        if line.startswith("$ "):
            cur = {"cmd": line[2:], "cont": [], "out": []}
            recs.append(cur)
        elif re.match(r"^(={10}|#{10}) .+ (={10}|#{10})$", line):
            cur = None
        elif cur is not None:
            if line.startswith("> ") and not cur["out"] and len(cur["cont"]) < 50 and cur.get("conting", True):
                cur["cont"].append(line[2:])
                continue
            cur["conting"] = False
            cur["out"].append(line.rstrip())
    for r in recs:
        while r["out"] and not r["out"][-1].strip():
            r["out"].pop()
        while r["out"] and not r["out"][0].strip():
            r["out"].pop(0)
    return recs


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def select(out, mods):
    if "noout" in mods:
        return []
    if "elide" in mods:          # 出力はあるが本文では略す（ログインの案内など。毎回変わる時刻を含む）
        return ["..."] if out else []
    if "lines" in mods:
        a, b = (int(x) for x in mods["lines"].split("-"))
        sel = out[a - 1:b]
        return (["..."] if a > 1 else []) + sel + (["..."] if b < len(out) else [])
    if "head" in mods:
        n = int(mods["head"])
        return out[:n] + (["..."] if len(out) > n else [])
    if "grep" in mods:
        rx = re.compile(mods["grep"])
        res, last = [], -1
        for i, l in enumerate(out):
            if rx.search(l):
                if res and i != last + 1:
                    res.append("...")
                elif not res and i > 0:
                    res.append("...")
                res.append(l)
                last = i
        if res and last < len(out) - 1:
            res.append("...")
        return res
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--slug", required=True)
    ap.add_argument("--log", default=None)
    a = ap.parse_args()
    log = Path(a.log or REPO / "logs" / f"{a.slug}-seq.log")
    recs = parse_log(log.read_text(encoding="utf-8"))
    tpl_dir = REPO / "probe" / f"{a.slug}-tpl"
    out_dir = REPO / "public" / a.slug / "theory"
    out_dir.mkdir(parents=True, exist_ok=True)
    k = 0
    errors = []
    for f in sorted(tpl_dir.glob("[0-9][0-9]-*.html")):
        src = f.read_text(encoding="utf-8")
        ids = {}

        def fill_block(m):
            nonlocal k
            body = m.group(2)
            if not re.search(r"^@@ ", body, re.M):
                return m.group(0)
            res = []
            for line in body.split("\n"):
                if line.startswith("@@note "):
                    sub, note = line[7:].split(" => ", 1)
                    for j in range(len(res) - 1, -1, -1):
                        if sub in html.unescape(res[j]) and not res[j].startswith("$ "):
                            res[j] += "   ← " + esc(note)
                            break
                    else:
                        errors.append(f"{f.name}: 注記の当て先が無い: {sub}")
                    continue
                if line.startswith("@@> "):
                    # ひな形の中身はすでに HTML（&amp; &gt; と書いてある）なので、そのまま使う
                    res.append("&gt; " + line[4:])
                    continue
                if not line.startswith("@@ "):
                    res.append(line)
                    continue
                cmdpart = line[3:]
                mods = {}
                mm = re.search(r"\s+##\s+(.*)$", cmdpart)
                if mm:
                    for tok in mm.group(1).split():
                        kk, _, vv = tok.partition("=")
                        mods[kk] = vv
                    cmdpart = cmdpart[:mm.start()]
                cmd = html.unescape(cmdpart)
                if k >= len(recs):
                    errors.append(f"{f.name}: 記録が足りない（{cmd}）")
                    res.append("$ " + esc(cmd))
                    continue
                r = recs[k]
                k += 1
                if r["cmd"] != cmd:
                    errors.append(f"{f.name}: {k} 番目のコマンドが記録と違う: ひな形 {cmd!r} / 記録 {r['cmd']!r}")
                if "id" in mods:
                    ids[mods["id"]] = r["out"]
                res.append("$ " + esc(cmd))
                res.extend(esc(l) for l in select(r["out"], mods))
            return m.group(1) + "\n".join(res) + m.group(3)

        dst = re.sub(r"(<pre\b[^>]*><code>)([\s\S]*?)(</code></pre>)", fill_block, src)

        def sub_ref(m):
            name, rx = m.group(1), m.group(2)
            lines = ids.get(name)
            if lines is None:
                errors.append(f"{f.name}: {{{{{name}:…}}}} の id が無い")
                return m.group(0)
            for l in lines:
                mm = re.search(html.unescape(rx), l)
                if mm:
                    return esc(mm.group(1))
            errors.append(f"{f.name}: {{{{{name}:{rx}}}}} が出力に見つからない")
            return m.group(0)

        dst = re.sub(r"\{\{([a-z0-9_]+):(.+?)\}\}", sub_ref, dst)
        (out_dir / f.name).write_text(dst, encoding="utf-8")
    if k != len(recs):
        errors.append(f"記録の項目 {len(recs)} 個のうち {k} 個しか使っていない（ひな形と記録の数が違う）")
    for e in errors:
        print("✗ " + e, file=sys.stderr)
    print(f"{a.slug}: {k} 組を埋めた（記録 {log.name}）", file=sys.stderr)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
