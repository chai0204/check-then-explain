#!/usr/bin/env python3
"""LinuC 主題1.05: 課題文のひな形（probe/linuc-disks-tpl/tasks/NN.md）の「いまの状態」の画面を、
演習の通しの記録（logs/linuc-disks-solve-all.log。probe/linuc-disks-solve-all.sh が取る）から埋めて、
containers/linuc-disks/lab/tasks/NN.md に書き出す。課題文の画面を手で写さないための道具。

  python3 -I probe/linuc-disks-taskfill.py            書き出す
  python3 -I probe/linuc-disks-taskfill.py --check    書き出さず、いまの課題文と違えば exit 1
                                                       （ls -l の日時と free の数は、課題文にも「人によって違う」と
                                                        書いてあるので、伏せて比べる。課題文はイメージに入るので、
                                                        記録を取り直すたびに書き直すと、記録したイメージと別物になる）

ひな形の "@@SCREEN NN-k@@" の行を、下の表の「記録の節 NN の、そのコマンドの出力」（最初に出たもの）で置き換える。
出力は4字下げる（課題文の中のコマンドの行と同じ深さ。「外で:」「中で:」を前に置いた演習10 は 11 字）。出力が無いコマンドは、行ごと消す。
"""
import re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TPL = REPO / "probe" / "linuc-disks-tpl" / "tasks"
OUT = REPO / "containers" / "linuc-disks" / "lab" / "tasks"
LOG = REPO / "logs" / "linuc-disks-solve-all.log"
SCREENS = {
    "01-1": ("1", "lsblk /dev/vde"),
    "02-1": ("2", "sudo fdisk -l /dev/vdd"),
    "02-2": ("2", "cat ~/vdd-before.txt"),
    "03-1": ("3", "sudo parted /dev/vdb print"),
    "04-1": ("4", "lsblk -o NAME,SIZE,FSTYPE,LABEL /dev/vdb"),
    "05-1": ("5", "ls -l ~/old-usb.img"),
    "06-1": ("6", "mount /media/cdrom"),
    "07-1": ("7", "free -h"),
    "08-1": ("8", "lsblk /dev/vdc /dev/sda"),
    "09-1": ("9", "lsblk -d -o NAME,TRAN,ROTA,SIZE,MODEL"),
    "10-1": ("10", "virsh attach-device linuc ~/vm/extra/usb-a.xml", 11),
    "10-2": ("10", "lsblk -d -o NAME,TRAN,SIZE,SERIAL", 11),
    "10-3": ("10", 'lsmod | grep -E "usb_storage|uas"', 11),
    "10-4": ("10", "virsh detach-device linuc ~/vm/extra/usb-a.xml", 11),
}


def sections():
    secs, cur, name, banner = {}, None, None, False
    for raw in LOG.read_text(encoding="utf-8").split("\n"):
        m = re.match(r"^========== (\d+)\. .* ==========$", raw)
        if m:
            name = m.group(1)
            secs.setdefault(name, [])
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
        if raw.startswith("# "):
            cur = None
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
    return secs


def masked(text):
    """課題文にも「人によって違う」と書いてある値を伏せる（--check のときだけ使う）。"""
    text = re.sub(r"\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) +\d+ +(\d\d:\d\d|\d{4})\b", "DATE", text)
    return re.sub(r"(?m)^(\s*(Mem|Swap):).*$", r"\1 N", text)


def main():
    check = "--check" in sys.argv
    secs = sections()
    bad = 0
    for f in sorted(TPL.glob("[0-9][0-9].md")):
        lines = []
        for raw in f.read_text(encoding="utf-8").split("\n"):
            m = re.fullmatch(r"@@SCREEN (\d\d-\d)@@", raw)
            if not m:
                lines.append(raw)
                continue
            sec, cmd, *ind = SCREENS[m.group(1)]
            pad = " " * (ind[0] if ind else 4)
            hit = next((e for e in secs.get(sec, []) if e["cmd"] == cmd), None)
            if hit is None and sec not in secs:      # 見出しが崩れた古い記録では、節をまたいで最初の1つを使う
                hit = next((e for es in secs.values() for e in es if e["cmd"] == cmd), None)
            if hit is None:
                raise SystemExit(f"{f.name}: 記録の節 {sec} に「$ {cmd}」が無い")
            lines.extend(pad + l if l else "" for l in hit["outs"])
        text = "\n".join(lines)
        dst = OUT / f.name
        if check:
            if not dst.exists() or masked(dst.read_text(encoding="utf-8")) != masked(text):
                print(f"✗ {dst.relative_to(REPO)} が記録から作ったものと違う")
                bad += 1
        else:
            dst.write_text(text, encoding="utf-8")
            print(f"  {dst.relative_to(REPO)}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
