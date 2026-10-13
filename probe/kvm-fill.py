#!/usr/bin/env python3
"""KVM の記事: 章の型（probe/kvm-tpl/*.html）の端末ブロックを、記録（logs/kvm-*.log）からそのまま埋めて
public/kvm/theory/ に書き出す。本文の端末表示を手で写さないための道具（写し間違いをしない）。

  python3 -I probe/kvm-fill.py            # 全部の章を作り直す

型の中の印（<pre …><code> と </code></pre> の間に置く）:
  <!--log probe 1:3-5-->        logs/kvm-probe.log の第1節（「========== … ==========」の1つ目が 0 番。ここでは
                                「0. 入ったとき」が 0、「第1章」が 1 …）の、3〜5 番目の「$ コマンド」とその出力
  <!--log ubuntu 2:1-3-->       logs/kvm-ubuntu.log の節 2（0 が「Ubuntu 24.04 の PC」）
  後ろに付けられるもの（空白で区切る）:
    fold                        ▶ qemu-system-x86_64 の固定の部分（-bios から -pidfile までの6行）を「...」にする
    head=N                      出力を最初の N 行だけにして、後ろを「...」にする
    note="文字列::注釈"         出力のうち「文字列」を含む最初の行の後ろに「   ← 注釈」を足す（; で複数。
                                「^文字列」は行全体がその文字列と同じ行、「re:正規表現」は正規表現に合う行）
地の文や表に書く数も、記録から引く（記録を取り直しても、本文の数が古いまま残らないように）:
  <!--num probe 4:1 total-->     その項目の「QEMU を起動してから N 秒」の N（kstart はカーネルの最初の表示の秒）
  <!--num probe 4:2 times-->     ps の CPU の時間（etimes は経過時間）
  <!--num probe 4:3 sauser-->    systemd-analyze の userspace の秒（sakernel・satotal も）。後ろに数字で小数の桁
  <!--ratio A / B-->             2つの数の比（小数1桁）。A と B は「probe 4:3 sauser」の形
  <!--minus probe 4:5 total 3--> 数から 3 を引いたもの（小数1桁）
コマンドとコマンドの間には空行を1つ入れる（記録と同じ）。出力は HTML のために & < > だけを置き換える。
"""
import html, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TPL = REPO / "probe" / "kvm-tpl"
OUT = REPO / "public" / "kvm" / "theory"
LOGS = {"probe": REPO / "logs" / "kvm-probe.log", "ubuntu": REPO / "logs" / "kvm-ubuntu.log"}
HEAD = re.compile(r"^(={10}) (.+) (={10})$")


def sections(path):
    """記録を節に分け、節ごとに [{cmd, outs}] を返す。"""
    secs, cur, banner = [], None, False
    for raw in path.read_text(encoding="utf-8").split("\n"):
        if HEAD.match(raw):
            secs.append([])
            cur = None
            continue
        if not secs:
            continue
        # 檻を起動したときの表示（「# --- …起動…」から「# --- ここまで ---」まで）と注釈は、どの出力にも入れない
        if raw.startswith("# --- ") and "ここまで" not in raw:
            banner, cur = True, None
            continue
        if raw.startswith("# --- ここまで"):
            banner = False
            continue
        if banner or raw.startswith("# "):
            cur = None if raw.startswith("# ") else cur
            continue
        if raw.startswith("$ "):
            cur = {"cmd": raw[2:], "outs": []}
            secs[-1].append(cur)
        elif cur is not None:
            cur["outs"].append(raw)
    for s in secs:                            # 項目の後ろの空行を落とす
        for e in s:
            while e["outs"] and not e["outs"][-1].strip():
                e["outs"].pop()
    return secs


CACHE = {}


def entries(log, sec, a, b):
    if log not in CACHE:
        CACHE[log] = sections(LOGS[log])
    s = CACHE[log][sec]
    if not (1 <= a <= b <= len(s)):
        sys.exit(f"範囲の外: {log} {sec}:{a}-{b}（節 {sec} の項目は {len(s)} 個）")
    return s[a - 1:b]


def fold(outs):
    res, i = [], 0
    while i < len(outs):
        l = outs[i]
        res.append(l)
        if l.startswith("▶ qemu-system-x86_64 "):
            j = i + 1
            while j < len(outs) and outs[j].startswith("    -") and "-pidfile" not in outs[j]:
                j += 1
            if j < len(outs) and "-pidfile" in outs[j]:
                res.append("...")
                i = j + 1
                continue
        i += 1
    return res


