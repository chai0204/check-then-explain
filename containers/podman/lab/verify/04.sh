#!/usr/bin/env bash
# 演習 04 の判定。観測型（練習機の上で実際に接続し、8080 番で待ち受けているプロセスを見る）。外（lab@host）で走り、練習機の中は lab-guest（qemu-guest-agent 経由）で見る。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値に引きずられないよう固定する
prereq() { echo "前提不足: 練習機が応答しません（起動の途中か、止まっている）。外で vm start を打ち、起動を待ってからもう一度"; exit 2; }
# 練習機に届くかを先に1回だけ確かめる。lab-guest は届かないとき 125 を返すが、podman や docker run も
# 自分の失敗に 125 を使うので、コマンドごとの 125 を「届かない」と読むと取り違える（実測: podman inspect の「無い」が 125）
lab-guest true >/dev/null 2>&1 || prereq
# student の rootless の podman に尋ねる（student のログインのセッションの場所を、環境から引き継がずに決め打ちする）
P() { lab-guest -u student "export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; $1"; }

body=$(lab-guest 'curl -s -m 8 http://127.0.0.1:8080/' 2>&1); rc=$?
echo "判定 : 観測型（練習機の上で curl http://127.0.0.1:8080/ を打ち、8080 番で待ち受けているプロセスを見た）"
lsn=$(lab-guest "ss -ltnpH 'sport = :8080'" 2>/dev/null | head -1)
who=$(grep -o '(("[^"]*"' <<<"$lsn" | head -1 | tr -d '(\"')
wpid=$(grep -o 'pid=[0-9]*' <<<"$lsn" | head -1 | cut -d= -f2)
wuser=$([ -n "$wpid" ] && lab-guest "ps -o user= -p $wpid" 2>/dev/null | tr -d ' ')
owner=$(P "podman ps --filter name=^ex04\$ --format '{{.Names}} {{.Ports}}'" 2>/dev/null)
echo "観測 : curl http://127.0.0.1:8080/ → ${body:-（応答なし）}"
echo "       8080 番で待ち受けているプロセス: ${who:-（無い）}（持ち主 ${wuser:-?}）"
echo "       student の podman の ex04: ${owner:-（無い）}"
[ "$body" = "hello from ex04" ] || exit 1
[ -n "$owner" ] || exit 1
case "$owner" in *"8080->80"*) ;; *) echo "       ex04 に、練習機の 8080 番からコンテナの 80 番への公開（-p）が無い"; exit 1 ;; esac
[ "$wuser" = student ] || { echo "       待ち受けているのが student のプロセスではない（rootless ではない）"; exit 1; }
case "$who" in rootlessport|pasta|pasta.*|slirp4netns) ;; *) echo "       待ち受けているのが公開の中継のプロセス（rootlessport・pasta）ではない"; exit 1 ;; esac
echo "       → rootless のまま、student の $who が 8080 番で受けてコンテナに届けた"
exit 0
