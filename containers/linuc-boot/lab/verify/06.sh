#!/usr/bin/env bash
# 演習 06 の判定。観測型（systemd が記録した lab-hog の終わり方と、いまのプロセスの状態を見る）。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値（system）に引きずられないよう固定する

q='systemctl show lab-hog.service -p LoadState -p ActiveState -p SubState -p Result -p ExecMainPID -p ExecMainCode -p ExecMainStatus -p ExecMainStartTimestampMonotonic'
st=$(lab-guest "$q" 2>/dev/null); rc=$?
[ $rc -eq 125 ] && { echo "前提不足: 練習機の中から応答がありません（電源が切れている・起動の途中・systemd を通らない起動（init=/bin/bash など）のどれか）。virsh domstate linuc と virsh console linuc で状態を見てください"; exit 2; }
get() { sed -n "s/^$1=//p" <<<"$st"; }
# 主プロセスが KILL で終わった直後は、systemd が残りのプロセス（TERM を無視する設定を受け継いだ子の sleep）を
# 片付けている途中で deactivating になる（実測）。落ち着くまで最大 15 秒待ってから判定する。
for _ in $(seq 1 15); do
  [ "$(get ActiveState)" = deactivating ] || break
  sleep 1; st=$(lab-guest "$q" 2>/dev/null)
done
load=$(get LoadState); act=$(get ActiveState); sub=$(get SubState); res=$(get Result)
pid=$(get ExecMainPID); code=$(get ExecMainCode); sig=$(get ExecMainStatus)
started=$(get ExecMainStartTimestampMonotonic)

[ "$load" = loaded ] || { echo "前提不足: lab-hog.service がありません（初回の準備が済んでいない。vm reset --yes で戻せます）"; exit 2; }

echo "判定 : 観測型（systemd が記録した lab-hog の状態と終わり方を、練習機の中で尋ねた）"
if [ "$act" = active ] || [ "$act" = deactivating ]; then
  echo "観測 : lab-hog はまだ動いている（$act/$sub、PID $pid）"
  lab-guest "ps -o pid=,stat=,user=,comm= -p $pid; grep -E '^Sig(Ign|Cgt)' /proc/$pid/status" 2>/dev/null | sed 's/^/       /'
  exit 1
fi
if [ "${started:-0}" = 0 ]; then
  echo "観測 : lab-hog はこの起動で一度も動いていない（$act/$sub）"
  echo "前提不足: 再起動や disable で、相手のプロセスがいない状態です（systemctl start lab-hog か vm reset --yes で戻せます）"
  exit 2
fi

case "$code" in
  1) how="終了コード $sig で自分から終わった" ;;
  2) how="シグナル $sig（$(lab-guest "kill -l $sig" 2>/dev/null)）で終わった" ;;
  3) how="シグナル $sig でコアを吐いて終わった" ;;
  *) how="終わり方の記録が無い（code=$code status=$sig）" ;;
esac
echo "観測 : lab-hog は止まっている（$act/$sub、Result=$res）"
echo "       主プロセスは $how"
case "$res" in
  signal)  echo "       → 止めたのはあなたが送ったシグナル。TERM は無視されるので、届いたのは捕まえられない合図" ;;
  timeout) echo "       → systemctl stop の TERM が無視され、10 秒待った systemd が KILL を送った" ;;
esac
exit 0
