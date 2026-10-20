#!/usr/bin/env python3
"""LinuC 主題1.04: 本文の端末ブロックを、端末つきの記録（probe/linuc-packages-seq.py）と本文の順に突き合わせる。

  python3 -I probe/linuc-packages-seqcompare.py [--dir logs] [--chapters 1,2] [--show]

本文の「$ コマンド＋直後の出力」の組を檻ごと（Debian 系 / RPM 系）に本文の順に並べ、端末つきの記録
（logs/linuc-packages-deb-tty.log / -rpm-tty.log）の項目と順に組にする（記録は本文から機械的に作った入力で
取ったので、順番がそのまま対応する）。組ごとに見ること（考え方は probe/linuc-text-seqcompare.py と同じ）:

  1. 本文の出力行が、記録の出力の中に順番どおりにある（logcheck --strict と同じ考え方）
  2. 記録の出力に、本文に無い行が残っていない。本文に省略の印（"..." / "…"）が無い組は、出力が行ごとに全部
     同じであること。印がある組は、印で区切った塊がそれぞれ記録の中でひと続きに現れ、最初の塊は出力の
     先頭から、最後の塊は出力の末尾まで（印で始まる・終わる場合を除く）であること。
  3. 記録で「プロンプトに戻らなかった」組（読者の端末では止まって見える）や、問いが出なかった組は、それだけで違い。

毎回変わる値は伏せて比べる: 日時（ls -l・dpkg -c・date の形）、dnf の「Last metadata expiration check」の
経過時間、ダウンロードの速さ、apt の「Fetched … (速さ)」、rpm の Install Date。
dnf がそのコマンドの中で目録を取ってきた（速さの行がある）ときは、「Last metadata expiration check」の行は
出たり出なかったりする（取ってきてから 1 秒たったかどうかで決まる。dnf/base.py の age != 0 の条件。
2026-10-20 に同じ手順で両方を実測）。そのときに限り、この行は本文・記録のどちらにあっても違いに数えない。
--chapters を付けると、その章だけを突き合わせる（記録もその章だけを取ったときに使う）。
--show を付けると、違った組の記録の出力を全部出す（本文を直すときに使う）。
"""
import argparse, html, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
THEORY = REPO / "public" / "linuc-packages" / "theory"
CAGE_OF = lambda n: "deb" if n <= 8 else "rpm"
MON = r"(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)"
DOW = r"(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)"

q = lambda s: s.replace('"', "'")
dropnote = lambda l: re.sub(r"\s{2,}←.*$", "", l)
skip = lambda l: re.fullmatch(r"(\.\.\.|…|（[^）]*）)", l) is not None
HEAD = re.compile(r"^(=|#){10} .* (=|#){10}$")


def mask(cmd, line):
    line = re.sub(r"Last metadata expiration check: .*$", "Last metadata expiration check: TIME", line)
    line = re.sub(r"\s+\d+(?:\.\d+)?\s*[kMG]?B/s\s*\|\s*\d+(?:\.\d+)?\s*[kMG]?B\s+\d\d:\d\d\s*$", " SPEED", line)
    line = re.sub(r"(Fetched .* in )\S+ \(.*B/s\)", r"\1TIME", line)
    line = re.sub(r"^(Install Date\s*:).*$", r"\1 DATE", line)
    line = re.sub(rf"{DOW} {MON} +\d+ \d\d:\d\d:\d\d(?: [A-Z]{{2,5}})? \d{{4}}", "DATE", line)
    line = re.sub(rf"{DOW} \d+ {MON} \d{{4}} \d\d:\d\d:\d\d(?: [AP]M)?(?: [A-Z]{{2,5}})?", "DATE", line)
    line = re.sub(rf"{MON} +\d+ +(?:\d\d:\d\d|\d{{4}})", "DATE", line)
    line = re.sub(r"\d{4}-\d\d-\d\d \d\d:\d\d(?::\d\d(?:\.\d+)?)?(?: [+-]\d{4})?", "DATETIME", line)
    return line


def page_groups(chapters=None):
    groups = []
    for f in sorted(THEORY.glob("[01][0-9]-*.html")):
        n = int(f.name[:2])
        if chapters and n not in chapters:
            continue
        s = f.read_text(encoding="utf-8")
        for m in re.finditer(r"<pre\b([^>]*)><code>([\s\S]*?)</code></pre>", s):
            lines = html.unescape(re.sub(r"<[^>]+>", "", m.group(2))).split("\n")
            if not any(l.startswith("$ ") for l in lines):
                continue
            mc = re.search(r'data-cage="(deb|rpm)"', m.group(1))
            cage = mc.group(1) if mc else CAGE_OF(n)
            cur = None
            for raw in lines:
                l = dropnote(raw)
                if l.startswith("$ "):
                    cur = {"page": f.name, "cage": cage, "cmd": l[2:], "outs": [], "elide": []}
                    groups.append(cur)
                elif cur is None or l.startswith("> ") or l == ">":
                    continue
                elif l.strip() in ("...", "…"):
                    cur["elide"].append(len(cur["outs"]))
                elif l.strip() and not skip(l.strip()):
                    cur["outs"].append(mask(cur["cmd"], l.strip()))
    return groups


