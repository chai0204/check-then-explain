#!/usr/bin/env python3
"""docker / podman の記事: 本文の端末ブロックを、本文から機械的に作った入力で通しに打った記録と、本文の順に突き合わせる。

  python3 -I probe/docker-seqcompare.py --slug docker 記録 [記録 ...]
  （記録は probe/docker-seq.py --slug docker --src pages で取ったもの。本文の「$ コマンド」を本文の順に打ってある）

作りは probe/linuc-services-seqcompare.py（主題1.09）にならった。本文の「$ コマンド＋直後の出力」の組の k 番目と、
通しの記録の k 番目の項目を組にする。

  1. 本文の出力行が、通しの出力の中に順番どおりにある（logcheck --strict と同じ考え方）
  2. 通しの出力に、本文に無い行が残っていないか。本文に省略の印（"..."）が無い組は、出力が行ごとに全部同じであること。
     印がある組は、印で区切った塊がそれぞれ通しの中でひと続きに現れること。
  3. 通しの記録で「プロンプトに戻らなかった」組は、それだけで違いとする。

毎回変わる値だけを伏せて比べる（mask）: コンテナの ID（64桁・12桁）・ビルドで毎回変わるダイジェスト・PID・名前空間の番号・
経過時間（Up 3 seconds / 5 seconds ago）・time の秒数・ls の日時・パケットの数え・veth の名前・MAC アドレス・
podman の警告の時刻。列の揃え（空白の数）は値の桁で変わるので、続く空白は1つにまとめて比べる。
伏せないもの: イメージのダイジェスト（alpine と busybox は固定）・アドレス・ケーパビリティ・終了コード・umask など、本文の主張に使う値。
"""
import argparse, html, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
FIXED = {"294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6",
         "fd7dc98638c8e305f4dc34e979f1c0fdfdcaeb0fbf8fcff77ae834b6da3d7e6e",
         "320994c3b997e2ec6433f717f153e108023c5bec8fefa8d76b83451d16d05ea8",
         "d56c381f961d307a21b3ca004cf1e3910f106644aefb1f43e654c8a56c4fd395",
         "e2de96513ba9eb53b431787ec8a65cdde380ac4772a3e4c4b714dcfde2a102b5",
         "74d97c428c51a828f9051a7a40a53ff1fc99e54fc30323ce36760701b0b7f711",
         "aaef90e065235eb0b2d9938be85d1b81add2902cf89affe2cdfa19be33476ac0",
         "f97baa533a26513c453a362be331a43eb60214302f449c16571b23cea141dce4"}
FIXED12 = {h[:12] for h in FIXED}

q = lambda s: s.replace('"', "'")
dropnote = lambda l: re.sub(r"\s{2,}←.*$", "", l)
skip = lambda l: re.fullmatch(r"(\.\.\.|…|（[^）]*）)", l) is not None
HEAD = re.compile(r"^(=|#){10} .* (=|#){10}$")
MON = r"(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)"


def hexmask(m):
    h = m.group(0)
    if h in FIXED or h in FIXED12 or any(f.startswith(h) for f in FIXED):
        return h
    return "HEX" if len(h) < 40 else "HEX64"


MASKS = [
    (re.compile(r'time="[^"]+"'), 'time="T"'),                                     # podman の警告の時刻
    (re.compile(r"\bWARN\[\d+\]"), "WARN[N]"),                                     # podman の警告の経過秒
    (re.compile(r"\b(real|user|sys)\t\d+m[\d.]+s"), r"\1\tTIME"),                    # time の結果
    (re.compile(r"\b\d+\.\d+s\b"), "Ns"),                                           # BuildKit の 0.1s など
    (re.compile(r"(Up|Exited \(\d+\)) (Less than a second|About an? \w+|\d+ \w+)( ago)?"), r"\1 AGO"),
    (re.compile(r"\b(Less than a second|About an? \w+|\d+ (seconds?|minutes?|hours?)) ago\b"), "AGO"),
    (re.compile(r"\b\d+ (seconds?|minutes?)\b(?= ago| )"), "N UNIT"),
    (re.compile(MON + r" +\d+ +(\d\d:\d\d|\d{4})"), "DATE"),                        # ls -l の日時
    (re.compile(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?([+-]\d\d:\d\d|Z)?"), "ISOTIME"),
    (re.compile(r"\[4026\d{6}\]"), "[NS]"),                                         # 名前空間の番号
    (re.compile(r"\bveth[0-9a-f]{7}\b"), "vethX"),
    (re.compile(r"@if\d+"), "@ifN"),
    (re.compile(r"\b([0-9a-f]{2}:){5}[0-9a-f]{2}\b"), "MAC"),
    (re.compile(r"\bfe80::[0-9a-f:]+/64\b"), "fe80::X/64"),                          # MAC（起動ごとに乱数）から作る IPv6 のアドレス
    (re.compile(r"\b[0-9a-f]{64}\b"), None),                                         # コンテナの ID・ダイジェスト（固定のものは残す）
    (re.compile(r"\b[0-9a-f]{12}\b"), None),
    (re.compile(r"\bpid=\d+"), "pid=N"),
    (re.compile(r"\bfd=\d+"), "fd=N"),                                               # ss -p のソケットの番号（起動ごとに変わる）
    (re.compile(r"\(policy ACCEPT \d+ packets, \d+ bytes\)"), "(policy ACCEPT N packets, N bytes)"),
    (re.compile(r"/proc/\d+/"), "/proc/N/"),
    (re.compile(r"\b(Last login: ).*"), r"\1X"),
]


def mask(cmd, line):
    for pat, rep in MASKS:
        line = pat.sub(hexmask if rep is None else rep, line)
    # ps の PID・PPID の列（行頭の数字の並び）。名前は残す
    if re.search(r"\bps\b|\bpgrep\b|\bdocker exec \S+ ps\b|\bdocker top\b|\bpodman exec \S+ ps\b", cmd):
        line = re.sub(r"^\s*\d+(\s+\d+)?(?=\s)", "PID", line)
    if re.search(r"\becho \$pid\b|^\s*echo \$[ab]\b", cmd):
        line = re.sub(r"^\d+$", "PID", line)
    if "runc" in cmd and "state" in cmd:
        line = re.sub(r'"pid": \d+', '"pid": N', line)
    if "iptables" in cmd and "-v" in cmd:                       # パケットの数え（規則の行の先頭2列）
        line = re.sub(r"^\s*(\d+\s+)?\d+[KM]?\s+\d+[KM]?\s+(?=DROP|DNAT|ACCEPT|RETURN|MASQUERADE)", "N N ", line)
    if "conmon" in cmd and "args" in cmd:                       # conmon の引数に出るコンテナの ID は上で伏せてある
        pass
    line = re.sub(r"\s{2,}", " ", line).strip()
    return line


def page_groups(slug):
    groups = []
    for f in sorted((REPO / "public" / slug / "theory").glob("[0-9][0-9]-*.html")):
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
    ap.add_argument("--slug", required=True)
    ap.add_argument("logs", nargs="+")
    a = ap.parse_args()
    groups = page_groups(a.slug)
    total_bad = 0
    for p in a.logs:
        seqp = Path(p)
        entries = log_entries(seqp)
        print(f"── {seqp}")
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
                print(f"✗ {g['page']}: $ {g['cmd']}\n    プロンプトに戻らなかった（読者の端末では止まって見える）")
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


if __name__ == "__main__":
    main()
