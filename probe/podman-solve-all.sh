#!/bin/bash
# Podman の記事の演習 01〜07 を、解く前（✗ になること）と模範解答の後（✔ になること）の両方で確かめる。ホストで実行する。
#
#   bash probe/podman-solve-all.sh            → logs/podman-solve-all.log
#
# 読者と同じ起動オプション（--hostname host --stop-timeout 30、ボリュームは名前なし）で檻を起動し、練習機の起動と初回の準備を待つ。
#   H … 外（lab@host）で打つもの（lab check NN）。docker exec -u lab で打つ
#   G … 練習機の中（student@linuc）で打つもの（模範解答の手順）。外から ssh linuc で流す（非対話のシェル）
# 記録の "$ " 行は、読者が打つ形にしてある。
set -u
cd /home/shun/learning-labs || exit 1
IMG=${IMG:-lab-podman:1.0.0}
C=podman-solve
LOG=logs/podman-solve-all.log

S() { printf '\n\n========== %s ==========\n' "$*" >> "$LOG"; }
H() { printf '\n$ %s\n' "$1" >> "$LOG"; docker exec -u lab -w /home/lab "$C" bash -c "$1" >> "$LOG" 2>&1; }
G() { printf '\n$ %s\n' "$1" >> "$LOG"; docker exec -u lab -w /home/lab "$C" ssh linuc "$1" >> "$LOG" 2>&1; }

docker rm -f -v "$C" >/dev/null 2>&1
docker run -d --name "$C" --hostname host --stop-timeout 30 -v /home/lab/vm -v /home/lab/.lab "$IMG" >/dev/null || exit 1
for _ in $(seq 1 150); do
  docker exec "$C" vm status --short 2>/dev/null | grep -q 'エージェント 応答あり / ssh 待ち受け中' \
    && docker exec "$C" test -f /home/lab/vm/.provisioned && break
  sleep 2
done
docker exec "$C" ssh linuc 'systemctl is-system-running --wait' >/dev/null 2>&1

: > "$LOG"
{
  echo "# Podman の記事の演習 01〜07 を、解く前（✗）と模範解答の後（✔）で確かめた記録。作り方: bash probe/podman-solve-all.sh"
  echo "# 檻: $IMG（docker run -d --hostname host --stop-timeout 30。ボリュームは名前なし）"
} >> "$LOG"

S "環境"
H 'lab env'
H 'lab ls'

S "演習 01 コンテナの親の conmon を突き止める"
H 'lab check 01'
G 'podman run -d --name ex01 alpine:3.24.2 sleep 3600'
G 'echo 1 > ~/ex01-conmon.txt'
H 'lab check 01'
G "ps -o ppid= -p \$(podman inspect -f '{{.State.Pid}}' ex01) | tr -d ' ' > ~/ex01-conmon.txt"
G 'ps -o pid,ppid,comm -p $(cat ~/ex01-conmon.txt)'
H 'lab check 01'

S "演習 02 中の UID 1000 が書けるディレクトリを用意する"
H 'lab check 02'
G 'mkdir -p ~/ex02/data && chmod 777 ~/ex02/data'
H 'lab check 02'
G 'rm -r ~/ex02'
G 'mkdir -p ~/ex02/data && podman unshare chown 1000:1000 ~/ex02/data && ls -lnd ~/ex02/data'
G 'podman run --rm --user 1000:1000 -v "$HOME/ex02/data":/data alpine:3.24.2 touch /data/ok && ls -ln ~/ex02/data'
H 'lab check 02'

S "演習 03 student のイメージを root の置き場所へ運ぶ"
H 'lab check 03'
G 'podman save busybox:1.38.0 | sudo podman load'
G 'sudo podman images --digests busybox'
H 'lab check 03'

S "演習 04 rootless のまま、8080 番で公開する"
H 'lab check 04'
G 'podman run -d --name ex04 -p 127.0.0.1:80:80 busybox:1.38.0 sh -c '"'"'mkdir -p /www && echo "hello from ex04" > /www/index.html && exec httpd -f -p 80 -h /www'"'"''
G 'podman rm ex04'
G 'podman run -d --name ex04 --network host busybox:1.38.0 sh -c '"'"'mkdir -p /www && echo "hello from ex04" > /www/index.html && exec httpd -f -p 127.0.0.1:8080 -h /www'"'"''
H 'lab check 04'
G 'podman rm -f -t 0 ex04'
G 'podman run -d --name ex04 -p 127.0.0.1:8080:80 busybox:1.38.0 sh -c '"'"'mkdir -p /www && echo "hello from ex04" > /www/index.html && exec httpd -f -p 80 -h /www'"'"''
G 'curl -s http://127.0.0.1:8080/'
H 'lab check 04'
G 'podman rm -f -t 0 ex04'
G 'podman run -d --name ex04 --network pasta -p 127.0.0.1:8080:80 busybox:1.38.0 sh -c '"'"'mkdir -p /www && echo "hello from ex04" > /www/index.html && exec httpd -f -p 80 -h /www'"'"''
H 'lab check 04'

S "演習 05 pod の中で、127.0.0.1 で届くようにする"
H 'lab check 05'
G 'podman pod create --name ex05'
H 'lab check 05'
G 'podman run -d --pod ex05 --name ex05-web busybox:1.38.0 sh -c '"'"'mkdir -p /www && echo "hello from ex05" > /www/index.html && exec httpd -f -p 80 -h /www'"'"''
G 'podman run --rm --pod ex05 alpine:3.24.2 wget -qO- http://127.0.0.1/'
H 'lab check 05'

S "演習 06 quadlet で、ログアウトしても動き続けるサービスにする"
H 'lab check 06'
G "mkdir -p ~/.config/containers/systemd && printf '%s\\n' '[Container]' 'Image=docker.io/library/busybox:1.38.0' 'Exec=httpd -f -h /etc' 'PublishPort=127.0.0.1:8086:80' '[Service]' 'Restart=always' '[Install]' 'WantedBy=default.target' > ~/.config/containers/systemd/ex06.container"
G 'cat ~/.config/containers/systemd/ex06.container'
G 'systemctl --user daemon-reload && systemctl --user start ex06.service && curl -s http://127.0.0.1:8086/hostname'
H 'lab check 06'
G 'loginctl enable-linger && loginctl show-user student -p Linger'
H 'lab check 06'

S "演習 07 docker の CLI で、podman のコンテナを動かす"
H 'lab check 07'
G 'podman run -d --name ex07 alpine:3.24.2 sleep 3600'
H 'lab check 07'
G 'podman rm -f -t 0 ex07'
G 'systemctl --user start podman.socket && DOCKER_HOST=unix:///run/user/1000/podman/podman.sock docker run -d --name ex07 alpine:3.24.2 sleep 3600'
G "podman inspect ex07 --format '{{.Config.CreateCommand}}'"
H 'lab check 07'

S "全問の後"
H 'lab ls'

docker rm -f -v "$C" >/dev/null
echo "→ $LOG"
