#!/usr/bin/env bash
# 演習 03 の判定。観測型（いま動いているカーネルが受け取った引数と、systemd が実際に到達したターゲットを見る）。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値（system）に引きずられないよう固定する

cmdline=$(lab-guest 'cat /proc/cmdline' 2>/dev/null); rc=$?
[ $rc -eq 125 ] && { echo "前提不足: 練習機の中から応答がありません（電源が切れている・起動の途中・systemd を通らない起動（init=/bin/bash など）のどれか）。virsh domstate linuc と virsh console linuc で状態を見てください"; exit 2; }
def=$(lab-guest 'systemctl get-default' 2>/dev/null)
gr=$(lab-guest 'systemctl is-active graphical.target' 2>/dev/null)
mu=$(lab-guest 'systemctl is-active multi-user.target' 2>/dev/null)

echo "判定 : 観測型（/proc/cmdline と、systemd が到達したターゲットを練習機の中で見た）"
echo "観測 : /proc/cmdline → $cmdline"
echo "       multi-user.target → $mu / graphical.target → $gr"
echo "       既定のターゲット（systemctl get-default）→ $def"

ng=0
if grep -qE '(^| )(systemd\.unit=(multi-user|runlevel3)\.target|3)( |$)' <<<"$cmdline"; then
  echo "       カーネル引数に multi-user を指す指定がある"
else
  echo "       → カーネル引数に起動ターゲットの指定が無い"
  ng=1
fi
[ "$mu" = active ] || { echo "       → multi-user.target が active でない"; ng=1; }
[ "$gr" = inactive ] || { echo "       → graphical.target が inactive でない"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       設定ファイルではなく、この1回の起動に渡した引数で multi-user.target に止まった"
[ "$def" = graphical.target ] && echo "       既定は graphical.target のまま。次に普通に起動すれば元に戻る"
exit 0
