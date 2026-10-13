#!/usr/bin/env bash
# 演習 07 の判定。観測型（student の podman の ex07 の状態と、作ったときのコマンドの記録を見る）。外（lab@host）で走り、練習機の中は lab-guest（qemu-guest-agent 経由）で見る。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値に引きずられないよう固定する
prereq() { echo "前提不足: 練習機が応答しません（起動の途中か、止まっている）。外で vm start を打ち、起動を待ってからもう一度"; exit 2; }
# 練習機に届くかを先に1回だけ確かめる。lab-guest は届かないとき 125 を返すが、podman や docker run も
# 自分の失敗に 125 を使うので、コマンドごとの 125 を「届かない」と読むと取り違える（実測: podman inspect の「無い」が 125）
lab-guest true >/dev/null 2>&1 || prereq
# student の rootless の podman に尋ねる（student のログインのセッションの場所を、環境から引き継がずに決め打ちする）
P() { lab-guest -u student "export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; $1"; }

st=$(P "podman inspect ex07 --format '{{.State.Running}}|{{.Config.CreateCommand}}|{{.ImageName}}'" 2>&1); rc=$?
echo "判定 : 観測型（student の podman に ex07 の状態と、作ったときのコマンドの記録を尋ねた）"
[ $rc -eq 0 ] || { echo "観測 : student の podman に ex07 という名前のコンテナが無い"; exit 1; }
IFS='|' read -r running cmd image <<<"$st"
echo "観測 : ex07（イメージ $image）が動いているか: $running"
echo "       作ったときのコマンド: $cmd"
[ "$running" = true ] || exit 1
case "$cmd" in
  *"system service"*) echo "       → docker の API の受け口（podman system service）を通して作られた" ;;
  *) echo "       podman のコマンドで作られている（docker の API の受け口を通っていない）"; exit 1 ;;
esac
exit 0
