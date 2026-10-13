#!/bin/bash
# QEMU の記事: 第4章と用語辞書の「KVM を使うと何が変わるか」の文を確かめた記録。
# この記事の檻は /dev/kvm を渡さないので、この記録だけは、檻に --device /dev/kvm を足して取った（本文の出力は KVM なし）。
#
# 走らせ方:
#   docker run --rm -d -t --name qemu-kvmcheck --hostname host --device /dev/kvm -v /home/lab/work lab-qemu:1.0.0
#   docker cp probe/qemu-probe-kvm.sh qemu-kvmcheck:/tmp/kvm.sh
#   docker exec qemu-kvmcheck bash -l /tmp/kvm.sh > logs/qemu-probe-kvm.log 2>&1
#   docker stop -t 3 qemu-kvmcheck
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
mkdir -p ~/work/k && cd ~/work/k || exit 1

S "0. 環境"
R 'ls -l /dev/kvm; grep -m1 "model name" /proc/cpuinfo'
R 'qemu-img create -q -f qcow2 -b /var/lib/lab-vm/linuc-guest.qcow2 -F qcow2 d.qcow2'
R 'try() {
  qemu-system-x86_64 "$@" -machine q35 -m 1536 -smp 2 -drive file=d.qcow2,if=virtio -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=n0,addr=0x10 -display none -serial file:ser.log -monitor unix:m.sock,server=on,wait=off -daemonize 2>/dev/null
  until ssh -o ConnectTimeout=3 linuc true 2>/dev/null; do sleep 2; done
  ssh linuc "grep -m1 \"model name\" /proc/cpuinfo; grep -m1 vendor_id /proc/cpuinfo; echo \"flags の中の svm・vmx・hypervisor: \$(grep -m1 ^flags /proc/cpuinfo | grep -o -w -E \"svm|vmx|hypervisor\" | sort -u | tr \"\\n\" \" \")\""
  echo "info qtree の割り込み・タイマーの部品: $(echo "info qtree" | socat -t 3 - UNIX-CONNECT:m.sock 2>/dev/null | grep -o -E "dev: [a-z0-9-]*(i8259|ioapic|pit|kvmclock)[a-z0-9-]*" | sed "s/dev: //" | sort -u | tr "\n" " ")"
  ssh linuc "sudo poweroff" 2>/dev/null; while pgrep -x qemu-system-x86 > /dev/null; do sleep 0.5; done
}
echo "（try を定義した）"'

S "1. -accel tcg（-cpu なし。本文と同じ）"
R 'try -accel tcg'
S "2. -accel kvm（-cpu なし）"
R 'try -accel kvm'
S "3. -accel kvm -cpu host"
R 'try -accel kvm -cpu host'
S "4. -accel tcg -cpu max"
R 'try -accel tcg -cpu max'
R 'rm -f d.qcow2 ser.log m.sock; ls -A'
