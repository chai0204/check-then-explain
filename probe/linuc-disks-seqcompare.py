#!/usr/bin/env python3
"""LinuC 主題1.05: 本文の端末ブロックを、通しの記録（probe/linuc-disks-seq.py）と本文の順に突き合わせる。

  python3 -I probe/linuc-disks-seqcompare.py [通しの記録 ...]     （既定: logs/linuc-disks-seq.log）

probe/linuc-files-seqcompare.py を写して作った（2026-10-20）。違いは、仮想マシンの練習機で毎回変わる値
（ファイルシステムや表の番号・起動からの秒数・待った秒数など）を伏せること。記録の章の見出しから打った章を読み取り、
その章の本文とだけ比べる。

本文の「$ コマンド＋直後の出力」の組の k 番目と、通しの記録の k 番目の項目を組にする
（通しの記録は本文から機械的に作った入力で取ったので、順番がそのまま対応する）。組ごとに見るもの:

  1. 本文の出力行が、通しの出力の中に順番どおりにある
  2. 通しの出力に、本文に無い行が残っていないか。本文に省略の印（"..."）が無い組は、出力が行ごとに全部同じであること。
     印がある組は、印で区切った塊がそれぞれ通しの中でひと続きに現れること（linuc-files-seqcompare と同じ）
  3. 通しの記録で「プロンプトに戻らなかった」組は、それだけで違いとする

毎回変わる値（本文にも「あなたの画面では違う」と書いてあるもの）は伏せて比べる:
  ls -l の日時・「Tue Oct 20 19:33:45 2026」の形の日時・YYYY-MM-DD HH:MM:SS・UUID（8-4-4-4-12）・FAT のボリューム ID・
  MBR の表の番号（0x…。fdisk の Disk identifier と sfdisk -d の label-id）・dmesg と udevadm monitor の秒数・dd のかかった秒数と速さ・vm start の秒数と「起動中…」の行・
  「初回の準備」の行・free と /proc/meminfo・/proc/interrupts の数・busctl の PID と接続の番号（:1.N）・Last login の行・
  mke2fs の進み（Discarding … done の空白）・df の tmpfs の行の数（/run の Used が人と時刻で変わる）・
  vgdisplay の VG UUID（LVM の番号は 6-4-4-4-4-4-6 の形で、上の UUID の形と違う）
"""
import html, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PAGES = sorted((REPO / "public" / "linuc-disks" / "theory").glob("[0-9][0-9]-*.html"))
seqs = [Path(a) for a in sys.argv[1:]] or [REPO / "logs" / "linuc-disks-seq.log"]

q = lambda s: s.replace('"', "'")
dropnote = lambda l: re.sub(r"\s{2,}←.*$", "", l)
skip = lambda l: re.fullmatch(r"(\.\.\.|…|（[^）]*）)", l) is not None
HEAD = re.compile(r"^(=|#){10} .* (=|#){10}$")
UUID = re.compile(r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b")


def mask(cmd, line):
    line = re.sub(r"(Mon|Tue|Wed|Thu|Fri|Sat|Sun) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) +\d+ \d\d:\d\d:\d\d \d{4}", "CTIME", line)
    line = re.sub(r"(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) +\d+ +(\d\d:\d\d|\d{4})", "DATE", line)
    line = re.sub(r"\d{4}-\d\d-\d\d \d\d:\d\d(:\d\d(\.\d+)?)?( [A-Z]{3,4}| [+-]\d{4})?", "DATETIME", line)
    line = UUID.sub("UUID", line)
    line = re.sub(r"\b[0-9A-F]{4}-[0-9A-F]{4}\b", "VOLID", line)               # FAT のボリューム ID
    line = re.sub(r"disk identifier 0x[0-9a-f]{8}", "disk identifier 0xID", line)
    line = re.sub(r"^Disk identifier: 0x[0-9a-f]{8}$", "Disk identifier: 0xID", line)
    line = re.sub(r"^label-id: 0x[0-9a-f]{8}$", "label-id: 0xID", line)          # sfdisk -d の表の番号
    line = re.sub(r"^\[ *\d+\.\d+\]", "[TS]", line)                              # dmesg
    line = re.sub(r"^(KERNEL|UDEV  )\[\d+\.\d+\]", r"\1[TS]", line)             # udevadm monitor
    line = re.sub(r"copied, [0-9.e+-]+ s, [0-9.]+ [kMGT]?B/s$", "copied, TIME", line)
    line = re.sub(r"^練習機が起動しました（\d+秒）$", "練習機が起動しました（N秒）", line)
    if re.match(r"(sudo )?free\b", cmd) or "meminfo" in cmd:
        line = re.sub(r"\d+(\.\d+)?([KMG]i)?(?=\s|$)", "N", line) if not line.lstrip().startswith("total") else line
    if "/proc/interrupts" in cmd:
        line = re.sub(r"^(\s*\d+:)\s+\d+\s+\d+", r"\1 N N", line)
    if cmd.startswith("busctl"):
        line = re.sub(r"^(\S+\s+)\d+(\s)", r"\1PID\2", line)
        line = re.sub(r"(?<=\s):1\.\d+(?=\s)", ":1.N", line)         # D-Bus が接続ごとに付ける番号
    line = re.sub(r"^Discarding device blocks: done\s*$", "Discarding device blocks: done", line)
    if cmd.startswith("df") and line.startswith("tmpfs "):
        line = re.sub(r"\d+(\.\d+)?[KMG]?%?(?=\s)", "N", line)
    line = re.sub(r"^VG UUID\s+\S+$", "VG UUID MASK", line)
    return line


def keep_line(cmd, l):
    """読者ごとに出たり出なかったりする行（本文にもそう書いてある）は、比べる前に落とす。"""
    if cmd.startswith("vm start") and (l.startswith("起動中…") or l.startswith("初回の準備")):
        return False
    if cmd == "ssh linuc" and l.startswith("Last login:"):
        return False
    return True


def page_groups(names=None):
    groups = []
    for f in PAGES:
        if names is not None and f.name not in names:
            continue
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
                elif l.strip() in ("...", "…", "（略）"):
                    groups[-1]["elide"].append(len(groups[-1]["outs"]))
                elif l.strip() and not skip(l.strip()) and keep_line(groups[-1]["cmd"], l.strip()):
                    groups[-1]["outs"].append(mask(groups[-1]["cmd"], l.strip()))
    return groups


def log_entries(path):
    entries, banner = [], False
    for raw in path.read_text(encoding="utf-8").split("\n"):
        if HEAD.match(raw.strip()):
            entries.append(None)
            continue
        if raw.startswith("# --- 端末"):
            banner = True
            continue
        if raw.startswith("# --- ここまで"):
            banner = False
            continue
        # 記録の注（"# --- …"）は飛ばす。それ以外の "# " で始まる行は出力（cat /etc/modules など）なので残す
        if banner or raw.startswith("# --- ") or (raw.startswith("# ") and (not entries or entries[-1] is None)):
            continue
        if raw.startswith("$ "):
            entries.append({"cmd": raw[2:], "outs": []})
            continue
        if not entries or entries[-1] is None:
            continue
        l = raw.strip()
        if "プロンプトに戻らなかった" in l:
            entries[-1]["stuck"] = True
        if l and not skip(l) and keep_line(entries[-1]["cmd"], l):
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


total_bad = 0
for seqp in seqs:
    names = set(re.findall(r"^========== \d+\. (\S+\.html) ==========$", seqp.read_text(encoding="utf-8"), re.M))
    groups = page_groups(names)
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
