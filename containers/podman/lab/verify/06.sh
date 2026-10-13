#!/usr/bin/env bash
# 演習 06 の判定。観測型（ex06.service の出どころと状態・linger を見て、練習機の上で実際に接続し、答えたコンテナを確かめる）。外（lab@host）で走り、練習機の中は lab-guest（qemu-guest-agent 経由）で見る。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値に引きずられないよう固定する
prereq() { echo "前提不足: 練習機が応答しません（起動の途中か、止まっている）。外で vm start を打ち、起動を待ってからもう一度"; exit 2; }
# 練習機に届くかを先に1回だけ確かめる。lab-guest は届かないとき 125 を返すが、podman や docker run も
# 自分の失敗に 125 を使うので、コマンドごとの 125 を「届かない」と読むと取り違える（実測: podman inspect の「無い」が 125）
lab-guest true >/dev/null 2>&1 || prereq
# student の rootless の podman に尋ねる（student のログインのセッションの場所を、環境から引き継がずに決め打ちする）
P() { lab-guest -u student "export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; $1"; }

lg=$(lab-guest 'loginctl show-user student -p Linger --value' 2>&1); rc=$?
echo "判定 : 観測型（student の systemd に ex06.service の状態と出どころを尋ね、linger を見て、http://127.0.0.1:8086/ に接続した）"
act=$(lab-guest 'systemctl --user -M student@ is-active ex06.service' 2>/dev/null)
src=$(lab-guest 'systemctl --user -M student@ show -p SourcePath --value ex06.service' 2>/dev/null)
body=$(lab-guest 'curl -s -m 8 http://127.0.0.1:8086/hostname' 2>/dev/null)
hn=$(P "podman inspect systemd-ex06 --format '{{.Config.Hostname}}'" 2>/dev/null)
echo "観測 : ex06.service の状態: ${act:-（無い）}"
echo "       ex06.service の出どころ: ${src:-（無い）}"
echo "       student の linger: ${lg:-（不明）}"
echo "       curl http://127.0.0.1:8086/hostname → ${body:-（応答なし）}（コンテナ systemd-ex06 のホスト名: ${hn:-（無い）}）"
[ "$src" = /home/student/.config/containers/systemd/ex06.container ] || exit 1
[ "$act" = active ] || exit 1
[ -n "$body" ] && [ "$body" = "$hn" ] || { echo "       8086 番の応答が、ex06.service のコンテナから来ていない"; exit 1; }
[ "$lg" = yes ] || { echo "       linger が入っていないので、ログアウトすると student の systemd ごと止まる"; exit 1; }
echo "       → quadlet のファイルから作られたサービスが動き、ログアウトしても止まらない"
exit 0