def key_hit(key, line):
    if key.startswith("^"):
        return line.strip() == key[1:]
    if key.startswith("re:"):
        return re.search(key[3:], line) is not None
    return key in line


def secs(text):
    """「1.983s」「763ms」を秒の数にする。"""
    m = re.fullmatch(r"([\d.]+)(ms|s)", text)
    v = float(m.group(1))
    return v / 1000 if m.group(2) == "ms" else v


def field(log, sec, n, name):
    """記録の1項目から数を1つ取り出す（本文の地の文や表に書く数を、記録から引くため）。"""
    e = entries(log, sec, n, n)[0]
    text = "\n".join(e["outs"])
    if name in ("total", "kstart"):
        m = re.search(r"QEMU を起動してから ([\d.]+) 秒(?:。カーネルの最初の表示は ([\d.]+) 秒の時点)?", text)
        return float(m.group(1) if name == "total" else m.group(2))
    if name in ("etimes", "times"):
        m = re.search(r"^\s*\d+\s+(\d+)\s+(\d+)\s+qemu-system-x86$", text, re.M)
        return float(m.group(1) if name == "etimes" else m.group(2))
    if name in ("sakernel", "sauser", "satotal"):
        m = re.search(r"Startup finished in (\S+) \(kernel\) \+ (\S+) \(userspace\) = (\S+?)\.?$", text, re.M)
        return secs(m.group({"sakernel": 1, "sauser": 2, "satotal": 3}[name]))
    sys.exit(f"知らない数の名前: {name}")


def fmt(v, digits):
    return f"{v:.{digits}f}"


def ref(text):
    """「probe 4:3 sauser」を (記録, 節, 項目, 名前) にする"""
    log, pos, name = text.split()
    sec, n = pos.split(":")
    return log, int(sec), int(n), name


def number(spec):
    """<!--num probe 4:1 total-->・<!--num probe 4:3 sauser 3-->（小数の桁）・
    <!--ratio probe 4:3 sauser / probe 4:7 sauser-->・<!--minus probe 4:5 total 3-->（引いて小数1桁）"""
    kind, rest = spec.split(None, 1)
    if kind == "num":
        t = rest.split()
        log, sec, n, name = ref(" ".join(t[:3]))
        v = field(log, sec, n, name)
        if len(t) > 3:
            d = int(t[3])
        else:
            d = 0 if name in ("etimes", "times") else (3 if name.startswith("sa") else 1)
        return fmt(v, d)
    if kind == "ratio":
        a, b = [x.strip() for x in rest.split("/")]
        return fmt(field(*ref(a)) / field(*ref(b)), 1)
    if kind == "minus":
        t = rest.split()
        return fmt(field(*ref(" ".join(t[:3]))) - float(t[3]), 1)
    sys.exit(f"知らない印: {spec}")


def render(spec):
    m = re.fullmatch(r"\s*(\w+)\s+(\d+):(\d+)(?:-(\d+))?(.*)", spec)
    if not m:
        sys.exit(f"印が読めない: {spec}")
    log, sec, a, b, opts = m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4) or m.group(3)), m.group(5)
    head = re.search(r"\bhead=(\d+)", opts)
    notes = []
    mn = re.search(r'note="([^"]*)"', opts)
    if mn:
        for pair in mn.group(1).split(";"):
            k, _, v = pair.partition("::")
            notes.append([k, v, False])
    parts = []
    for e in entries(log, sec, a, b):
        outs = list(e["outs"])
        if "fold" in opts.split():
            outs = fold(outs)
        if head and len(outs) > int(head.group(1)):
            outs = outs[:int(head.group(1))] + ["..."]
        lines = ["$ " + e["cmd"]]
        for l in outs:
            for n in notes:
                if not n[2] and key_hit(n[0], l):
                    l = l + "   ← " + n[1]
                    n[2] = True
                    break
            lines.append(l)
        parts.append("\n".join(lines))
    for n in notes:
        if not n[2]:
            sys.exit(f"注釈の行が見つからない: {spec} / {n[0]}")
    text = "\n\n".join(parts)
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for t in sorted(TPL.glob("*.html")):
        s = t.read_text(encoding="utf-8")
        s = re.sub(r"<!--log ([^>]*?)-->", lambda m: render(m.group(1)), s)
        s = re.sub(r"<!--((?:num|ratio|minus) [^>]*?)-->", lambda m: number(m.group(1)), s)
        (OUT / t.name).write_text(s, encoding="utf-8")
        print(f"→ public/kvm/theory/{t.name}")


if __name__ == "__main__":
    main()
