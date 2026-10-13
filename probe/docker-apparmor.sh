#!/bin/bash
# AppArmor が有効な docker（この記事の練習機の Ubuntu の docker.io）で、--cap-add SYS_ADMIN だけでは
# /sys/fs/cgroup を書けるように付け直せないこと、そのため LinuC 1.09 の檻（--cap-add SYS_ADMIN だけを渡す）が
# 起動しないことを確かめる。ホストで実行する。1.09 の檻のイメージはホストの docker から練習機の docker へ送る。
#
#   bash probe/docker-apparmor.sh            → logs/docker-apparmor.log
set -u
cd /home/shun/learning-labs || exit 1
IMG=${IMG:-lab-docker:1.0.0}
CAGE109=ghcr.io/chai0204/lab-linuc-services:1.0.2
C=docker-apparmor
LOG=logs/docker-apparmor.log
G() { printf '\n$ %s\n' "$1" >> "$LOG"; docker exec -u lab -w /home/lab "$C" ssh linuc "$1" >> "$LOG" 2>&1; }

docker rm -f -v "$C" >/dev/null 2>&1
docker run -d --name "$C" --hostname host --stop-timeout 30 -v /home/lab/vm -v /home/lab/.lab "$IMG" >/dev/null || exit 1
for _ in $(seq 1 200); do
  docker exec "$C" vm status --short 2>/dev/null | grep -q 'エージェント 応答あり / ssh 待ち受け中' && break
  sleep 2
done
docker exec -u lab "$C" ssh linuc 'systemctl is-system-running --wait' >/dev/null 2>&1

: > "$LOG"
{
  echo "# AppArmor が有効な docker で、--cap-add SYS_ADMIN の効き方を確かめた記録。作り方: bash probe/docker-apparmor.sh。$(date +%F)"
  echo "# 檻: $IMG（$(docker image inspect -f '{{.Id}}' "$IMG")）。練習機の中の docker で確かめる"
} >> "$LOG"

printf '\n========== 1. SYS_ADMIN を足しても、docker-default が mount を断る ==========\n' >> "$LOG"
G 'docker info --format "{{.SecurityOptions}}"'
G 'docker run --rm --cap-add SYS_ADMIN alpine:3.24.2 sh -c '"'"'grep CapEff /proc/self/status; cat /proc/self/attr/current; mount -o remount,rw /sys/fs/cgroup 2>&1; grep " /sys/fs/cgroup " /proc/self/mounts'"'"''
G 'docker run --rm --cap-add SYS_ADMIN --security-opt apparmor=unconfined alpine:3.24.2 sh -c '"'"'cat /proc/self/attr/current; mount -o remount,rw /sys/fs/cgroup 2>&1 && echo remounted; grep " /sys/fs/cgroup " /proc/self/mounts'"'"''

printf '\n========== 2. LinuC 1.09 の檻を、その実践編の起動コマンドのまま起動する ==========\n' >> "$LOG"
printf '\n（ホストの docker から練習機の docker へ送る: docker save %s | ssh linuc docker load）\n' "$CAGE109" >> "$LOG"
docker save "$CAGE109" | docker exec -i -u lab "$C" ssh linuc 'docker load' >> "$LOG" 2>&1
G "docker run -d -t --name lab-linuc --hostname linuc --cap-add SYS_ADMIN -v lab-linuc-services-state:/root/.lab $CAGE109"
G 'sleep 20'
G 'docker ps -a --format "{{.Names}}: {{.Status}}"'
G 'docker logs lab-linuc 2>&1 | tail -8'
G "docker inspect -f '終了コード {{.State.ExitCode}} / AppArmor の規則 {{.AppArmorProfile}}' lab-linuc"
G 'docker rm -f lab-linuc; docker volume rm lab-linuc-services-state'

printf '\n========== 3. AppArmor の無い docker（著者の PC。NixOS の docker）では ==========\n' >> "$LOG"
for c in "docker info --format '{{.ServerVersion}} {{.SecurityOptions}}'" \
         "docker run --rm --cap-add SYS_ADMIN ubuntu:24.04 sh -c 'grep CapEff /proc/self/status; mount -o remount,rw /sys/fs/cgroup 2>&1 && echo remounted; grep \" /sys/fs/cgroup \" /proc/self/mounts'"; do
  printf '\n$ %s\n' "$c" >> "$LOG"
  bash -c "$c" >> "$LOG" 2>&1
done

docker rm -f -v "$C" >/dev/null
echo "→ $LOG"
