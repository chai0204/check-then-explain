#!/usr/bin/env bash
# 演習 05 の判定。観測型（外（lab@host）から実際に curl し、ex05 の公開の設定を見る）。外（lab@host）で走り、練習機の中は lab-guest（qemu-guest-agent 経由・root）で見る。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値に引きずられないよう固定する
prereq() { echo "前提不足: 練習機が応答しません（起動の途中か、止まっている）。外で vm start を打ち、起動を待ってからもう一度"; exit 2; }
# 練習機に届くかを先に1回だけ確かめる。lab-guest は届かないとき 125 を返すが、podman や docker run も
# 自分の失敗に 125 を使うので、コマンドごとの 125 を「届かない」と読むと取り違える（実測: podman inspect の「無い」が 125）
lab-guest true >/dev/null 2>&1 || prereq

port=$(lab-guest 'docker port ex05 80' 2>&1); rc=$?
echo "判定 : 観測型（外の lab@host から実際に curl http://127.0.0.1:8080/ を打ち、ex05 の公開の設定を尋ねた）"
if [ $rc -ne 0 ]; then
  echo "観測 : ex05 が無いか、80 番を公開していない（docker port ex05 80: $(tail -1 <<<"$port")）"
  exit 1
fi
body=$(curl -s -m 8 http://127.0.0.1:8080/ 2>&1)
echo "観測 : docker port ex05 80 → $(tr '\n' ' ' <<<"$port")"
echo "       外から curl http://127.0.0.1:8080/ → ${body:-（応答なし）}"
if grep -qE '^(0\.0\.0\.0|\[::\]):' <<<"$port"; then
  echo "       全部のアドレス（0.0.0.0 / ::）で待ち受けている"
  exit 1
fi
[ "$body" = "hello from ex05" ] || { echo "       「hello from ex05」が返らない"; exit 1; }
grep -qx '10.0.2.15:8080' <<<"$port" || { echo "       練習機の 10.0.2.15:8080 で公開していない"; exit 1; }
echo "       → 10.0.2.15:8080 だけで公開し、外からの接続がコンテナに届いた"
exit 0
