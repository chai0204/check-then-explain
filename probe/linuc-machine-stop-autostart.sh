#!/usr/bin/env bash
# 仮想マシン型の土台: docker stop で練習機が正常に止まるか、virsh autostart が docker start をまたいで効くか。
#   bash probe/linuc-machine-stop-autostart.sh > logs/linuc-machine-stop-autostart.log 2>&1
set -u
IMG=${1:-lab-linuc-machine:1.0.0}
ready() {  # $1 = コンテナ名。ssh を受け付けるまで待って秒数を出す
  local t0=$SECONDS
  for _ in $(seq 1 150); do
    docker exec "$1" vm status --short 2>/dev/null | grep -q 'running（エージェント 応答あり / ssh 待ち受け中）' && { echo "$((SECONDS - t0))"; return 0; }
    sleep 2
  done
  echo "timeout"; return 1
}

echo "== 1. docker stop（--stop-timeout 30）で練習機が正常に止まるか"
C=linuc-machine-stoptest
docker rm -fv $C >/dev/null 2>&1
docker run -d --name $C --hostname host --stop-timeout 30 -e LAB_VM_AUTOSTART=1 \
  -v /home/lab/vm -v /home/lab/.lab "$IMG" >/dev/null
echo "起動から ssh まで: $(ready $C) 秒"
docker exec $C ssh linuc 'sudo systemctl start cron; systemctl is-active cron' 2>&1
t=$SECONDS; docker stop $C >/dev/null; echo "docker stop: $((SECONDS - t)) 秒 / 終了コード $(docker inspect -f '{{.State.ExitCode}}' $C)"
docker start $C >/dev/null
echo "再開から ssh まで: $(ready $C) 秒"
echo "-- 前回の起動の最後（正常停止なら Power-Off まで記録がある）"
docker exec $C ssh linuc 'journalctl -b -1 --no-pager -n 4 -o short-monotonic | cut -c1-120' 2>&1
echo "-- 今回の起動で ext4 の回復が走ったか（何も出なければ走っていない）"
docker exec $C ssh linuc 'journalctl -k -b 0 --no-pager | grep -i -E "recovery|orphan" || echo "(回復なし)"' 2>&1
docker rm -fv $C >/dev/null

echo
echo "== 2. virsh autostart が docker stop / start をまたいで効くか（自動起動なしのコース）"
C=linuc-machine-autostart
docker rm -fv $C >/dev/null 2>&1
docker run -d --name $C --hostname host --stop-timeout 30 \
  -v /home/lab/vm -v /home/lab/.lab "$IMG" >/dev/null
sleep 5
docker exec $C bash -lc 'virsh list --all; virsh autostart linuc; virsh dominfo linuc | grep -i autostart' 2>&1
docker exec $C bash -lc 'virsh start linuc' 2>&1
echo "virsh start から ssh まで: $(ready $C) 秒"
t=$SECONDS; docker stop $C >/dev/null; echo "docker stop: $((SECONDS - t)) 秒 / 終了コード $(docker inspect -f '{{.State.ExitCode}}' $C)"
docker start $C >/dev/null
echo "docker start の後、何もしないで ssh まで: $(ready $C) 秒"
docker exec $C bash -lc 'virsh list --all' 2>&1
docker rm -fv $C >/dev/null
echo "== 終了"
