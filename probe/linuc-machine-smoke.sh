#!/usr/bin/env bash
# 仮想マシン型の檻の土台（lab-linuc-machine:1.0.0）を、読者と同じ起動のしかたで通し試験する。
#   bash probe/linuc-machine-smoke.sh > logs/linuc-machine-smoke.log 2>&1
# ボリュームは匿名にして、最後に docker rm -fv で一緒に消す（名前付きは消すたびに確認が要るため）。
set -u
C=linuc-machine-smoke
IMG=${1:-lab-linuc-machine:1.0.0}
H() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
X() { docker exec "$C" bash -lc "$*" 2>&1; }

docker rm -fv "$C" >/dev/null 2>&1
echo "== 起動（読者と同じ: --hostname host、練習機の自動起動あり）"
t0=$SECONDS
docker run -d --name "$C" --hostname host -e LAB_VM_AUTOSTART=1 \
  -v /home/lab/vm -v /home/lab/.lab "$IMG" >/dev/null
for _ in $(seq 1 300); do
  X 'vm status --short' | grep -q 'running（エージェント 応答あり / ssh 待ち受け中）' && break
  sleep 2
done
echo "練習機が ssh を受け付けるまで: $((SECONDS - t0)) 秒（KVM なし）"

H "docker exec $C vm status"
H "docker exec $C virsh list --all"
H "docker exec $C ssh linuc 'hostname; whoami; uname -r; systemctl is-system-running; ip -br a show enp0s16; ip r'"
H "docker exec $C ssh linuc 'systemctl --failed --no-legend --plain | wc -l'"
H "docker exec $C lab-guest 'id; cat /etc/hostname'; echo rc=\$?"
H "docker exec $C lab-guest -u student 'id -un; pwd'; echo rc=\$?"
H "docker exec $C lab-guest 'exit 7'; echo rc=\$?"
H "docker exec $C ssh linuc 'lab env'"
H "docker exec $C ssh linuc 'systemd-detect-virt; grep -m1 \"model name\" /proc/cpuinfo; lscpu | grep -E \"^(Model name|Hypervisor|Virtualization)\"'"
H "docker exec $C bash -c 'systemd-detect-virt 2>/dev/null || echo \"(systemd-detect-virt 無し)\"; uname -r'"
H "docker exec $C ssh linuc 'echo 残るか > ~/persist.txt; sync'"

echo; echo "== 停止と再起動（練習機の状態がボリュームに残るか）"
t1=$SECONDS; docker stop "$C" >/dev/null; echo "docker stop: $((SECONDS - t1)) 秒"
docker start "$C" >/dev/null
t2=$SECONDS
for _ in $(seq 1 300); do
  X 'vm status --short' | grep -q 'running（エージェント 応答あり / ssh 待ち受け中）' && break
  sleep 2
done
echo "再開後、ssh を受け付けるまで: $((SECONDS - t2)) 秒"
H "docker exec $C ssh linuc 'cat ~/persist.txt'"

echo; echo "== 練習機を止めたときの判定（125 が返り、読者の失敗にしない）"
H "docker exec $C vm stop"
H "docker exec $C lab-guest true; echo rc=\$?"
H "docker exec $C vm status --short"

docker rm -fv "$C" >/dev/null 2>&1
echo; echo "== 終了"
