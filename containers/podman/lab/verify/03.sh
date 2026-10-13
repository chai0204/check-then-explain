#!/usr/bin/env bash
# 演習 03 の判定。観測型（root の置き場所の busybox:1.38.0 の ID を見て、root の podman で起動する）。外（lab@host）で走り、練習機の中は lab-guest（qemu-guest-agent 経由）で見る。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値に引きずられないよう固定する
prereq() { echo "前提不足: 練習機が応答しません（起動の途中か、止まっている）。外で vm start を打ち、起動を待ってからもう一度"; exit 2; }
# 練習機に届くかを先に1回だけ確かめる。lab-guest は届かないとき 125 を返すが、podman や docker run も
# 自分の失敗に 125 を使うので、コマンドごとの 125 を「届かない」と読むと取り違える（実測: podman inspect の「無い」が 125）
lab-guest true >/dev/null 2>&1 || prereq
# student の rootless の podman に尋ねる（student のログインのセッションの場所を、環境から引き継がずに決め打ちする）
P() { lab-guest -u student "export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; $1"; }

st=$(lab-guest "podman image inspect busybox:1.38.0 --format '{{.Id}} {{.Digest}}'" 2>&1); rc=$?
echo "判定 : 観測型（root の podman の置き場所を尋ね、root の podman で起動した）"
if [ $rc -ne 0 ]; then echo "観測 : root の置き場所に busybox:1.38.0 が無い"; exit 1; fi
read -r id dg <<<"$st"
run=$(lab-guest 'podman run --rm busybox:1.38.0 echo ok' 2>&1 | tail -1)
echo "観測 : root の置き場所の busybox:1.38.0 の ID = ${id:0:12} / DIGEST = ${dg:7:12}…"
echo "       root の podman で起動 → $run"
[ "${id:0:12}" = aaef90e06523 ] || { echo "       student の busybox:1.38.0（aaef90e06523）と中身が違う"; exit 1; }
if [ "$dg" = sha256:fd7dc98638c8e305f4dc34e979f1c0fdfdcaeb0fbf8fcff77ae834b6da3d7e6e ]; then
  echo "       DIGEST がレジストリの値（fd7dc98638c8…）のまま。レジストリ（のミラー）から取ってきたもので、student の置き場所から運んだものではない"
  exit 1
fi
[ "$run" = ok ] || exit 1
echo "       → student と同じ中身（ID が同じ）を運び（DIGEST は読み込んだ側で作り直されている）、root で起動できた"
exit 0
