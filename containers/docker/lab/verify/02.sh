#!/usr/bin/env bash
# 演習 02 の判定。観測型（動いている ex02 に実際に docker stop を打ち、時間と終了コードを見る。見た後は起動し直す）。外（lab@host）で走り、練習機の中は lab-guest（qemu-guest-agent 経由・root）で見る。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値に引きずられないよう固定する
prereq() { echo "前提不足: 練習機が応答しません（起動の途中か、止まっている）。外で vm start を打ち、起動を待ってからもう一度"; exit 2; }
# 練習機に届くかを先に1回だけ確かめる。lab-guest は届かないとき 125 を返すが、podman や docker run も
# 自分の失敗に 125 を使うので、コマンドごとの 125 を「届かない」と読むと取り違える（実測: podman inspect の「無い」が 125）
lab-guest true >/dev/null 2>&1 || prereq

st=$(lab-guest "docker inspect -f '{{.State.Running}} {{.HostConfig.Init}} {{.Config.StopSignal}}' ex02" 2>&1); rc=$?
echo "判定 : 観測型（ex02 に docker stop を打ち、かかった時間と終了コードを見た。見た後は docker start で起動し直した）"
if [ $rc -ne 0 ]; then
  echo "観測 : ex02 という名前のコンテナが無い（docker inspect ex02: $(tail -1 <<<"$st")）"
  exit 1
fi
read -r running init sig <<<"$st"
[ "$running" = true ] || { echo "観測 : ex02 は動いていない（判定は、動いている ex02 を止めて止まり方を見る）"; exit 1; }
case "${sig:-}" in
  ""|SIGTERM|TERM|15) ;;
  *) echo "観測 : docker stop が最初に送る合図が TERM ではない（--stop-signal / STOPSIGNAL が $sig）"
     echo "       この演習は、TERM で終わるようにすること"
     exit 1 ;;
esac
t0=$(date +%s%N)
lab-guest 'docker stop ex02' >/dev/null 2>&1
t1=$(date +%s%N)
code=$(lab-guest "docker inspect -f '{{.State.ExitCode}}' ex02" 2>/dev/null)
lab-guest 'docker start ex02' >/dev/null 2>&1
secs=$(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.1f", (b - a) / 1e9 }')
case "$init" in true) iv="あり" ;; *) iv="なし" ;; esac
echo "観測 : docker stop ex02 に ${secs} 秒、終了コード ${code}（--init ${iv}）"
case "$code" in
  137) echo "       137 = 128 + 9。TERM は届かず、待ち時間の後に KILL で止められた"
       exit 1 ;;
  143) echo "       143 = 128 + 15。TERM で終わったという報告（--init の docker-init は、子が TERM で終わったことをこの値で報告する）" ;;
  *)   echo "       KILL（137）ではなく、TERM を受け取ったプロセスが自分で決めたコード（$code）で終わった" ;;
esac
echo "       （判定の後、docker start ex02 で起動し直しました）"
exit 0
