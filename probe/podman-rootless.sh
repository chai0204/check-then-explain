#!/bin/bash
# この記事の檻（lab-podman:1.0.0）と Docker の記事の檻（lab-docker:1.0.0）を、rootless の podman で、
# 読者と同じオプション（名前付きボリュームも同じ）で起動して確かめる。ホストで実行する。
#
#   bash probe/podman-rootless.sh       → logs/podman-rootless.log・logs/docker-rootless.log
#
# rootless の podman は、AI の検証環境の lab ユーザのもの（ssh lab。podman 5.8.6）を使う。
# イメージは docker save | ssh lab podman load で送り、終わったらコンテナ・ボリューム・イメージを消す。
# コンテナとボリュームの名前は <slug>-rootless…（読者の名前 lab-<slug> とぶつけない）。
set -u
cd /home/shun/learning-labs || exit 1

REMOTE=$(cat <<'EOS'
set -u
IMG=$1 NAME=$2 SLUG=$3
podman rm -f -v "$NAME" >/dev/null 2>&1; podman volume rm -f "$NAME-vm" "$NAME-state" >/dev/null 2>&1
echo "\$ podman version --format '{{.Client.Version}}'"
podman version --format '{{.Client.Version}}'
echo
echo "\$ podman run -d --name $NAME --hostname host --stop-timeout 30 -v $NAME-vm:/home/lab/vm -v $NAME-state:/home/lab/.lab $IMG"
t0=$(date +%s)
podman run -d --name "$NAME" --hostname host --stop-timeout 30 -v "$NAME-vm":/home/lab/vm -v "$NAME-state":/home/lab/.lab "$IMG" >/dev/null || exit 1
for _ in $(seq 1 300); do
  podman exec "$NAME" vm status --short 2>/dev/null | grep -q 'エージェント 応答あり / ssh 待ち受け中' && break
  sleep 1
done
echo "起動から ssh まで: $(( $(date +%s) - t0 )) 秒"
if [ "$SLUG" = podman ]; then
  for _ in $(seq 1 300); do podman exec "$NAME" test -f /home/lab/vm/.provisioned && break; sleep 1; done
fi
podman exec "$NAME" ssh linuc 'systemctl is-system-running --wait' >/dev/null 2>&1
for c in "lab env" "ls -ld /home/lab/vm /home/lab/.lab" "sh -c umask" "grep -E '^Cap(Eff|Bnd)' /proc/self/status"; do
  echo
  echo "\$ podman exec $NAME $c"
  podman exec "$NAME" bash -c "$c"
done
echo
echo "\$ podman volume inspect $NAME-vm --format '{{.Mountpoint}}'"
podman volume inspect "$NAME-vm" --format '{{.Mountpoint}}'
echo
if [ "$SLUG" = podman ]; then q='podman --version; podman images --format "{{.Repository}}:{{.Tag}}"'; else q='docker --version; docker images --format "{{.Repository}}:{{.Tag}}"'; fi
echo "\$ podman exec $NAME ssh linuc '$q'"
podman exec "$NAME" ssh linuc "$q"
echo
echo "\$ podman stop $NAME"
s=$(date +%s)
podman stop "$NAME" >/dev/null
echo "podman stop: $(( $(date +%s) - s )) 秒 / 終了コード $(podman inspect -f '{{.State.ExitCode}}' "$NAME")"
podman rm -v "$NAME" >/dev/null
podman volume rm "$NAME-vm" "$NAME-state" >/dev/null
podman rmi "$IMG" >/dev/null
echo "== 片付け済み（コンテナ・ボリューム・イメージ）"
EOS
)

for slug in podman docker; do
  img=lab-$slug:1.0.0
  log=logs/$slug-rootless.log
  {
    echo "# この檻（$img）を、rootless の podman（lab ユーザ）で、読者と同じオプション（名前付きボリューム）で起動した記録。$(date +%F)"
    echo "# 作り方: bash probe/podman-rootless.sh（イメージは docker save | ssh lab podman load で送った）"
    echo "# イメージ $img の ID: $(docker image inspect -f '{{.Id}}' "$img")"
    echo
    loaded=$(docker save "$img" | ssh lab 'podman load' 2>&1 | grep -o 'Loaded image: .*' | tail -1)
    echo "$loaded"
    echo
    ssh lab bash -s -- "${loaded#Loaded image: }" "$slug-rootless" "$slug" <<<"$REMOTE" 2>&1
  } > "$log"
  echo "→ $log"
done
