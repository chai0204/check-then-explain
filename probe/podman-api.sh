#!/bin/bash
# docker の CLI（29.1.3）を podman の docker 互換の受け口（podman.socket）につないだとき、CLI がどの版の番号で頼んでいるかを、
# 受け口の側の記録（student の podman.service の journal。1行に1つの要求）で確かめる。ホストで実行する。
#
#   bash probe/podman-api.sh            → logs/podman-api.log
set -u
cd /home/shun/learning-labs || exit 1
IMG=${IMG:-lab-podman:1.0.0}
C=podman-api
LOG=logs/podman-api.log
G() { printf '\n$ %s\n' "$1" >> "$LOG"; docker exec -u lab -w /home/lab "$C" ssh linuc "$1" >> "$LOG" 2>&1; }

docker rm -f -v "$C" >/dev/null 2>&1
docker run -d --name "$C" --hostname host --stop-timeout 30 -v /home/lab/vm -v /home/lab/.lab "$IMG" >/dev/null || exit 1
for _ in $(seq 1 200); do
  docker exec "$C" vm status --short 2>/dev/null | grep -q 'エージェント 応答あり / ssh 待ち受け中' \
    && docker exec "$C" test -f /home/lab/vm/.provisioned && break
  sleep 2
done
docker exec -u lab "$C" ssh linuc 'systemctl is-system-running --wait' >/dev/null 2>&1

: > "$LOG"
{
  echo "# docker の CLI が podman の受け口に頼むときの版の番号を、受け口の記録で確かめた記録。作り方: bash probe/podman-api.sh。$(date +%F)"
  echo "# 檻: $IMG（$(docker image inspect -f '{{.Id}}' "$IMG")）。練習機の中で student として打つ"
} >> "$LOG"

# 練習機の中に置く小さな道具: コマンドを打ち、その間に受け口（podman.service）に届いた要求の1行目を並べる
docker exec -i -u lab "$C" ssh linuc 'cat > /tmp/apireq.sh' <<'EOS'
export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
t=$(date +%s); sleep 1
bash -c "$1"; echo "終了コード $?"
sleep 2
echo "--- 受け口に届いた要求（podman.service の記録）"
journalctl --user -u podman.service --since "@$t" -o cat --no-pager | grep -oE '"(GET|POST|HEAD|DELETE) [^ ]+ HTTP/1.1" [0-9]+' | sed -E 's/[0-9a-f]{64}/<ID>/g'
EOS
A() { printf '\n$ DOCKER_HOST=unix:///run/user/1000/podman/podman.sock %s\n' "$1" >> "$LOG"; docker exec -u lab -w /home/lab "$C" ssh linuc "bash /tmp/apireq.sh $(printf %q "$1")" >> "$LOG" 2>&1; }

G 'systemctl --user start podman.socket'
A "docker version --format 'client {{.Client.APIVersion}} / server {{.Server.APIVersion}}'"
A 'docker ps --format "{{.Names}}"'
A 'docker run --rm alpine:3.24.2 true'
A 'docker images --format "{{.Repository}}:{{.Tag}}"'
A 'docker images'
A 'DOCKER_API_VERSION=1.41 docker images --format "{{.Repository}}:{{.Tag}}"'
A 'docker image inspect --platform linux/amd64 alpine:3.24.2 --format "{{.Id}}"'
G 'systemctl --user stop podman.socket podman.service'

docker rm -f -v "$C" >/dev/null
echo "→ $LOG"
