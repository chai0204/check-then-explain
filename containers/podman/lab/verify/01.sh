#!/usr/bin/env bash
# 演習 01 の判定。観測型（ex01 の sleep の親のプロセスを練習機の上で調べ、~/ex01-conmon.txt の数字と比べる）。外（lab@host）で走り、練習機の中は lab-guest（qemu-guest-agent 経由）で見る。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値に引きずられないよう固定する
prereq() { echo "前提不足: 練習機が応答しません（起動の途中か、止まっている）。外で vm start を打ち、起動を待ってからもう一度"; exit 2; }
# 練習機に届くかを先に1回だけ確かめる。lab-guest は届かないとき 125 を返すが、podman や docker run も
# 自分の失敗に 125 を使うので、コマンドごとの 125 を「届かない」と読むと取り違える（実測: podman inspect の「無い」が 125）
lab-guest true >/dev/null 2>&1 || prereq
# student の rootless の podman に尋ねる（student のログインのセッションの場所を、環境から引き継がずに決め打ちする）
P() { lab-guest -u student "export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; $1"; }

st=$(P "podman inspect -f '{{.State.Running}} {{.State.Pid}}' ex01" 2>&1); rc=$?
echo "判定 : 観測型（ex01 のプロセスの親を練習機の上で調べ、~/ex01-conmon.txt と比べた）"
if [ $rc -ne 0 ]; then echo "観測 : student の podman に ex01 という名前のコンテナが無い"; exit 1; fi
read -r running pid <<<"$st"
[ "$running" = true ] || { echo "観測 : ex01 は動いていない"; exit 1; }
pp=$(lab-guest "ps -o ppid= -p $pid" 2>/dev/null | tr -d ' ')
comm=$(lab-guest "ps -o comm= -p $pp" 2>/dev/null)
gp=$(lab-guest "ps -o ppid= -p $pp" 2>/dev/null | tr -d ' ')
file=$(lab-guest 'cat /home/student/ex01-conmon.txt' 2>/dev/null | tr -d ' \n')
echo "観測 : ex01 の sleep（PID $pid）の親は PID $pp の $comm（その親は PID $gp）"
echo "       ~/ex01-conmon.txt の中身: ${file:-（無い）}"
[ "$comm" = conmon ] || exit 1
[ "$file" = "$pp" ] || { echo "       ファイルの数字が、親の PID と違う"; exit 1; }
echo "       → 親は conmon で、ファイルの数字と一致した（podman のプロセスは親ではない）"
exit 0
