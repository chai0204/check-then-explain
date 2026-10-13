#!/usr/bin/env python3
"""KVM の記事: 本文の端末ブロックを、通しの記録（probe/kvm-seq.py --pages。端末つき・1つのシェル）と本文の順に突き合わせる。

  python3 -I probe/kvm-seqcompare.py [通しの記録 ...]     （既定: logs/kvm-seq.log）

作りは probe/linuc-services-seqcompare.py（主題1.09）にならった。本文の「$ コマンド＋直後の出力」の組の k 番目と、
通しの記録の k 番目の項目を組にする（通しの記録は本文から機械的に作った入力で取ったので、順番がそのまま対応する）。
data-where に「Ubuntu」とあるブロック（別の PC で取った記録）は、通しでは打たないので数えない。

  1. 本文の出力行が、通しの出力の中に順番どおりにある（logcheck --strict と同じ考え方）
  2. 通しの出力に、本文に無い行が残っていないか。本文に省略の印（"..." / "…"）が無い組は、出力が
     行ごとに全部同じであること。印がある組は、印で区切った塊がそれぞれ通しの中でひと続きに現れること。
  3. 通しの記録で「プロンプトに戻らなかった」組は、それだけで違いとする。

毎回変わる値だけを伏せて比べる（mask）: 時刻・日付、PID、QEMU を起動してから ssh までの秒数とカーネルが動き出した秒数、
止まるまでの秒数、ps の経過時間と CPU 時間、systemd-analyze の時間、journal の Startup finished の時間、
dmesg の行頭の時刻、Last login の行、vm start の待ち時間の行（「起動中… N秒」の行の数は速さで変わる）。
列の揃え（空白の数）は値の桁で変わるので、続く空白は1つにまとめて比べる。
"""
import html, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PAGES = sorted((REPO / "public" / "kvm" / "theory").glob("[0-9][0-9]-*.html"))
seqs = [Path(a) for a in sys.argv[1:]] or [REPO / "logs" / "kvm-seq.log"]

q = lambda s: s.replace('"', "'")
dropnote = lambda l: re.sub(r"\s{2,}←.*$", "", l)
skip = lambda l: re.fullmatch(r"(\.\.\.|…|（[^）]*）)", l) is not None
HEAD = re.compile(r"^(=|#){10} .* (=|#){10}$")
MON = r"(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)"

MASKS = [
    (re.compile(r"（QEMU を起動してから [\d.]+ 秒。カーネルの最初の表示は [\d.]+ 秒の時点）"), "（QEMU を起動してから T 秒。カーネルの最初の表示は T 秒の時点）"),
    (re.compile(r"（QEMU を起動してから [\d.]+ 秒）"), "（QEMU を起動してから T 秒）"),
    (re.compile(r"止まりました（[\d.]+ ?秒）"), "止まりました（T 秒）"),
    (re.compile(r"練習機が起動しました（\d+秒）"), "練習機が起動しました（T秒）"),
    (re.compile(r"Startup finished in .*"), "Startup finished in T"),
    (re.compile(r"graphical\.target reached after .*"), "graphical.target reached after T"),
    (re.compile(r"^\[ *\d+\.\d+\] "), "[T] "),                                     # dmesg の行頭
    (re.compile(r"\bPID \d+\b"), "PID X"),
    (re.compile(r"\b\d{1,2} " + MON + r" \d{4} \d\d:\d\d:\d\d"), "DATE"),
    (re.compile(MON + r" +\d+ +(\d\d:\d\d(:\d\d)?|\d{4})"), "DATE"),            # ls -l の日付
    (re.compile(r"\d{4}-\d\d-\d\d \d\d:\d\d:\d\d"), "DATETIME"),
    (re.compile(r"\b\d\d:\d\d:\d\d\b"), "TIME"),
]


def mask(cmd, line):
    for pat, rep in MASKS:
        line = pat.sub(rep, line)
    line = re.sub(r"\s{2,}", " ", line).strip()
    if re.search(r"\bps -o pid,etimes,times", cmd) and re.match(r"^\d+ \d+ \d+ ", line):
        line = re.sub(r"^\d+ \d+ \d+ ", "PID ELAPSED TIME ", line)              # PID・経過秒・CPU 秒
    if line.startswith("Last login: "):
        line = "Last login: X"
    return line


def norm_outs(cmd, outs):
    if cmd.strip().startswith("vm start"):                                       # 待っている間の行の数は速さで変わる
        return [l for l in outs if not l.startswith("起動中…")]
    return outs


def page_groups():
    groups = []
    for f in PAGES:
        s = f.read_text(encoding="utf-8")
        if not re.search(r'<body[^>]*data-ch="\d+"', s):
            continue
        for m in re.finditer(r"<pre\b([^>]*)><code>([\s\S]*?)</code></pre>", s):
            lines = html.unescape(re.sub(r"<[^>]+>", "", m.group(2))).split("\n")
            if not any(l.startswith("$ ") for l in lines):
                continue
            mw = re.search(r'data-where="([^"]*)"', m.group(1))
            if mw and "Ubuntu" in html.unescape(mw.group(1)):
                continue
            cur = None
            for raw in lines:
                l = dropnote(raw)
                if l.startswith("$ "):
                    cur = {"page": f.name, "cmd": l[2:], "outs": [], "elide": []}
                    groups.append(cur)
                elif cur is None or l.startswith("> "):
                    continue
                elif l.strip() in ("...", "…"):
                    cur["elide"].append(len(cur["outs"]))
                elif l.strip() and not skip(l.strip()):
                    cur["outs"].append(mask(cur["cmd"], l.strip()))
    for g in groups:
        g["outs"] = norm_outs(g["cmd"], g["outs"])
    return groups


def log_entries(path):
    entries, cont, banner = [], False, False
    for raw in path.read_text(encoding="utf-8").split("\n"):
        if HEAD.match(raw.strip()):
            entries.append(None)
            continue
        # 檻を起動したときの表示（「# --- …起動…」から「# --- ここまで ---」まで）は、どのコマンドの出力でもない
        if raw.startswith("# --- ") and "ここまで" not in raw:
            banner = True
            entries.append(None)
            continue
        if raw.startswith("# --- ここまで"):
            banner = False
            continue
        if banner or raw.startswith("# "):    # 記録の注釈
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
    es = [e for e in entries if e is not None]
    for e in es:
        e["outs"] = norm_outs(e["cmd"], e["outs"])
    return es


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
            continue
        bad += 1
        extra = [l for l in S if l not in P]
        print(f"✗ {g['page']}: $ {g['cmd']}")
        print("    通しの出力に、本文に無い行がある: " + " / ".join(extra[:8]) + (" …" if len(extra) > 8 else ""))
    print(f"組 {len(groups)} 個を突き合わせた。違い {bad} 件")
    total_bad += bad
sys.exit(1 if total_bad else 0)
