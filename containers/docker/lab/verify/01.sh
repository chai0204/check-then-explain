#!/usr/bin/env bash
# 演習 01 の判定。観測型（ex01 の状態と、ex01 の cgroup のかごの memory.max を練習機の上で読む）。外（lab@host）で走り、練習機の中は lab-guest（qemu-guest-agent 経由・root）で見る。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値に引きずられないよう固定する
prereq() { echo "前提不足: 練習機が応答しません（起動の途中か、止まっている）。外で vm start を打ち、起動を待ってからもう一度"; exit 2; }
# 練習機に届くかを先に1回だけ確かめる。lab-guest は届かないとき 125 を返すが、podman や docker run も
# 自分の失敗に 125 を使うので、コマンドごとの 125 を「届かない」と読むと取り違える（実測: podman inspect の「無い」が 125）
lab-guest true >/dev/null 2>&1 || prereq

st=$(lab-guest "docker inspect -f '{{.State.Running}} {{.Id}} {{.Config.Image}} {{.Image}} {{.Path}}' ex01" 2>&1); rc=$?
echo "判定 : 観測型（練習機の docker に ex01 の状態を尋ね、cgroup のファイルを読んだ）"
if [ $rc -ne 0 ]; then
  echo "観測 : ex01 という名前のコンテナが無い（docker inspect ex01: $(tail -1 <<<"$st")）"
  exit 1
fi
read -r running id image imgid path <<<"$st"
echo "観測 : ex01（イメージ $image・コマンド $path）が動いているか: $running"
[ "$running" = true ] || { echo "       動いていないので、かご（cgroup）が無い"; exit 1; }
[ "$imgid" = sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6 ] || { echo "       イメージが alpine:3.24.2 の中身（294b683cb724）ではない"; exit 1; }
[ "$path" = sleep ] || { echo "       動かしているコマンドが sleep ではない"; exit 1; }
max=$(lab-guest "cat /sys/fs/cgroup/system.slice/docker-$id.scope/memory.max" 2>&1)
echo "       /sys/fs/cgroup/system.slice/docker-${id:0:12}….scope/memory.max = $max"
if [ "$max" != 100663296 ]; then
  echo "       上限は 100663296（96 × 1024 × 1024）ではない"
  exit 1
fi
echo "       → ex01 のかごに 96MiB の上限が書かれている"
exit 0
