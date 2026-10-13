#!/bin/bash
# 檻（lab-docker:1.0.0・lab-podman:1.0.0）の docker stop に何秒かかるかを、練習機の中で何も動いていないときと、
# TERM を受け取らない PID 1 のコンテナ（演習の解答の形）を練習機の中に残したときで測る。ホストで実行する。
#
#   bash probe/docker-stop.sh            → logs/docker-stop.log・logs/podman-stop.log
#
# 読者と同じ起動オプション（--hostname host --stop-timeout 30。ボリュームは名前なし）で起動する。
# 檻の起動スクリプト（lab-vm-init）は TERM を受けると練習機を正常に止め、25 秒待っても止まらなければ電源を切る。
# 「止まるまでの秒数」と、起動し直した後の練習機の中のコンテナの状態（どう止められたか）を記録する。
set -u
cd /home/shun/learning-labs || exit 1

wait_ready() {  # $1 コンテナ名 $2 slug
  for _ in $(seq 1 200); do
    docker exec "$1" vm status --short 2>/dev/null | grep -q 'エージェント 応答あり / ssh 待ち受け中' \
      && { [ "$2" != podman ] || docker exec "$1" test -f /home/lab/vm/.provisioned; } && break
    sleep 2
  done
  docker exec -u lab "$1" ssh linuc 'systemctl is-system-running --wait' >/dev/null 2>&1
}
G() { printf '\n$ %s\n' "$2" >> "$LOG"; docker exec -u lab -w /home/lab "$1" ssh linuc "$2" >> "$LOG" 2>&1; }
stop_and_measure() {  # $1 コンテナ名
  printf '\n$ docker stop %s\n' "$1" >> "$LOG"
  local s e
  s=$(date +%s.%N)
  docker stop "$1" >> "$LOG" 2>&1
  e=$(date +%s.%N)
  echo "かかった時間: $(awk -v a="$s" -v b="$e" 'BEGIN { printf "%.1f", b - a }') 秒 / 檻の終了コード $(docker inspect -f '{{.State.ExitCode}}' "$1")" >> "$LOG"
}

for slug in docker podman; do
  C=$slug-stop
  IMG=lab-$slug:1.0.0
  LOG=logs/$slug-stop.log
  docker rm -f -v "$C" >/dev/null 2>&1
  : > "$LOG"
  {
    echo "# 檻 $IMG の docker stop にかかる時間（--stop-timeout 30）。作り方: bash probe/docker-stop.sh。$(date +%F)"
    echo "# イメージの ID: $(docker image inspect -f '{{.Id}}' "$IMG")"
  } >> "$LOG"
  docker run -d --name "$C" --hostname host --stop-timeout 30 -v /home/lab/vm -v /home/lab/.lab "$IMG" >/dev/null || exit 1
  wait_ready "$C" "$slug"

  printf '\n========== 1. 練習機の中で何も動いていないとき ==========\n' >> "$LOG"
  if [ "$slug" = docker ]; then G "$C" 'docker ps -a --format "{{.Names}}: {{.Status}}"'; else G "$C" 'podman ps -a --format "{{.Names}}: {{.Status}}"'; fi
  stop_and_measure "$C"

  docker start "$C" >/dev/null
  wait_ready "$C" "$slug"
  printf '\n========== 2. TERM を受け取らない PID 1 のコンテナを3つ残したとき（演習の解答の形） ==========\n' >> "$LOG"
  if [ "$slug" = docker ]; then
    G "$C" 'docker run -d --name ex01 --memory 96m alpine:3.24.2 sleep 3600'
    G "$C" 'docker run -d --name ex05 -p 10.0.2.15:8080:80 busybox:1.38.0 sh -c '"'"'mkdir -p /www && echo "hello from ex05" > /www/index.html && exec httpd -f -p 80 -h /www'"'"''
    G "$C" 'docker run -d --name ex07 --cap-add NET_ADMIN alpine:3.24.2 sleep 3600'
    G "$C" 'docker ps --format "{{.Names}}: {{.Status}}"'
  else
    G "$C" 'podman run -d --name ex01 alpine:3.24.2 sleep 3600'
    G "$C" 'podman run -d --name ex04 -p 127.0.0.1:8080:80 busybox:1.38.0 sh -c '"'"'mkdir -p /www && echo "hello from ex04" > /www/index.html && exec httpd -f -p 80 -h /www'"'"''
    G "$C" 'podman run -d --name ex07 alpine:3.24.2 sleep 3600'
    G "$C" 'podman ps --format "{{.Names}}: {{.Status}}"'
  fi
  stop_and_measure "$C"

  docker start "$C" >/dev/null
  wait_ready "$C" "$slug"
  printf '\n========== 3. 起動し直した後、練習機の中のコンテナはどう止められていたか ==========\n' >> "$LOG"
  if [ "$slug" = docker ]; then
    G "$C" 'docker ps -a --format "{{.Names}}: {{.Status}}"'
  else
    G "$C" 'podman ps -a --format "{{.Names}}: {{.Status}}"'
  fi
  G "$C" 'sudo journalctl -b -1 -n 4 --no-pager -o cat'
  docker rm -f -v "$C" >/dev/null
  echo "→ $LOG"
done
