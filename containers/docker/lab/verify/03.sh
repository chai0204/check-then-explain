#!/usr/bin/env bash
# 演習 03 の判定。観測型（ex03:base が指す中身のダイジェストを見て、その中身を実際に起動する）。外（lab@host）で走り、練習機の中は lab-guest（qemu-guest-agent 経由・root）で見る。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値に引きずられないよう固定する
prereq() { echo "前提不足: 練習機が応答しません（起動の途中か、止まっている）。外で vm start を打ち、起動を待ってからもう一度"; exit 2; }
# 練習機に届くかを先に1回だけ確かめる。lab-guest は届かないとき 125 を返すが、podman や docker run も
# 自分の失敗に 125 を使うので、コマンドごとの 125 を「届かない」と読むと取り違える（実測: podman inspect の「無い」が 125）
lab-guest true >/dev/null 2>&1 || prereq

want=sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6
id=$(lab-guest "docker image inspect ex03:base --format '{{.Id}}'" 2>&1); rc=$?
echo "判定 : 観測型（ex03:base が指す中身のダイジェストを尋ね、その中身を起動した）"
if [ $rc -ne 0 ]; then
  echo "観測 : ex03:base という名前のイメージが無い"
  exit 1
fi
echo "観測 : ex03:base が指す中身 = $id"
rel=$(lab-guest 'docker run --rm ex03:base cat /etc/alpine-release' 2>&1 | tail -1)
echo "       docker run --rm ex03:base cat /etc/alpine-release → $rel"
if [ "$id" != "$want" ]; then
  echo "       Alpine 3.24.2 の中身（${want:0:19}…）ではない"
  exit 1
fi
echo "       → 名前が Alpine 3.24.2 の中身（ダイジェスト一致）を指している"
exit 0
