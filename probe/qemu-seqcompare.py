#!/usr/bin/env python3
"""QEMU の記事: 本文の端末ブロックを、通しの記録（probe/qemu-seq.py）と本文の順に突き合わせる。

  python3 -I probe/qemu-seqcompare.py [通しの記録 ...]                 （既定: logs/qemu-seq.log）
  python3 -I probe/qemu-seqcompare.py --refresh logs/qemu-seq.log      毎回変わる値だけを、記録の値に書き換える

本文の「$ コマンド＋直後の出力」の組の k 番目と、通しの記録の k 番目の項目を組にする
（通しの記録は本文から機械的に作った入力で取ったので、順番がそのまま対応する）。組ごとに見ること:

  1. コマンドが同じ
  2. 本文の出力行が、通しの出力の中に順番どおりにある
  3. 通しの出力に、本文に無い行が残っていない。本文に省略の印（"（略）" / "..." / "…"）が無い組は、出力が
     行ごとに全部同じであること。印がある組は、印で区切った塊がそれぞれ通しの中でひと続きに現れ、
     最初の塊は出力の先頭から、最後の塊は出力の末尾まで（印で始まる・終わる場合を除く）であること
  4. 通しの記録で「プロンプトに戻らなかった」「待ちきれなかった」組は、それだけで違いとする

QEMU の画面（練習機のシリアル・モニタ）の中で打つもの（<kbd>）は、画面に出た文字としてそのまま比べる。
「（打鍵: …）」はキーを押した印で、出力ではないので比べない。
毎回変わる値（時刻・PID・カーネルの時刻・QEMU が付ける通し番号・時間を測った値・翻訳の統計・
書き込みで増えるファイルの大きさ）だけを伏せて比べる。伏せる規則は MASKS にある。

もう1つ、練習機のシリアルの画面では、行の頭のプロンプト（linuc login: / Password: / student@linuc:~$）を比べない。
練習機の systemd-fsckd が、起動の 30 秒ほど後に退場するとき、コンソールのカーソルのある1行を空白で上書きする
（\r と空白 51 個と \r。時刻は systemd-fsckd の退場と一致した）。どの行に当たるかは PC の速さと打つ間合いで変わり、
当たった行のプロンプトだけが画面から消える。本文はこれを注で説明している（第3章）。

--refresh: 本文の行のうち、伏せた形が記録と同じで、文字だけが違うもの（＝毎回変わる値）を、記録の文字に書き換える。
最終イメージで記録を取り直したとき、本文の時刻や PID を、その記録のものにそろえるために使う（logcheck が
「本文の行が記録にそのままある」ことを見るため）。伏せない部分が違う行は書き換えず、違いとして報告する。
"""
import html, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PAGES = sorted((REPO / "public" / "qemu" / "theory").glob("[0-9][0-9]-*.html"))

q = lambda s: s.replace('"', "'")
dropnote = lambda l: re.sub(r"\s{2,}←.*$", "", l)
ELIDE_RE = re.compile(r"(\.\.\.|…|（略）)")
NOTE_RE = re.compile(r"（[^）]*）")
HEAD = re.compile(r"^(=|#){10} .* (=|#){10}$")
MON = "Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec"
DOW = "Mon|Tue|Wed|Thu|Fri|Sat|Sun"

