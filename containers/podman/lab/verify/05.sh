#!/usr/bin/env bash
# 演習 05 の判定。観測型（pod ex05 の infra のコンテナの網の名前空間に入り、http://127.0.0.1/ に接続する）。外（lab@host）で走り、練習機の中は lab-guest（qemu-guest-agent 経由）で見る。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値に引きずられないよう固定する
prereq() { echo "前提不足: 練習機が応答しません（起動の途中か、止まっている）。外で vm start を打ち、起動を待ってからもう一度"; exit 2; }
# 練習機に届くかを先に1回だけ確かめる。lab-guest は届かないとき 125 を返すが、podman や docker run も
# 自分の失敗に 125 を使うので、コマンドごとの 125 を「届かない」と読むと取り違える（実測: podman inspect の「無い」が 125）
lab-guest true >/dev/null 2>&1 || prereq
# student の rootless の podman に尋ねる（student のログインのセッションの場所を、環境から引き継がずに決め打ちする）
P() { lab-guest -u student "export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; $1"; }

infra=$(P "podman pod inspect ex05 --format '{{.InfraContainerID}}'" 2>&1); rc=$?
echo "判定 : 観測型（pod ex05 の網の名前空間の中から、実際に http://127.0.0.1/ に接続した）"
[ $rc -eq 0 ] || { echo "観測 : student の podman に ex05 という pod が無い"; exit 1; }
pid=$(P "podman inspect --format '{{.State.Pid}}' $infra" 2>/dev/null)
n=$(P "podman ps -a --filter pod=ex05 --format '{{.Names}}'" 2>/dev/null | wc -l)
body=$(lab-guest "nsenter -t $pid -n curl -s -m 8 http://127.0.0.1/" 2>&1)
echo "観測 : pod ex05 のコンテナ数（infra を含む）: $n"
echo "       pod の網の中から http://127.0.0.1/ → ${body:-（応答なし）}"
[ "$body" = "hello from ex05" ] || exit 1
echo "       → pod の網の中の 127.0.0.1 で、httpd に届いた"
exit 0
