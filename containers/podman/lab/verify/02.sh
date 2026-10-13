#!/usr/bin/env bash
# 演習 02 の判定。観測型（同じ形のコンテナを実際に動かして書けるかを試し、~/ex02/data の持ち主の番号を見る）。外（lab@host）で走り、練習機の中は lab-guest（qemu-guest-agent 経由）で見る。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値に引きずられないよう固定する
prereq() { echo "前提不足: 練習機が応答しません（起動の途中か、止まっている）。外で vm start を打ち、起動を待ってからもう一度"; exit 2; }
# 練習機に届くかを先に1回だけ確かめる。lab-guest は届かないとき 125 を返すが、podman や docker run も
# 自分の失敗に 125 を使うので、コマンドごとの 125 を「届かない」と読むと取り違える（実測: podman inspect の「無い」が 125）
lab-guest true >/dev/null 2>&1 || prereq
# student の rootless の podman に尋ねる（student のログインのセッションの場所を、環境から引き継がずに決め打ちする）
P() { lab-guest -u student "export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; $1"; }

own=$(lab-guest 'stat -c "%u:%g %A" /home/student/ex02/data' 2>&1); rc=$?
echo "判定 : 観測型（--user 1000:1000 のコンテナを実際に動かして ~/ex02/data に書けるかを試し、持ち主の番号を見た）"
[ $rc -eq 0 ] || { echo "観測 : ~/ex02/data が無い"; exit 1; }
try=$(P 'podman run --rm --user 1000:1000 -v /home/student/ex02/data:/data alpine:3.24.2 sh -c "touch /data/.lab-check && rm /data/.lab-check && echo ok"' 2>&1 | tail -1)
echo "観測 : ~/ex02/data の持ち主と権限（練習機の上）: $own"
echo "       中の UID 1000 で書けるか: ${try}"
[ "$try" = ok ] || exit 1
case "$own" in
  100999:*) echo "       → 持ち主が中の UID 1000（外の 100999）になっていて、書けた" ;;
  *)        echo "       持ち主は中の UID 1000（外の 100999）ではない"; exit 1 ;;
esac
exit 0