MASKS = [
    (re.compile(r"^\[\s*\d+\.\d+\]"), "[T]"),                                     # カーネルの時刻
    (re.compile(rf"({DOW}) \d{{4}}-\d\d-\d\d \d\d:\d\d:\d\d( \w+)?"), "DATETIME"),  # Tue 2026-10-13 23:20:05 JST
    (re.compile(r"\d{4}[-/]\d\d[-/]\d\d \d\d:\d\d:\d\d(\.\d+)?"), "DATETIME"),
    (re.compile(rf"({MON}) +\d+ +(\d\d:\d\d|\d{{4}})"), "DATE"),                   # ls -l の日時
    (re.compile(r"^(real|user|sys)(\s+)\d+m\d+\.\d+s$"), r"\1\2NmN.Ns"),           # time の結果
    (re.compile(r'"seconds": \d+, "microseconds": \d+'), '"seconds": N, "microseconds": N'),
    (re.compile(r'"id": ?"libvirt-\d+"'), '"id":"libvirt-N"'),
    (re.compile(r"#(net|block)\d+"), r"#\1N"),                                     # QEMU が付ける通し番号
    (re.compile(r"\bpid[= ]\d+"), "pid N"),
    (re.compile(r"\bfd=\d+"), "fd=N"),
    (re.compile(r"socat\[\d+\]"), "socat[N]"),
    (re.compile(r"0x[0-9a-f]{8,}"), "0xADDR"),                                   # socat の誤りの番地など
    (re.compile(r"/var/tmp/vl\.\w+"), "/var/tmp/vl.X"),                           # -snapshot の一時ファイル
    (re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"), "UUID"),
    (re.compile(r"^\[(\d+)\]\s+\d+$"), r"[\1] N"),                                # ジョブの番号と PID
    (re.compile(r"10\.0\.2\.2:\d+"), "10.0.2.2:PORT"),                             # 練習機から見た接続元のポート
    (re.compile(r"\.{2,} ok$"), ".. ok"),                                         # iPXE の DHCP を待つ点の数
]


GUEST_HEAD = re.compile(r"^(student@linuc:~\$|linuc login:)( |$)")
DROP = {"", "Password:"}


def mask(cmd, line):
    # 練習機の systemd-fsckd は、起動の 30 秒ほど後に退場するとき、コンソールの1行を空白で上書きする
    # （\r と空白 51 個と \r）。当たった行のプロンプト（ログインの案内・Password:・student@linuc:~$）は
    # 画面から消え、どの行に当たるかは PC の速さと打つ速さで変わる。プロンプトの部分だけを比べない。
    line = GUEST_HEAD.sub("", line)
    for rx, rep in MASKS:
        line = rx.sub(rep, line)
    # コマンドごとに、毎回変わる数
    if re.search(r"\bpgrep -a\b", cmd):
        line = re.sub(r"^\d+ ", "N ", line)
    if re.search(r"\bps -o pid", cmd):
        line = re.sub(r"^\s*\d+\s+\d+\s", "  N  N ", line)
    if re.search(r"grep -c '\^IN:'", cmd):
        line = re.sub(r"^\d+$", "N", line)
    if re.search(r"\bls -l\b.*\.qcow2$", cmd) or re.search(r"qemu-img info", cmd):
        line = re.sub(r"(lab lab) +\d+", r"\1 SIZE", line)
        line = re.sub(r"(disk size: )[\d.]+ (KiB|MiB|GiB)", r"\1SIZE", line)
    # info jit の統計と、スナップショットの一覧（大きさ・日時・仮想マシンの時計）
    if re.match(r"\s*(gen code size|TB |cross page|direct jump|TLB )", line):
        line = re.sub(r"\d+(\.\d+)?", "N", line)
    if re.match(r"^(--|\d+)\s+\S+\s+[\d.]+ (KiB|MiB|GiB|B)\s", line):
        line = re.sub(r"[\d.]+ (KiB|MiB|GiB|B)\s+DATETIME\s+\S+", "SIZE DATETIME CLOCK", line)
    return line


def page_groups():
    """本文の組: {page, cmd, outs: [(マスク前, マスク後)], elide: [位置], raw_lines: [(行番号, 本文の行)]}"""
    groups = []
    for f in PAGES:
        src = f.read_text(encoding="utf-8")
        lines_src = src.split("\n")
        for m in re.finditer(r"<pre\b[^>]*><code>([\s\S]*?)</code></pre>", src):
            start_line = src[:m.start(1)].count("\n")
            raws = m.group(1).split("\n")
            texts = [html.unescape(re.sub(r"<[^>]+>", "", r)) for r in raws]
            if not any(t.startswith("$ ") for t in texts):
                continue
            for i, t in enumerate(texts):
                l = dropnote(t)
                if l.startswith("$ "):
                    groups.append({"page": f.name, "cmd": l[2:], "outs": [], "elide": [], "where": []})
                    continue
                if not groups or groups[-1]["page"] != f.name or l.startswith("> "):
                    continue
                s = l.strip()
                if not s:
                    continue
                if ELIDE_RE.fullmatch(s):
                    groups[-1]["elide"].append(len(groups[-1]["outs"]))
                    continue
                if NOTE_RE.fullmatch(s):
                    continue
                g = groups[-1]
                ms = mask(g["cmd"], s)
                if ms.strip() in DROP:
                    continue
                g["outs"].append((s, ms))
                g["where"].append((f, start_line + i))
    return groups


def log_entries(path):
    entries, cont = [], False
    for raw in path.read_text(encoding="utf-8").split("\n"):
        if HEAD.match(raw.strip()):
            entries.append(None)
            continue
        if raw.startswith("$ "):
            entries.append({"cmd": raw[2:], "outs": [], "stuck": False})
            cont = True
            continue
        if not entries or entries[-1] is None:
            continue
        if cont and raw.startswith("> "):
            continue
        cont = False
        l = raw.strip()
        if "プロンプトに戻らなかった" in l or "待ちきれなかった" in l:
            entries[-1]["stuck"] = True
        if l:
            entries[-1]["outs"].append(l)
    out = [e for e in entries if e is not None]
    # 先頭の「lab env」（檻に入った直後の記録。本文の章の外）は除く
    while out and out[0]["cmd"] == "lab env":
        out.pop(0)
    return out


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


def compare(groups, entries, label):
    bad = 0
    print(f"── {label}")
    if len(entries) != len(groups):
        print(f"✗ 組の数が違う: 本文 {len(groups)} / 通し {len(entries)}")
        bad += 1
    for k, (g, e) in enumerate(zip(groups, entries)):
        if q(g["cmd"].strip()) != q(e["cmd"].strip()):
            print(f"✗ {g['page']}: {k+1} 番目の組のコマンドが違う（本文 {g['cmd']!r} / 通し {e['cmd']!r}）。ここで打ち切る")
            return bad + 1
        if e["stuck"]:
            bad += 1
            print(f"✗ {g['page']}: $ {g['cmd'][:100]}")
            print("    記録に「プロンプトに戻らなかった／待ちきれなかった」がある")
            continue
        P = [m for _, m in g["outs"]]
        S = [x for x in (mask(e["cmd"], l) for l in e["outs"]) if x.strip() not in DROP]
        n = subseq(P, S)
        if n != len(P):
            bad += 1
            print(f"✗ {g['page']}: $ {g['cmd'][:100]}")
            print(f"    本文の {n+1} 行目が通しに無い（または順が違う）: 「{g['outs'][n][0]}」")
            near = [s for s in e["outs"] if s[:12] == g["outs"][n][0][:12]][:3]
            if near:
                print("    通しの似た行: " + " / ".join(near))
            continue
        if P == S:
            continue
        if g["elide"] and excerpt_ok(P, g["elide"], S):
            continue
        bad += 1
        extra = [l for l in S if l not in P]
        print(f"✗ {g['page']}: $ {g['cmd'][:100]}")
        print("    通しの出力に、本文に無い行がある（省略の印で区切った塊がつながらない）: " + " / ".join(extra[:6]) + (" …" if len(extra) > 6 else ""))
    print(f"組 {len(groups)} 個を突き合わせた。違い {bad} 件")
    return bad


def refresh(groups, entries):
    """伏せた形が同じで文字が違う本文の行を、記録の文字に書き換える"""
    edits = {}
    for g, e in zip(groups, entries):
        if q(g["cmd"].strip()) != q(e["cmd"].strip()):
            print(f"✗ コマンドが違うので、ここから先は書き換えない: {g['cmd'][:80]}")
            break
        S = [(l, mask(e["cmd"], l)) for l in e["outs"]]
        S = [x for x in S if x[1].strip() not in DROP]
        j = 0
        for (orig, m), (f, ln) in zip(g["outs"], g["where"]):
            while j < len(S) and S[j][1] != m:
                j += 1
            if j == len(S):
                break
            if S[j][0] != orig:
                edits.setdefault(f, []).append((ln, orig, S[j][0]))
            j += 1
    n = 0
    for f, lst in edits.items():
        lines = f.read_text(encoding="utf-8").split("\n")
        for ln, orig, new in lst:
            eo, en = html.escape(orig, quote=False), html.escape(new, quote=False)
            km = re.search(r"<kbd>[\s\S]*?</kbd>", lines[ln])
            if km:
                # 打つ行（<kbd>）: 違うのは行の頭（プロンプトが消えたかどうか）だけのはず。行の頭を記録に合わせる
                typed = html.unescape(re.sub(r"<[^>]+>", "", km.group(0)))
                if new.endswith(typed):
                    head = new[:len(new) - len(typed)]
                    tags = re.match(r"^((?:\s*<[^>]+>)*)", lines[ln][:km.start()]).group(1)
                    lines[ln] = tags + html.escape(head, quote=False) + lines[ln][km.start():]
                    print(f"  {f.name}:{ln+1}: {orig!r} → {new!r}")
                    n += 1
                    continue
                print(f"  書き換えられない（打つ行の中身が違う）: {f.name}:{ln+1}: {orig} / 記録 {new}")
            elif eo in lines[ln]:
                lines[ln] = lines[ln].replace(eo, en, 1)
                print(f"  {f.name}:{ln+1}: {orig!r} → {new!r}")
                n += 1
            else:
                print(f"  書き換えられない（行の形が違う）: {f.name}:{ln+1}: {orig}")
        f.write_text("\n".join(lines), encoding="utf-8")
    print(f"書き換えた行: {n}")


def main():
    args = sys.argv[1:]
    groups = page_groups()
    if args[:1] == ["--refresh"]:
        p = Path(args[1])
        refresh(groups, log_entries(p))
        return 0
    seqs = [Path(a) for a in args] or [REPO / "logs" / "qemu-seq.log"]
    total = 0
    for p in seqs:
        total += compare(groups, log_entries(p), str(p.relative_to(REPO)) if p.is_relative_to(REPO) else str(p))
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
