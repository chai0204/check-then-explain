#!/usr/bin/env python3
"""LinuC 主題1.03: 本文の端末ブロックを、通しの記録（probe/linuc-text-seq.py）と本文の順に突き合わせる。

  python3 -I probe/linuc-text-seqcompare.py [通しの記録 ...]     （既定: logs/linuc-text-seq.log）

本文の「$ コマンド＋直後の出力」の組の k 番目と、通しの記録の k 番目の項目を組にする
（通しの記録は本文から機械的に作った入力で取ったので、順番がそのまま対応する）。組ごとに2つを見る。

  1. 本文の出力行が、通しの出力の中に順番どおりにある（logcheck --strict と同じ考え方）
  2. 通しの出力に、本文に無い行が残っていないか。本文に省略の印（"..." / "…"）が無い組は、出力が
     行ごとに全部同じであること。印がある組は、印で区切った塊がそれぞれ通しの中でひと続きに現れ、
     最初の塊は出力の先頭から、最後の塊は出力の末尾まで（印で始まる・終わる場合を除く）であること。
     本文より行が多いと、読者は本文と違う画面を見る（前の章の残りなど）。
  3. 通しの記録で「プロンプトに戻らなかった」組（読者の端末では止まって見える）は、それだけで違いとする。

毎回変わる値は伏せて比べる: ls -l の日時、YYYY-MM-DD HH:MM の日時、ls -i の inode 番号。
"""
import html, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PAGES = sorted((REPO / "public" / "linuc-text" / "theory").glob("[01][0-9]-*.html"))
SRC_LOGS = [REPO / "logs" / f for f in ("linuc-text-probe.log", "linuc-text-probe-extra.log",
                                         "linuc-text-probe-exam.log")]
seqs = [Path(a) for a in sys.argv[1:]] or [REPO / "logs" / "linuc-text-seq.log"]

q = lambda s: s.replace('"', "'")
dropnote = lambda l: re.sub(r"\s{2,}←.*$", "", l)
skip = lambda l: re.fullmatch(r"(\.\.\.|…|（[^）]*）)", l) is not None
ELIDE = "\x00省略"                   # 本文の "..." / "…"（照合はしないが、どこで省いたかは覚えておく）
HEAD = re.compile(r"^(=|#){10} .* (=|#){10}$")


def mask(cmd, line):
    line = re.sub(r"(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) +\d+ +(\d\d:\d\d|\d{4})", "DATE", line)
    line = re.sub(r"\d{4}-\d\d-\d\d \d\d:\d\d(:\d\d(\.\d+)?)?( [+-]\d{4})?", "DATETIME", line)
    if re.search(r"\bls\s+(-\w*\s+)*-\w*i", cmd):
        line = re.sub(r"\b\d{3,}\b", "INO", line)
    return line


def page_groups():
    groups = []
    for f in PAGES:
        s = f.read_text(encoding="utf-8")
        for m in re.finditer(r"<pre\b[^>]*><code>([\s\S]*?)</code></pre>", s):
            lines = html.unescape(re.sub(r"<[^>]+>", "", m.group(1))).split("\n")
            if not any(l.startswith("$ ") for l in lines):
                continue
            for raw in lines:
                l = dropnote(raw)
                if l.startswith("$ "):
                    groups.append({"page": f.name, "cmd": l[2:], "outs": [], "elide": []})
                elif not groups or groups[-1]["page"] != f.name or l.startswith("> "):
                    continue
                elif l.strip() in ("...", "…"):
                    groups[-1]["elide"].append(len(groups[-1]["outs"]))
                elif l.strip() and not skip(l.strip()):
                    groups[-1]["outs"].append(mask(groups[-1]["cmd"], l.strip()))
    return groups


def log_entries(path):
    entries, cont = [], False
    for raw in path.read_text(encoding="utf-8").split("\n"):
        if HEAD.match(raw.strip()):
            entries.append(None)
            continue
        if raw.startswith("$ "):
            entries.append({"cmd": raw[2:], "outs": []})
            cont = True
            continue
        if not entries or entries[-1] is None:
            continue
        if cont and raw.startswith("> "):
            continue
        cont = False
        l = raw.strip()
        if "プロンプトに戻らなかった" in l:
            entries[-1]["stuck"] = True
        if l and not skip(l):
            entries[-1]["outs"].append(mask(entries[-1]["cmd"], l))
    return [e for e in entries if e is not None]


def excerpt_ok(P, elide, S):
    """省略の印の位置 elide（P の何行目の前で省いたか）で P を塊に分け、S の中に順にひと続きで現れるか。"""
    cuts = sorted(set(elide))
    segs, prev = [], 0
    for c in cuts:
        segs.append(P[prev:c])
        prev = c
    segs.append(P[prev:])
    head_open = bool(cuts) and cuts[0] == 0          # 印で始まる（先頭を省いた）
    tail_open = bool(cuts) and cuts[-1] == len(P)    # 印で終わる（末尾を省いた）
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


recorded = {}
for p in SRC_LOGS:
    for e in log_entries(p):
        recorded.setdefault(q(e["cmd"].strip()), []).append(e["outs"])

groups = page_groups()
total_bad = 0
for seqp in seqs:
    entries = log_entries(seqp)
    print(f"── {seqp.relative_to(REPO) if seqp.is_relative_to(REPO) else seqp}")
    bad = 0
    if len(entries) != len(groups):
        print(f"✗ 組の数が違う: 本文 {len(groups)} / 通し {len(entries)}")
        bad += 1
    for k, (g, e) in enumerate(zip(groups, entries)):
        if q(g["cmd"].strip()) != q(e["cmd"].strip()):
            print(f"✗ {g['page']}: {k+1} 番目の組のコマンドが違う（本文 {g['cmd']!r} / 通し {e['cmd']!r}）。ここで打ち切る")
            bad += 1
            break
        if e.get("stuck"):
            bad += 1
            print(f"✗ {g['page']}: $ {g['cmd']}")
            print("    プロンプトに戻らなかった（読者の端末では止まって見える）")
            continue
        P, S = g["outs"], e["outs"]
        n = subseq(P, S)
        if n != len(P):
            bad += 1
            print(f"✗ {g['page']}: $ {g['cmd']}")
            print(f"    本文の {n+1} 行目が通しに無い（または順が違う）: 「{P[n]}」")
            print("    通し: " + " / ".join(S[:10]) + (" …" if len(S) > 10 else ""))
            continue
        if P == S:
            continue
        if g["elide"] and excerpt_ok(P, g["elide"], S):
            continue          # 本文は "..." で省いて見せている。省いていない塊はすべて通しと同じ
        bad += 1
        extra = [l for l in S if l not in P]
        print(f"✗ {g['page']}: $ {g['cmd']}")
        print("    通しの出力に、本文に無い行がある: " + " / ".join(extra[:8]) + (" …" if len(extra) > 8 else ""))
        cands = recorded.get(q(g["cmd"].strip()), [])
        if any(o == S for o in cands):
            print("    （同じ出力が本文の記録にもある。本文の側で行を落としていないか確かめる）")
    print(f"組 {len(groups)} 個を突き合わせた。違い {bad} 件")
    total_bad += bad
sys.exit(1 if total_bad else 0)
