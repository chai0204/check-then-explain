#!/usr/bin/env python3
"""LinuC 主題1.04: 章の端末ブロックの出力を、端末つきの記録（logs/linuc-packages-{deb,rpm}-tty.log）から写す。

  python3 -I probe/linuc-packages-fill.py 3 [4 ...]

書くときは、出力を記録から写したい $ 行の下に "@@" の1行だけを置く（問いに答えるコマンドは、答えの行
「Do you want to continue? [Y/n] y」なども一緒に置く。記録を取る probe/linuc-packages-seq.py がそれを見て答える）。
先に記録を取り（seq.py --chapters N）、このスクリプトで "@@" を置いたコマンドの出力を、記録の出力で丸ごと置き換える。
"@@" の無いコマンドの出力は触らない（"..." で省いた行など、手で整えたものを残すため）。
置き換えたあとの長い出力を "..." で省くのは手でやる（突き合わせは probe/linuc-packages-seqcompare.py）。

  python3 -I probe/linuc-packages-fill.py --refresh 1 [2 ...]

記録を取り直したあとに使う。"@@" の無いコマンドも含めて、本文の出力行のうち、毎回変わる値（日時・経過時間・
速さ。伏せ方は seqcompare と同じ）だけが記録と違う行を、記録の行で置き換える。"..." で省いた形や行の選び方は
変えない。伏せた形でも記録に無い行は触らない（それは seqcompare が違いとして出す）。
"""
import html, importlib.util, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
THEORY = REPO / "public" / "linuc-packages" / "theory"
CAGE_OF = lambda n: "deb" if n <= 8 else "rpm"
HEAD = re.compile(r"^(=|#){10} (.*) (=|#){10}$")


def log_sections(cage):
    """記録を章ごとに: {ファイル名: [(cmd, cont, outs), ...]}"""
    p = REPO / "logs" / f"linuc-packages-{cage}-tty.log"
    secs, cur, ent = {}, None, None
    for raw in p.read_text(encoding="utf-8").split("\n"):
        m = HEAD.match(raw.strip())
        if m:
            name = m.group(2).split(". ", 1)[-1]
            cur = secs.setdefault(name, [])
            ent = None
            continue
        if cur is None:
            continue
        if raw.startswith("$ "):
            ent = [raw[2:], [], []]
            cur.append(ent)
        elif ent is not None and raw.startswith("> ") and not ent[2]:
            ent[1].append(raw[2:])
        elif ent is not None:
            ent[2].append(raw.rstrip())
    for v in secs.values():
        for e in v:
            while e[2] and e[2][-1] == "":
                e[2].pop()
            while e[2] and e[2][0] == "":
                e[2].pop(0)
    return secs


def _mask():
    """伏せ方は seqcompare と同じものを使う（-I では同じディレクトリを import できないので、場所を指して読む）"""
    spec = importlib.util.spec_from_file_location("seqcompare", REPO / "probe" / "linuc-packages-seqcompare.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.mask


def refresh_outs(cmd, outs, rec, mask):
    """本文の出力行 outs を、記録の出力 rec と順に組にし、伏せると同じで生の形が違う行だけを記録の行にする"""
    res, pos, n = [], 0, 0
    for o in outs:
        t = o.strip()
        if not t or t in ("...", "…"):
            res.append(o)
            continue
        mo = mask(cmd, t)
        hit = next((i for i in range(pos, len(rec)) if rec[i].strip() and mask(cmd, rec[i].strip()) == mo), None)
        if hit is None:
            res.append(o)
            continue
        pos = hit + 1
        if rec[hit].rstrip() != o.rstrip():
            res.append(rec[hit].rstrip())
            n += 1
        else:
            res.append(o)
    return res, n


def fill(n, refresh=False):
    f = next(THEORY.glob(f"{n:02d}-*.html"))
    s = f.read_text(encoding="utf-8")
    entries = log_sections(CAGE_OF(n)).get(f.name)
    if entries is None:
        sys.exit(f"{f.name}: 記録に章の区切りが無い（先に seq.py --chapters {n} を取る）")
    k, changed = 0, 0
    mask = _mask() if refresh else None

    def block(m):
        nonlocal k, changed
        body = html.unescape(m.group(2))
        lines = body.split("\n")
        if not any(l.startswith("$ ") for l in lines):
            return m.group(0)
        out, i = [], 0
        while i < len(lines):
            l = lines[i]
            if not l.startswith("$ "):
                out.append(l)
                i += 1
                continue
            cmd = l[2:]
            j = i + 1
            conts = []
            while j < len(lines) and (lines[j].startswith("> ") or lines[j] == ">"):
                conts.append(lines[j])
                j += 1
            outs = []
            while j < len(lines) and not lines[j].startswith("$ "):
                outs.append(lines[j])
                j += 1
            if k >= len(entries):
                sys.exit(f"{f.name}: 記録のほうが短い（{k + 1} 番目の $ 行 {cmd!r}）")
            e = entries[k]
            k += 1
            if e[0].replace('"', "'") != re.sub(r"\s{2,}←.*$", "", cmd).replace('"', "'"):
                sys.exit(f"{f.name}: {k} 番目のコマンドが記録と違う（本文 {cmd!r} / 記録 {e[0]!r}）")
            out.append(l)
            out.extend(conts)
            if any(o.strip() == "@@" for o in outs):
                out.extend(e[2])
                changed += 1
            elif refresh:
                new, c = refresh_outs(e[0], outs, e[2], mask)
                out.extend(new)
                changed += c
            else:
                out.extend(outs)
            i = j
        new = html.escape("\n".join(out), quote=False)
        return f"<pre{m.group(1)}><code>{new}</code></pre>"

    s2 = re.sub(r"<pre\b([^>]*)><code>([\s\S]*?)</code></pre>", block, s)
    if k != len(entries):
        print(f"注意: {f.name}: 本文の $ 行 {k} 個 / 記録 {len(entries)} 個", file=sys.stderr)
    f.write_text(s2, encoding="utf-8")
    what = "行を記録の値に揃えた" if refresh else "個のコマンドの出力を記録から写した"
    print(f"{f.name}: {changed} {what}", file=sys.stderr)


if __name__ == "__main__":
    args = sys.argv[1:]
    refresh = "--refresh" in args
    for a in [x for x in args if x != "--refresh"]:
        fill(int(a), refresh)
