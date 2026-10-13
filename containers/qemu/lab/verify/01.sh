#!/usr/bin/env bash
# 演習 01 の判定。観測型（~/work/01/qmp.sock に QMP で実際に問い合わせ、そのソケットを待ち受けている QEMU のプロセスを
# /proc で見て、~/work/01/serial.log を読む）。
#   - 画面が無いと伝えたか : QMP の qom-get /machine graphics が false
#   - 端末から切り離したか : そのプロセスに制御端末が無い（/proc/PID/stat の tty_nr が 0）。-daemonize は setsid で
#                            端末を手放す。& で後ろに回しただけなら、制御端末はこの端末のまま
#   - serial.log がいまの QEMU のものか : そのプロセスが ~/work/01/serial.log を開いている（/proc/PID/fd）
#   ソケットとプロセスは、/proc/net/unix の inode と /proc/PID/fd の socket:[inode] で突き合わせる。
#   相対パスで作ったソケットは /proc/net/unix に相対パスで出るので、そのプロセスを起動したときの PWD を前に付けて比べる
#   （-daemonize した QEMU は作業ディレクトリを / に移しているので、/proc/PID/cwd は使えない）。
set -uo pipefail
command -v socat >/dev/null && command -v jq >/dev/null || { echo "前提不足: socat か jq が見つかりません（檻のイメージを確かめてください）"; exit 2; }
W=$HOME/work/01
sock=$W/qmp.sock
log=$W/serial.log
Q=/lab/bin/qmp

echo "判定 : 観測型（~/work/01/qmp.sock に QMP で問い合わせ、そのソケットを待ち受けている QEMU を /proc で見て、~/work/01/serial.log を読んだ）"
if [ ! -e "$sock" ]; then
  echo "観測 : ~/work/01/qmp.sock が無い"
  exit 1
fi
if [ ! -S "$sock" ]; then
  echo "観測 : ~/work/01/qmp.sock はあるが、UNIX ソケットではない"
  exit 1
fi
st=$($Q "$sock" query-status 2>/dev/null)
if [ -z "$st" ]; then
  echo "観測 : ~/work/01/qmp.sock はあるが、QMP の返事が無い（そのソケットを開いた QEMU は、もう終わっている）"
  exit 1
fi
status=$(jq -r 'if has("return") then .return.status else (.error.desc // "?") end' <<<"$st")
# jq の // は false も「無い」と扱うので、has で分ける（graphics=off のときの値は false）
gr=$($Q "$sock" qom-get '{"path":"/machine","property":"graphics"}' | jq -r 'if has("return") then .return else (.error.desc // "?") end')
ser=$($Q "$sock" query-chardev | jq -r '.return[]? | select(.label == "serial0") | .filename')
disks=$($Q "$sock" query-block | jq -r '[.return[]? | select(.inserted) | .device // .qdev] | join(", ")')

# このソケットを待ち受けている QEMU を探す
qpid=""
for p in $(pgrep -x qemu-system-x86); do
  pwd0=$(tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | sed -n 's/^PWD=//p')
  for ino in $(for fd in /proc/"$p"/fd/*; do readlink "$fd"; done 2>/dev/null | sed -n 's/^socket:\[\([0-9]*\)\]$/\1/p'); do
    path=$(awk -v i="$ino" '$7 == i && NF >= 8 {print $8}' /proc/net/unix)
    [ -n "$path" ] || continue
    case $path in /*) ;; *) path=${pwd0:-?}/$path ;; esac
    [ "$path" = "$sock" ] && { qpid=$p; break 2; }
  done
done
tty="?"; holds=no
if [ -n "$qpid" ]; then
  tty=$(sed 's/^.*) //' "/proc/$qpid/stat" | cut -d' ' -f5)
  for fd in /proc/"$qpid"/fd/*; do
    [ "$(readlink "$fd" 2>/dev/null)" = "$log" ] && { holds=yes; break; }
  done
fi
nsea=0
[ -f "$log" ] && nsea=$(grep -ac 'SeaBIOS' "$log")

echo "観測 : QMP の query-status                     → $status"
echo "       /machine の graphics（画面があると伝えたか）→ $gr"
echo "       serial0 のつなぎ先（query-chardev）       → ${ser:-（serial0 が無い）}"
echo "       媒体が入っている装置（query-block）       → ${disks:-なし}"
if [ -n "$qpid" ]; then
  echo "       このソケットを待ち受けている QEMU         → PID $qpid（制御端末 $([ "$tty" = 0 ] && echo なし || echo あり)）"
  echo "       その QEMU が ~/work/01/serial.log を開いているか → $([ "$holds" = yes ] && echo 開いている || echo 開いていない)"
else
  echo "       このソケットを待ち受けている QEMU         → 見つからない"
fi
if [ -f "$log" ]; then
  echo "       ~/work/01/serial.log                       → $(stat -c %s "$log") バイト、SeaBIOS の文字 $nsea 個"
else
  echo "       ~/work/01/serial.log                       → 無い"
fi

ng=0
[ "$status" = running ] || { echo "       → QEMU が running ではない"; ng=1; }
[ "$gr" = false ] || { echo "       → ファームウェアに「画面が無い」と伝えていない（graphics が false ではない）"; ng=1; }
[ "$ser" = file ] || { echo "       → シリアルポートがファイルにつながっていない"; ng=1; }
if [ -z "$qpid" ]; then
  echo "       → このソケットを待ち受けている QEMU のプロセスが見つからない"; ng=1
else
  [ "$tty" = 0 ] || { echo "       → その QEMU は端末につながったまま（& で後ろに回しただけなど）。端末から切り離されていない"; ng=1; }
  [ "$holds" = yes ] || { echo "       → その QEMU は ~/work/01/serial.log に書いていない（前に動かした QEMU が残したファイルかもしれない）"; ng=1; }
fi
[ -f "$log" ] || { echo "       → シリアルの記録 ~/work/01/serial.log が無い"; ng=1; }
[ "$nsea" -ge 1 ] || { echo "       → serial.log に SeaBIOS の画面が出ていない"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       端末から切り離された QEMU に QMP で問い合わせができ、その QEMU が SeaBIOS の画面を serial.log に書いている"
echo "       → シリアルもモニタも「線の先」を付け替えただけ。画面が無くても PC は動いている"
exit 0
