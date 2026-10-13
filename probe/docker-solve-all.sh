#!/bin/bash
# Docker の記事の演習 01〜07 を、解く前（✗ になること）と模範解答の後（✔ になること）の両方で確かめる。ホストで実行する。
#
#   bash probe/docker-solve-all.sh            → logs/docker-solve-all.log
#
# 読者と同じ起動オプション（--hostname host --stop-timeout 30、ボリュームは名前なし）で檻を起動し、練習機の起動を待つ。
#   H … 外（lab@host）で打つもの（lab check NN）。docker exec -u lab で打つ
#   G … 練習機の中（student@linuc）で打つもの（模範解答の手順）。外から ssh linuc で流す（非対話のシェル）
# 記録の "$ " 行は、読者が打つ形にしてある。
set -u
cd /home/shun/learning-labs || exit 1
IMG=${IMG:-lab-docker:1.0.0}
C=docker-solve
LOG=logs/docker-solve-all.log

S() { printf '\n\n========== %s ==========\n' "$*" >> "$LOG"; }
H() { printf '\n$ %s\n' "$1" >> "$LOG"; docker exec -u lab -w /home/lab "$C" bash -c "$1" >> "$LOG" 2>&1; }
G() { printf '\n$ %s\n' "$1" >> "$LOG"; docker exec -u lab -w /home/lab "$C" ssh linuc "$1" >> "$LOG" 2>&1; }

docker rm -f -v "$C" >/dev/null 2>&1
docker run -d --name "$C" --hostname host --stop-timeout 30 -v /home/lab/vm -v /home/lab/.lab "$IMG" >/dev/null || exit 1
for _ in $(seq 1 150); do
  docker exec "$C" vm status --short 2>/dev/null | grep -q 'エージェント 応答あり / ssh 待ち受け中' && break
  sleep 2
done
docker exec "$C" ssh linuc 'systemctl is-system-running --wait' >/dev/null 2>&1

: > "$LOG"
{
  echo "# Docker の記事の演習 01〜07 を、解く前（✗）と模範解答の後（✔）で確かめた記録。作り方: bash probe/docker-solve-all.sh"
  echo "# 檻: $IMG（docker run -d --hostname host --stop-timeout 30。ボリュームは名前なし）"
} >> "$LOG"

S "環境"
H 'lab env'
H 'lab ls'

S "演習 01 メモリの上限を付けたコンテナを動かす"
H 'lab check 01'
G 'docker run -d --name ex01 --memory 64m alpine:3.24.2 sleep 3600'
H 'lab check 01'
G 'docker rm -f ex01'
G 'docker run -d --name ex01 --memory 96m busybox:1.38.0 sleep 3600'
H 'lab check 01'
G 'docker rm -f ex01'
G 'docker run -d --name ex01 --memory 96m alpine:3.24.2 sleep 3600'
G "cat /sys/fs/cgroup/system.slice/docker-\$(docker inspect -f '{{.Id}}' ex01).scope/memory.max"
H 'lab check 01'

S "演習 02 docker stop が TERM で終わるコンテナを動かす"
H 'lab check 02'
G 'docker run -d --name ex02 alpine:3.24.2 sleep 3600'
H 'lab check 02'
G 'docker rm -f ex02'
G 'docker run -d --name ex02 --init --stop-signal HUP alpine:3.24.2 sleep 3600'
H 'lab check 02'
G 'docker rm -f ex02'
G 'docker run -d --name ex02 --init alpine:3.24.2 sleep 3600'
G 'docker exec ex02 ps'
H 'lab check 02'
G "docker ps --format '{{.Names}}: {{.Status}}' --filter name=ex02"

S "演習 03 付け替えられた名前を、中身に戻す"
G 'docker tag busybox:1.38.0 ex03:base'
H 'lab check 03'
G 'docker tag 294b683cb724 ex03:base'
G "docker image inspect ex03:base --format '{{.Id}}'"
H 'lab check 03'

S "演習 04 コンテナを消しても残るデータを置く"
H 'lab check 04'
G 'docker run -d --name ex04-writer -v ex04-data:/data alpine:3.24.2 sh -c "echo \"keep me\" > /data/memo.txt; sleep 3600"'
H 'lab check 04'
G 'docker rm -f ex04-writer'
G 'sudo cat /var/lib/docker/volumes/ex04-data/_data/memo.txt'
H 'lab check 04'

S "演習 05 練習機の外から届くように、ポートを公開する"
H 'lab check 05'
G 'docker run -d --name ex05 -p 8080:80 busybox:1.38.0 sh -c '"'"'mkdir -p /www && echo "hello from ex05" > /www/index.html && exec httpd -f -p 80 -h /www'"'"''
H 'lab check 05'
G 'docker rm -f ex05'
G 'docker run -d --name ex05 -p 10.0.2.15:8080:80 busybox:1.38.0 sh -c '"'"'mkdir -p /www && echo "hello from ex05" > /www/index.html && exec httpd -f -p 80 -h /www'"'"''
G 'docker port ex05'
H 'curl -s http://127.0.0.1:8080/'
H 'lab check 05'

S "演習 06 キャッシュが効く順に Dockerfile を並べ替える"
H 'lab check 06'
G 'mkdir -p ~/ex06 && cd ~/ex06 && echo '"'"'echo "hello, $(cat /opt/ready.txt)"'"'"' > greet.sh && printf '"'"'%s\n'"'"' '"'"'FROM alpine:3.24.2'"'"' '"'"'COPY greet.sh /opt/greet.sh'"'"' '"'"'RUN sleep 8 && echo "ready" > /opt/ready.txt'"'"' '"'"'CMD ["sh", "/opt/greet.sh"]'"'"' > Dockerfile && docker build -q -t ex06:1 . && docker run --rm ex06:1'
H 'lab check 06'
G 'cd ~/ex06 && printf '"'"'%s\n'"'"' '"'"'FROM alpine:3.24.2'"'"' '"'"'RUN mkdir -p /opt'"'"' '"'"'COPY greet.sh /opt/greet.sh'"'"' '"'"'RUN sleep 8 && echo "ready" > /opt/ready.txt'"'"' '"'"'CMD ["sh", "/opt/greet.sh"]'"'"' > Dockerfile && docker build -q -t ex06:1 . && docker run --rm ex06:1'
H 'lab check 06'
G 'cd ~/ex06 && printf '"'"'%s\n'"'"' '"'"'FROM alpine:3.24.2'"'"' '"'"'RUN sleep 8 && echo "ready" > /opt/ready.txt'"'"' '"'"'COPY greet.sh /opt/greet.sh'"'"' '"'"'CMD ["sh", "/opt/greet.sh"]'"'"' > Dockerfile && cat Dockerfile && docker build -q -t ex06:1 . && docker run --rm ex06:1'
H 'lab check 06'

S "演習 07 必要な特権だけを渡して起動する"
H 'lab check 07'
G 'docker run -d --name ex07 --privileged alpine:3.24.2 sleep 3600'
H 'lab check 07'
G 'docker rm -f ex07'
G 'docker run -d --name ex07 --cap-add ALL alpine:3.24.2 sleep 3600'
H 'lab check 07'
G 'docker rm -f ex07'
G 'docker run -d --name ex07 --cap-add NET_ADMIN alpine:3.24.2 sleep 3600'
G 'docker exec ex07 grep CapEff /proc/self/status'
H 'lab check 07'

S "全問の後"
H 'lab ls'

docker rm -f -v "$C" >/dev/null
echo "→ $LOG"
