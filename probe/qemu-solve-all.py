#!/usr/bin/env python3
"""QEMU の記事: 全演習を、読者と同じ起動・同じ端末で解き、判定が両方向に働くことを記録する。

  python3 -I probe/qemu-solve-all.py [--out logs/qemu-solve-all.log]

目的は2つ（linuc-brief §1.4）。
  1) 解く前（と、よくある途中の誤り）で lab check が ✗ を出し、観測した事実を言うこと
  2) 模範解答どおりにやれば ✔ になること

起動と打ち方は probe/qemu-seq.py と同じ（docker run --rm -it --hostname host の端末を tmux で開き、
PS1 だけを "$ " にして、1つのシェルで打つ）。QEMU の画面に打つもの（ログイン・Ctrl-a c・モニタの命令）も
同じ仕組みで送る。判定（lab check）は読者と同じく外のシェルで打つ。
"""
import argparse, importlib.util, sys, time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("qemu_seq", REPO / "probe" / "qemu-seq.py")
seq = importlib.util.module_from_spec(spec)
spec.loader.exec_module(seq)
seq.NAME = "qemu-solve"
seq.SOCK = "qemu-solve"

BASE = "/var/lib/lab-vm/linuc-guest.qcow2"
QMP = lambda c: ("printf '%s\\n' '{\"execute\":\"qmp_capabilities\"}' '{\"execute\":\"" + c +
                 "\"}' | socat - UNIX-CONNECT:qmp.sock")
CHK = lambda n: f'lab check {n}; echo "exit=$?"'
WAIT_SSH = "until ssh -o ConnectTimeout=3 linuc true 2>/dev/null; do sleep 3; done"
WAIT_GONE = "while pgrep -x qemu-system-x86 > /dev/null; do sleep 1; done"
OVERLAY = f"qemu-img create -f qcow2 -b {BASE} -F qcow2 linuc.qcow2"
BOOT_FG = "qemu-system-x86_64 -m 1536 -smp 2 -drive file=linuc.qcow2,if=virtio -display none -serial mon:stdio"
NET = ("-netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=n0")
BG = "-display none -serial file:serial.log -qmp unix:qmp.sock,server=on,wait=off -daemonize"
OVMF = ("-drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd "
        "-drive if=pflash,format=raw,file=vars.fd")


def c(cmd, *events):
    return {"cmd": cmd, "events": list(events), "chap": "solve"}


LOGIN = [("type", "linuc login:", "student"), ("pw",)]

