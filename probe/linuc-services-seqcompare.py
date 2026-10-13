#!/usr/bin/env python3
"""LinuC 主題1.09: 本文の端末ブロックを、通しの記録（probe/linuc-services-seq.py。端末つき）と本文の順に突き合わせる。

  python3 -I probe/linuc-services-seqcompare.py [通しの記録 ...]     （既定: logs/linuc-services-tty.log）

作りは probe/linuc-text-seqcompare.py（主題1.03）にならった。本文の「$ コマンド＋直後の出力」の組の k 番目と、
通しの記録の k 番目の項目を組にする（通しの記録は本文から機械的に作った入力で取ったので、順番がそのまま対応する）。

  1. 本文の出力行が、通しの出力の中に順番どおりにある（logcheck --strict と同じ考え方）
  2. 通しの出力に、本文に無い行が残っていないか。本文に省略の印（"..." / "…"）が無い組は、出力が
     行ごとに全部同じであること。印がある組は、印で区切った塊がそれぞれ通しの中でひと続きに現れること。
  3. 通しの記録で「プロンプトに戻らなかった」組（読者の端末では止まって見える。pager など）は、それだけで違いとする。

毎回変わる値は伏せて比べる（mask）: 日時・時刻・エポック秒・PID・postfix のキュー ID・Message-Id・配送の遅れ・
journal のカーソルと _PID などの項目・chrony の測った値（と fast / slow）・apt の転送の速さ・gzip したファイルの
大きさ・タイマーの残り時間。列の揃え（空白の数）は値の桁で変わるので、続く空白は1つにまとめて比べる。
並びや顔ぶれが毎回変わるもの（本文に注記してある）:
  apt-get update の Get: の行（番号と並びが回線で変わる）→ 番号を外して並べ替える
  journalctl --vacuum-* の3行（並びが変わる）→ 並べ替える
  journalctl -o verbose の _COMM・_CAP_EFFECTIVE・_SYSTEMD_* など（送り手のプロセスを読めたときだけ付く）→ 外す
"""
import html, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PAGES = sorted((REPO / "public" / "linuc-services" / "theory").glob("0[1-9]-*.html"))
seqs = [Path(a) for a in sys.argv[1:]] or [REPO / "logs" / "linuc-services-tty.log"]

q = lambda s: s.replace('"', "'")
dropnote = lambda l: re.sub(r"\s{2,}←.*$", "", l)
skip = lambda l: re.fullmatch(r"(\.\.\.|…|（[^）]*）)", l) is not None
HEAD = re.compile(r"^(=|#){10} .* (=|#){10}$")
MON = r"(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)"

MASKS = [
    (re.compile(r"\[s=[^\]]*\]"), "[CURSOR]"),                                  # journal -o verbose の見出し
    (re.compile(r"\b(_PID|_STREAM_ID|_SOURCE_REALTIME_TIMESTAMP)=\S+"), r"\1=X"),
    (re.compile(r"<\d{14}\.[0-9A-F]+@"), "<MSGID@"),                            # Message-Id
    (re.compile(r"\bdelay=[\d.]+, delays=[\d./]+"), "delay=X, delays=X"),
    (re.compile(r"\bx-pid=\"\d+\""), 'x-pid="X"'),
    (re.compile(r"\bpid \d+\b"), "pid X"),
    (re.compile(r"\[\d+\]"), "[PID]"),                                          # chronyd[461] など
    (re.compile(r"\b[0-9A-F]{10,12}\b"), "QID"),                                 # postfix のキュー ID
    (re.compile(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?([+-]\d\d:\d\d)?"), "ISOTIME"),
    (re.compile(r"\d{4}-\d\d-\d\d-\d+:\d+:\d+"), "STAMP"),                       # logrotate の status
    (re.compile(r"\b\d{1,2} " + MON + r" \d{4} \d\d:\d\d:\d\d"), "DATE"),       # メールの Date:
    (re.compile(MON + r" +\d+ +(\d\d:\d\d(:\d\d(\.\d+)?)?|\d{4})"), "DATE"),    # ls -l・date・journal
    (re.compile(r"\d{4}-\d\d-\d\d( \d\d:\d\d(:\d\d(\.\d+)?)?)?( \([+-]\d{4}\)| [+-]\d{4})?"), "DATETIME"),
    (re.compile(r"\b\d\d:\d\d:\d\d(\.\d+)?\b"), "TIME"),
    (re.compile(r"\b1[6-9]\d{8}\b"), "EPOCH"),
    (re.compile(r"[+-]?\d+\.\d{3,}"), "NUM"),                                   # chrony・ntpdate の測った値
    (re.compile(r"[+-]?\d+(ns|us|ms)\b"), "OFFSET"),
    (re.compile(r"\bin \d+s \(\d+ kB/s\)"), "in Ts (R kB/s)"),                   # apt の転送の速さ
    (re.compile(r"\b\d+h \d+min\b|\b\d+min \d+s\b|\b\d+h\b(?= )"), "LEFT"),       # タイマーの残り時間
]


OPTIONAL_FIELDS = re.compile(r"^_(COMM|EXE|CMDLINE|CAP_EFFECTIVE|SYSTEMD_[A-Z_]+|SELINUX_CONTEXT|AUDIT_[A-Z_]+)=")


def mask(cmd, line):
    line = re.sub(r"\[\s+", "[", line)                    # chronyc の [ +411ns] と [+1135ns]
    for pat, rep in MASKS:
        line = pat.sub(rep, line)
    if re.search(r"\b(seconds|ppm)\b", line):
        line = re.sub(r"\b(fast|slow)\b", "DIR", line)   # chronyc tracking の向き
    line = re.sub(r"\s{2,}", " ", line)
    if re.search(r"\bls -l\b", cmd) and line.endswith(".gz"):
        line = re.sub(r"^(\S+ +\d+ +\S+ +\S+ +)\d+", r"\1SIZE", line)       # gzip した大きさは中身の時刻で変わる
    if cmd.startswith("systemctl list-timers"):            # 幅で切られる NEXT の後ろ（JST / J… / …）は LEFT の桁で変わる
        line = re.sub(r"DATETIME (JST|J…|…)", "DATETIME TZ", line)
    if cmd.startswith("chronyc sources"):
        line = re.sub(r"^(\^\* localhost +\d+ +\d+ +\d+) +\d+ ", r"\1 LASTRX ", line)
    return line


def norm_outs(cmd, outs):
    c = cmd.strip()
    if c == "apt-get update":                              # Get: の番号と並びは回線で変わる
        gets = sorted(re.sub(r"^Get:\d+ ", "Get: ", l) for l in outs if l.startswith("Get:"))
        rest = [l for l in outs if not l.startswith("Get:")]
        return gets + rest
    if c.startswith("journalctl --vacuum-"):               # 3行の並びが変わる
        return sorted(outs)
    if re.search(r"\bjournalctl\b.*-o verbose", c):         # 送り手を読めたときだけ付く項目
        return [l for l in outs if not OPTIONAL_FIELDS.match(l)]
    return outs


def page_groups():
    groups = []
    for f in PAGES:
        s = f.read_text(encoding="utf-8")
        if not re.search(r'<body[^>]*data-ch="\d+"', s):
            continue
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
    for g in groups:
        if not g["elide"]:
            g["outs"] = norm_outs(g["cmd"], g["outs"])
    return groups


def log_entries(path):
    entries, cont = [], False
    for raw in path.read_text(encoding="utf-8").split("\n"):
        if raw.startswith("#") and not entries:
            continue
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
