#!/usr/bin/env bash
# 出来上がった練習機のディスクを一度だけ起動して、次の2つを行う（keyscan.sh から root で呼ばれる）。
#   1. ホスト鍵を known_hosts の形で取り出す（外側の lab が初回の確認なしで ssh linuc できるように）
#   2. 起動の健全性を記録する（cloud-init を止めた後でもネットワークが上がるか、失敗したユニットが無いか）
# 土台のディスクは書き換えない（使い捨ての差分の上で起動する）。
set -euo pipefail
B=/build
qemu-img create -q -f qcow2 -F qcow2 -b $B/linuc-guest.qcow2 /tmp/ks.qcow2
cp /usr/share/OVMF/OVMF_VARS_4M.fd /tmp/vars.fd
ACCEL=tcg; [ -w /dev/kvm ] && ACCEL=kvm
echo "== 起動（accel=$ACCEL）"
qemu-system-x86_64 -machine q35 -accel $ACCEL -cpu max -smp 2 -m 1536 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
  -drive if=pflash,format=raw,file=/tmp/vars.fd \
  -drive file=/tmp/ks.qcow2,if=virtio \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-net-pci,netdev=n0,mac=52:54:00:12:34:56,addr=0x10 \
  -device virtio-rng-pci \
  -display none -serial file:/tmp/ks-serial.log -daemonize -pidfile /tmp/ks.pid
t0=$SECONDS
for _ in $(seq 1 240); do
  timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/2222 && head -c4 <&3' 2>/dev/null | grep -q 'SSH-' && break
  sleep 1
done
echo "ssh の待ち受けまで $((SECONDS - t0)) 秒"
ssh-keyscan -p 2222 -t ed25519,ecdsa,rsa 127.0.0.1 2>/dev/null | sort > $B/known_hosts
echo "== known_hosts"; cut -c1-60 $B/known_hosts
SSH=(ssh -i $B/lab_ed25519 -o UserKnownHostsFile=$B/known_hosts -o StrictHostKeyChecking=yes -p 2222 student@127.0.0.1)
echo "== 健全性（鍵とホスト鍵の両方を厳密に照合して入る）"
"${SSH[@]}" 'hostname; grep PRETTY_NAME /etc/os-release; uname -r; systemctl is-system-running --wait; systemctl --failed --no-legend --plain; ip -br a; man -w ls grep mount fdisk 2>&1; command -v nmcli ifup ifconfig dig nmap gpg xinetd firewalld at anacron lvcreate mkfs.xfs mkfs.btrfs gdisk parted efibootmgr lsusb lspci tmux screen; systemctl is-enabled NetworkManager firewalld xinetd qemu-guest-agent 2>&1; df -h / | tail -1'
"${SSH[@]}" 'sudo systemctl poweroff' 2>/dev/null || true
pid=$(cat /tmp/ks.pid)
for _ in $(seq 1 60); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
chown 1000:1000 $B/known_hosts
echo "== 完了"
