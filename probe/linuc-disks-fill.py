#!/usr/bin/env python3
"""LinuC 主題1.05: 章のひな形（probe/linuc-disks-tpl/NN-*.html）の端末ブロックを、通しの記録
（probe/linuc-disks-seq.py が書く logs/linuc-disks-seq.log）からそのまま埋めて public/linuc-disks/theory/ に書き出す。
本文の端末表示を手で写さないための道具（写し間違いをしない。kvm-fill.py と同じ考え方）。

  python3 -I probe/linuc-disks-fill.py [記録]          （既定: logs/linuc-disks-seq.log）
  python3 -I probe/linuc-disks-fill.py --check [記録]  書き出さず、ひな形と記録が対応しているかだけ見る

ひな形の端末ブロック（<pre data-where="…"><code> … </code></pre> のうち "$ " で始まる行を含むもの）は、
"$ コマンド" の行だけを読み、ほかの行は捨てて、記録の出力で置き換える。章の k 番目の "$ " と、記録の同じ章の
k 番目の項目を組にする（記録はひな形から作った入力で取ったので、順番がそのまま対応する。コマンドが違えば止まる）。

"$ コマンド" の行の末尾に置ける指示（HTML のコメントなので、読者の画面には出ない。書き出すときに消す）:
  <!--o keys="n|p|1||+200M|p|w"-->  対話の答え（記録の道具が使う。ここでは何もしない）
  <!--o head=5-->                    出力の最初の5行だけを残し、後ろを "..." にする
  <!--o tail=3-->                    出力の最後の3行だけを残し、前を "..." にする
  <!--o keep="1-3,8,12-14"-->        出力のうち、その行だけを残す（とびとびの間は "..."）
  <!--o note="探す文字列::注釈;;探す文字列2::注釈2"-->
                                     出力のうち「探す文字列」を含む最初の行（前の注釈の行より後ろ）の末尾に
                                     "   ← 注釈" を足す。「^文字列」は行全体がその文字列と同じ行
出力は HTML のために & < > だけを置き換える。コマンドの行は、ひな形に書いたまま（すでに HTML）にする。
"""
import html, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TPL = REPO / "probe" / "linuc-disks-tpl"
OUT = REPO / "public" / "linuc-disks" / "theory"
HEAD = re.compile(r"^========== (\d+)\. (\S+\.html) ==========$")
esc = lambda s: s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def sections(path):
    """記録を章に分け、章ごとに [{cmd, outs}] を返す。端末を開いたときの表示（# --- … # --- ここまで ---）は入れない。"""
    secs, cur, banner, name = {}, None, False, None
    for raw in path.read_text(encoding="utf-8").split("\n"):
        m = HEAD.match(raw)
        if m:
            name = m.group(2)
            secs[name] = []
            cur = None
            continue
        if name is None:
            continue
        if raw.startswith("# --- 端末"):
            banner, cur = True, None
            continue
        if raw.startswith("# --- ここまで"):
            banner = False
            continue
        if banner:
            continue
        if raw.startswith("$ "):
            cur = {"cmd": raw[2:], "outs": []}
            secs[name].append(cur)
        elif cur is not None:
            cur["outs"].append(raw)
    for s in secs.values():
        for e in s:
            while e["outs"] and not e["outs"][-1].strip():
                e["outs"].pop()
            while e["outs"] and not e["outs"][0].strip():
                e["outs"].pop(0)
    return secs


def opt(d, key):
    m = re.search(rf'\b{key}=("([^"]*)"|(\S+))', d or "")
    return None if not m else (m.group(2) if m.group(2) is not None else m.group(3))


def ranges(spec):
    keep = set()
    for part in spec.split(","):
        lo, _, hi = part.partition("-")
        keep.update(range(int(lo), int(hi or lo) + 1))
    return keep


def shape(outs, d):
    """指示どおりに出力を削り、注釈を付ける。返すのは HTML の行。"""
    lines = [esc(l) for l in outs]
    notes = []
    for item in filter(None, (opt(d, "note") or "").split(";;")):
        needle, _, text = item.partition("::")
        notes.append((needle, text))
    pos = 0
    for needle, text in notes:
        for i in range(pos, len(outs)):
            hit = outs[i] == needle[1:] if needle.startswith("^") else needle in outs[i]
            if hit:
                lines[i] = f"{lines[i]}   ← {esc(text)}"
                pos = i + 1
                break
        else:
            raise SystemExit(f"注釈の置き場所が見つからない: {needle!r}（出力: {outs[:6]} …）")
    h, t, k = opt(d, "head"), opt(d, "tail"), opt(d, "keep")
    if h:
        n = int(h)
        lines = lines[:n] + (["..."] if len(lines) > n else [])
    elif t:
        n = int(t)
        lines = (["..."] if len(lines) > n else []) + lines[-n:]
    elif k:
        keep, res, prev = ranges(k), [], 0
        for i, l in enumerate(lines, 1):
            if i in keep:
                if i != prev + 1:
                    res.append("...")
                res.append(l)
                prev = i
        if prev < len(lines):
            res.append("...")
        lines = res
    return lines


def fill(tpl_text, entries, fname):
    k = 0
    def block(m):
        nonlocal k
        attrs, body = m.group(1), m.group(2)
        if not re.search(r"^\$ ", body, re.M):
            return m.group(0)
        res = []
        for raw in body.split("\n"):
            if not raw.startswith("$ "):
                continue
            d = re.search(r"<!--o\b(.*?)-->", raw)
            cmd_html = re.sub(r"<!--.*?-->", "", raw)[2:]
            cmd = html.unescape(re.sub(r"<[^>]+>", "", cmd_html))
            if k >= len(entries):
                raise SystemExit(f"{fname}: 記録の項目が足りない（{k + 1} 番目: $ {cmd}）")
            e = entries[k]
            k += 1
            if e["cmd"] != cmd:
                raise SystemExit(f"{fname}: {k} 番目のコマンドが記録と違う\n  ひな形: {cmd!r}\n  記録  : {e['cmd']!r}")
            res.append("$ " + cmd_html)
            res.extend(shape(e["outs"], d.group(1) if d else ""))
        return f"<pre{attrs}><code>" + "\n".join(res) + "</code></pre>"
    text = re.sub(r"<pre\b([^>]*)><code>([\s\S]*?)</code></pre>", block, tpl_text)
    if k != len(entries):
        raise SystemExit(f"{fname}: 記録の項目が {len(entries)} 個なのに、ひな形のコマンドは {k} 個")
    return text


def main():
    args = [x for x in sys.argv[1:] if not x.startswith("--")]
    check = "--check" in sys.argv
    log = Path(args[0]) if args else REPO / "logs" / "linuc-disks-seq.log"
    secs = sections(log)
    done = 0
    for f in sorted(TPL.glob("[0-9][0-9]-*.html")):
        if f.name not in secs:
            print(f"  （{f.name} は記録に無い。飛ばす）")
            continue
        out = fill(f.read_text(encoding="utf-8"), secs[f.name], f.name)
        if not check:
            (OUT / f.name).write_text(out, encoding="utf-8")
        done += 1
        print(f"  {f.name}: 端末の項目 {len(secs[f.name])} 個")
    print(f"→ {done} 章を{'確かめた' if check else '書き出した'}（記録 {log.relative_to(REPO) if log.is_relative_to(REPO) else log}）")


if __name__ == "__main__":
    main()
