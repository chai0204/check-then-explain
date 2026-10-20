#!/bin/bash
# linuc-network の練習機で、docker stop（--stop-timeout 30）にかかる秒数を測る（2回）。probe/linuc-machine-stop-autostart.sh の 1. を写した
#   bash probe/linuc-network-stop-time.sh > logs/linuc-network-stop-time.log 2>&1
set -u
IMG=${1:-lab-linuc-network:1.0.2}
ready() {
  local t0=$SECONDS
  for _ in $(seq 1 150); do
    docker exec "$1" vm status --short 2>/dev/null | grep -q 'running（エージェント 応答あり / ssh 待ち受け中）' && { echo "$((SECONDS - t0))"; return 0; }
    sleep 2
  done
  echo "timeout"; return 1
}
echo "image: $IMG  ($(docker image inspect "$IMG" --format '{{.Id}}' | cut -c1-19))"
echo "load: $(cut -d' ' -f1-3 /proc/loadavg)  running containers: $(docker ps -q | wc -l)"
C=me-stoptime-network
docker rm -fv $C >/dev/null 2>&1
docker run -d --name $C --hostname host --stop-timeout 30 -e LAB_VM_AUTOSTART=1 \
  -v /home/lab/vm -v /home/lab/.lab "$IMG" >/dev/null
for i in 1 2; do
  echo "[$i] 起動から ssh まで: $(ready $C) 秒"
  sleep 20   # 起動直後の後片づけが落ち着くのを待つ
  t=$SECONDS; docker stop $C >/dev/null; echo "[$i] docker stop: $((SECONDS - t)) 秒 / 終了コード $(docker inspect -f '{{.State.ExitCode}}' $C)"
  docker start $C >/dev/null
done
echo "[3] 再開から ssh まで: $(ready $C) 秒"
echo "-- 直前の起動の最後"
docker exec $C ssh linuc 'journalctl -b -1 --no-pager -n 3 -o short-monotonic | cut -c1-110' 2>&1
echo "-- 今回の起動で ext4 の回復が走ったか"
docker exec $C ssh linuc 'journalctl -k -b 0 --no-pager | grep -i -E "recovery|orphan" || echo "(回復なし)"' 2>&1
docker rm -fv $C >/dev/null
echo "== 終了"