PLAN = [
  ("A. 何もしていない状態で lab check（全部 ✗ のはず）", [c(CHK(""))]),
  ("B. 演習01 — 画面の無い PC を後ろで動かし、QMP で尋ねられるようにする", [
    c("lab start 01"), c("cd ~/work/01"), c(CHK("01")),
    c("# よくある途中: -display none だけで後ろに回す（SeaBIOS はシリアルに書かない）"),
    c("qemu-system-x86_64 -display none -serial file:serial.log -qmp unix:qmp.sock,server=on,wait=off -daemonize"),
    c("sleep 3"), c(CHK("01")), c(QMP("quit")), c(WAIT_GONE),
    c("# よくある途中: -daemonize の代わりに & で後ろに回す（端末につながったまま）"),
    c("qemu-system-x86_64 -display none -machine graphics=off -serial file:serial.log -qmp unix:qmp.sock,server=on,wait=off &"),
    c("sleep 3"), c(CHK("01")), c(QMP("quit")), c(WAIT_GONE),
    c("qemu-system-x86_64 -display none -machine graphics=off -serial file:serial.log -qmp unix:qmp.sock,server=on,wait=off -daemonize"),
    c("sleep 3"), c(CHK("01")), c(QMP("quit")), c(WAIT_GONE), c(CHK("01")),
    c("# よくある途中: 前の serial.log が残ったまま、画面ありの QEMU のシリアルを別のファイルへ"),
    c("qemu-system-x86_64 -display none -serial file:other.log -qmp unix:qmp.sock,server=on,wait=off -daemonize"),
    c("sleep 3"), c(CHK("01")), c(QMP("quit")), c(WAIT_GONE),
  ]),
  ("C. 演習02 — 土台を汚さずに、自分の練習機のディスクを作って起動する", [
    c("lab start 02"), c("cd ~/work/02"), c(CHK("02")),
    c("# よくある途中: 土台を写す（cp）"),
    c(f"cp {BASE} linuc.qcow2"), c(CHK("02")), c("rm -f linuc.qcow2"),
    c(OVERLAY), c(CHK("02")),
    c("# よくある途中: quit（電源を抜く）で止める"),
    c(BOOT_FG, ("see", "linuc login:"), ("key", "Ctrl-a c"), ("type", "(qemu)", "quit")),
    c(CHK("02")),
    c(BOOT_FG, ("see", "linuc login:"), ("key", "Ctrl-a c"), ("type", "(qemu)", "system_powerdown")),
    c(CHK("02")),
  ]),
  ("D. 演習03 — ログインした直後の練習機を、メモリごと保存する", [
    c("lab start 03"), c("cd ~/work/03"), c(OVERLAY),
    c("# よくある途中: 外から qemu-img snapshot -c で取る（ディスクだけ）"),
    c("qemu-img snapshot -c loggedin linuc.qcow2"), c(CHK("03")), c("qemu-img snapshot -d loggedin linuc.qcow2"),
    c("# よくある途中: 練習機を動かしたまま判定する（後ろで動かし、QMP の human-monitor-command で savevm）"),
    c(f"qemu-system-x86_64 -m 1536 -smp 2 -drive file=linuc.qcow2,if=virtio {BG}"),
    c("until grep -q 'login:' serial.log; do sleep 3; done"),
    c("printf '%s\\n' '{\"execute\":\"qmp_capabilities\"}' '{\"execute\":\"human-monitor-command\",\"arguments\":{\"command-line\":\"savevm loggedin\"}}' | socat -t 20 - UNIX-CONNECT:qmp.sock"),
    c(CHK("03")), c(QMP("system_powerdown")), c(WAIT_GONE), c("qemu-img snapshot -d loggedin linuc.qcow2"),
    c(BOOT_FG, *LOGIN, ("key", "Ctrl-a c"), ("type", "(qemu)", "savevm loggedin"),
      ("type", "(qemu)", "info snapshots"), ("type", "(qemu)", "system_powerdown")),
    c(CHK("03")), c("qemu-img snapshot -l linuc.qcow2"),
  ]),
  ("E. 演習04 — TCG が最初に翻訳した命令を、記録に残す", [
    c("lab start 04"), c("cd ~/work/04"), c(CHK("04")),
    c("timeout 5 qemu-system-x86_64 -display none -d in_asm -D tcg.log"), c(CHK("04")),
  ]),
  ("F. 演習05 — 外から ssh で練習機に入れるようにする", [
    c("lab start 05"), c("cd ~/work/05"), c(CHK("05")),
    c("# よくある途中: 差分ではなく、土台を写したディスク（cp）で起動する"),
    c(f"cp {BASE} linuc.qcow2"), c("chmod u+w linuc.qcow2"),
    c(f"qemu-system-x86_64 -machine q35 -m 1536 -smp 2 -drive file=linuc.qcow2,if=virtio {NET},addr=0x10 {BG}"),
    c(WAIT_SSH), c(CHK("05")), c(QMP("system_powerdown")), c(WAIT_GONE), c("rm -f linuc.qcow2"),
    c(OVERLAY),
    c("# よくある途中: NIC の位置を指定しない（練習機の中で ens3 になり、アドレスが付かない）"),
    c(f"qemu-system-x86_64 -m 1536 -smp 2 -drive file=linuc.qcow2,if=virtio {NET} {BG}"),
    c("until grep -q 'login:' serial.log; do sleep 3; done"), c(CHK("05")),
    c(QMP("system_powerdown")), c(WAIT_GONE),
    c(f"qemu-system-x86_64 -machine q35 -m 1536 -smp 2 -drive file=linuc.qcow2,if=virtio {NET},addr=0x10 {BG}"),
    c(WAIT_SSH), c(CHK("05")), c(QMP("system_powerdown")), c(WAIT_GONE),
  ]),
  ("G. 演習06 — 練習機を UEFI で起動し、ブートの項目を NVRAM のファイルに残す", [
    c("lab start 06"), c("cd ~/work/06"), c(OVERLAY), c("cp /usr/share/OVMF/OVMF_VARS_4M.fd vars.fd"), c(CHK("06")),
    c("# よくある途中: SeaBIOS のまま起動する（vars.fd を渡していない）"),
    c(f"qemu-system-x86_64 -machine q35 -m 1536 -smp 2 -drive file=linuc.qcow2,if=virtio {NET},addr=0x10 {BG}"),
    c(WAIT_SSH), c(CHK("06")), c(QMP("system_powerdown")), c(WAIT_GONE),
    c(f"qemu-system-x86_64 -machine q35 -m 1536 -smp 2 {OVMF} -drive file=linuc.qcow2,if=virtio {NET},addr=0x10 {BG}"),
    c(WAIT_SSH), c(CHK("06")), c(QMP("system_powerdown")), c(WAIT_GONE),
  ]),
  ("H. 全部の後", [c("lab ls")]),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(REPO / "logs" / "qemu-solve-all.log"))
    a = ap.parse_args()
    out = Path(a.out)
    log = ["# 全演習を、読者と同じ起動（docker run --rm -it --hostname host、名前の無いボリューム2つ）の1つのシェルで解いた記録。",
           "# 解く前・よくある途中の誤り（✗）と、模範解答どおり（✔）の両方を打つ。作り方: python3 -I probe/qemu-solve-all.py"]
    t = seq.Term(80, 24)
    t0 = time.time()
    try:
        for title, steps in PLAN:
            log.append(f"\n\n########## {title} ##########")
            for st in steps:
                body = seq.run_step(t, st)
                log.append(f"\n$ {st['cmd']}")
                log.extend(body)
                out.write_text("\n".join(log) + "\n", encoding="utf-8")
                print(f"\r{title[:2]} {int(time.time() - t0)} 秒", end="", file=sys.stderr, flush=True)
    finally:
        out.write_text("\n".join(log) + "\n", encoding="utf-8")
        t.close()
    for w in seq.STUCK:
        print("\n止まった: " + w, file=sys.stderr)
    for w in seq.WARN:
        print("\n注意: " + w, file=sys.stderr)
    print(f"\n→ {out}（{int(time.time() - t0)} 秒）", file=sys.stderr)


if __name__ == "__main__":
    main()
