#!/bin/bash
# QEMU の記事: 檻（lab-qemu:1.0.0）を podman（rootless）で起動しても、本文と演習が同じように動くかを確かめる。
#
# 走らせ方（入口ページの起動コマンドと同じ檻。名前とボリューム名だけ probe 用）:
#   docker save lab-qemu:1.0.0 | ssh lab podman load
#   podman run -d -t --name qemu-podman --hostname host \
#     -v qemu-podman-work:/home/lab/work -v qemu-podman-state:/home/lab/.lab \
#     docker.io/library/lab-qemu:1.0.0      # 公開名 ghcr.io/chai0204/lab:qemu-1.0.0。記録は push 前のローカルの同じイメージで取った
#   podman cp probe/qemu-podman.sh qemu-podman:/tmp/podman.sh
#   podman exec qemu-podman bash -l /tmp/podman.sh > logs/qemu-podman.log 2>&1
#   podman rm -f qemu-podman; podman volume rm qemu-podman-work qemu-podman-state; podman rmi docker.io/library/lab-qemu:1.0.0
#
# 見るところ: 特権なし（CapEff が 0）で TCG の練習機が起動し、hostfwd の入口を QEMU が待ち受け、
# ssh で入れて、演習 05 の lab check が通り、QMP で電源を切れること。
set -u
LAST=0
R() {
  local cmd="$1" first=1 line
  while IFS= read -r line; do
    if [ "$first" = 1 ]; then printf '\n$ %s\n' "$line"; first=0
    else printf '> %s\n' "$line"; fi
  done <<< "$cmd"
  (exit "$LAST"); eval "$cmd" 2>&1
  LAST=$?
}
S() { printf '\n\n========== %s ==========\n' "$*"; }

S "0. 環境"
R 'lab env'
R 'id'
R 'grep -E "^(CapEff|CapBnd)" /proc/self/status'
R 'ls -l /dev/kvm'

S "第5章・演習 05（q35 の 0x10 に NIC を差し、外の 127.0.0.1:2222 を練習機の 22 番へ）"
R 'lab start 05 > /dev/null; cd ~/work/05; pwd'
R 'qemu-img create -f qcow2 -b /var/lib/lab-vm/linuc-guest.qcow2 -F qcow2 linuc.qcow2'
R 'qemu-system-x86_64 -machine q35 -m 1536 -smp 2 -drive file=linuc.qcow2,if=virtio -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=n0,addr=0x10 -display none -serial file:serial.log -qmp unix:qmp.sock,server=on,wait=off -daemonize'
R 'ss -tlnp'
R 'SECONDS=0; until ssh -o ConnectTimeout=3 linuc true 2>/dev/null; do sleep 3; done; echo "ssh まで: $SECONDS 秒"'
R 'ssh linuc ip -br a'
R "ssh linuc 'echo \$SSH_CONNECTION'"
R 'lab check 05'
R "printf '%s\n' '{\"execute\":\"qmp_capabilities\"}' '{\"execute\":\"query-status\"}' | socat - UNIX-CONNECT:qmp.sock"
R "printf '%s\n' '{\"execute\":\"qmp_capabilities\"}' '{\"execute\":\"system_powerdown\"}' | socat - UNIX-CONNECT:qmp.sock"
R 'SECONDS=0; while pgrep -x qemu-system-x86 > /dev/null; do sleep 1; done; echo "止まるまで: $SECONDS 秒"'
R 'tail -1 serial.log'

S "後片付けの確認"
R 'pgrep -a qemu-system-x86; echo "pgrep の終了コード: $?"'
R 'lab ls'