def log_entries(path):
    entries = []
    for raw in path.read_text(encoding="utf-8").split("\n"):
        if HEAD.match(raw.strip()):
            entries.append(None)
            continue
        if raw.startswith("$ "):
            entries.append({"cmd": raw[2:], "outs": [], "raw": []})
            continue
        if not entries or entries[-1] is None:
            continue
        l = raw.strip()
        if "プロンプトに戻らなかった" in l or "が出なかった" in l:
            entries[-1]["stuck"] = True
        if raw.startswith("> ") and not entries[-1]["outs"]:
            continue                      # 続きの行のこだま
        if l:
            entries[-1]["raw"].append(raw.rstrip())
        if l and not skip(l):
            entries[-1]["outs"].append(mask(entries[-1]["cmd"], l))
    return [e for e in entries if e is not None]


def excerpt_ok(P, elide, S):
    cuts = sorted(set(elide))
    segs, prev = [], 0
    for c in cuts:
        segs.append(P[prev:c])
        prev = c
    segs.append(P[prev:])
    head_open = bool(cuts) and cuts[0] == 0
    tail_open = bool(cuts) and cuts[-1] == len(P)
    pos = 0
    for n, seg in enumerate(segs):
        if not seg:
            continue
        if n == 0 and not head_open:
            if S[:len(seg)] != seg:
                return False
            pos = len(seg)
            continue
        found = next((i for i in range(pos, len(S) - len(seg) + 1) if S[i:i + len(seg)] == seg), None)
        if found is None:
            return False
        pos = found + len(seg)
    return tail_open or pos == len(S)


def subseq(need, hay):
    i = 0
    for h in hay:
        if i < len(need) and h == need[i]:
            i += 1
    return i


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=str(REPO / "logs"))
    ap.add_argument("--chapters", default="")
    ap.add_argument("--show", action="store_true")
    a = ap.parse_args()
    chapters = {int(x) for x in a.chapters.split(",") if x.strip()} or None
    groups = page_groups(chapters)
    total = 0
    for cage in ("deb", "rpm"):
        gs = [g for g in groups if g["cage"] == cage]
        if chapters and not gs:
            continue
        p = Path(a.dir) / f"linuc-packages-{cage}-tty.log"
        entries = log_entries(p)
        print(f"── {p.relative_to(REPO) if p.is_relative_to(REPO) else p}")
        bad = 0
        if len(entries) != len(gs):
            print(f"✗ 組の数が違う: 本文 {len(gs)} / 記録 {len(entries)}")
            bad += 1
        for k, (g, e) in enumerate(zip(gs, entries)):
            if q(g["cmd"].strip()) != q(e["cmd"].strip()):
                print(f"✗ {g['page']}: {k+1} 番目の組のコマンドが違う（本文 {g['cmd']!r} / 記録 {e['cmd']!r}）。ここで打ち切る")
                bad += 1
                break
            P, S, elide = g["outs"], e["outs"], g["elide"]
            if any(l.endswith(" SPEED") for l in S):     # 目録を取ってきたコマンド: Last metadata の行は出たり出なかったりする
                lm = "Last metadata expiration check: TIME"
                keep = [i for i, l in enumerate(P) if l != lm]
                elide = [sum(1 for i in keep if i < c) for c in elide]   # 省略の印の位置を、抜いたあとの行番号に直す
                P = [P[i] for i in keep]
                S = [l for l in S if l != lm]
            why = None
            if e.get("stuck"):
                why = "プロンプトに戻らなかった・問いが出なかった（読者の端末では止まって見える）"
            else:
                n = subseq(P, S)
                if n != len(P):
                    why = f"本文の {n+1} 行目が記録に無い（または順が違う）: 「{P[n]}」"
                elif P != S and not (elide and excerpt_ok(P, elide, S)):
                    extra = [l for l in S if l not in P]
                    why = "記録の出力に、本文に無い行がある: " + " / ".join(extra[:6]) + (" …" if len(extra) > 6 else "")
            if why:
                bad += 1
                print(f"✗ {g['page']}: $ {g['cmd']}")
                print("    " + why)
                if a.show:
                    for l in e["raw"]:
                        print("    | " + l)
        print(f"組 {len(gs)} 個を突き合わせた。違い {bad} 件")
        total += bad
    sys.exit(1 if total else 0)


if __name__ == "__main__":
    main()
