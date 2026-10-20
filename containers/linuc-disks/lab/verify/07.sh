#!/usr/bin/env bash
# 演習 07 の判定。観測型。判定は練習機の状態を変えない（スワップを外したり、足したりしない）。
#   いまの状態      … vdb3 がいまスワップとして使われているか（/proc/swaps。swapon --show と同じもの）
#   起動したあと    … /etc/fstab のスワップの行が vdb3 を指しているか（UUID=・LABEL= を実際の装置に解いて比べる）。
#                     noauto が付いていると起動のときに使われないので、オプションも見る。
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }
lab-guest 'test -b /dev/vdb3' >/dev/null 2>&1 || {
  echo "前提不足: /dev/vdb3 がありません（先に演習03 の切り方にしてください）"; exit 2; }

type=$(lab-guest 'blkid -p -o value -s TYPE /dev/vdb3 2>/dev/null' 2>/dev/null)
prio=$(lab-guest 'awk '"'"'$1=="/dev/vdb3"{print $5}'"'"' /proc/swaps' 2>/dev/null)
# /etc/fstab のスワップの行を、書いたまま（raw）と、装置に解いたもの（evaluate）の2通りで読む（同じ順に並ぶ）
raw=$(lab-guest 'findmnt --fstab -t swap -n -r -o SOURCE,OPTIONS 2>/dev/null' 2>/dev/null)
ev=$(lab-guest 'findmnt --fstab -t swap -n -r --evaluate -o SOURCE 2>/dev/null' 2>/dev/null)
line=""; lopts=""
while IFS= read -r r && IFS= read -r e <&3; do
  if [ "$e" = /dev/vdb3 ]; then line=${r%% *}; lopts=${r#* }; break; fi
done <<<"$raw" 3<<<"$ev"

echo "判定 : 観測型（いま vdb3 が使われているかを /proc/swaps で、起動のときに使われるかを /etc/fstab の行で見た。状態は変えない）"
echo "観測 : vdb3 の中身              = ${type:-（印なし）}"
echo "       いま使われているか       = $([ -n "$prio" ] && echo "はい（優先度 $prio）" || echo いいえ)"
if [ -n "$line" ]; then
  echo "       /etc/fstab のスワップの行 = $line（実体: /dev/vdb3、オプション ${lopts:-?}）"
else
  echo "       /etc/fstab のスワップの行 = ${raw:+（vdb3 を指す行が無い。書いてある行: $(cut -d' ' -f1 <<<"$raw" | paste -sd ' ')）}${raw:-（無い）}"
fi
ng=0
[ "$type" = swap ] || { echo "       → vdb3 がスワップ領域として作られていない"; ng=1; }
[ -n "$prio" ] || { echo "       → vdb3 は、いまスワップとして使われていない"; ng=1; }
[ -n "$line" ] || { echo "       → /etc/fstab に、vdb3 を指すスワップの行が無い（起動したときに使われない）"; ng=1; }
case "$line" in /dev/vd*) echo "       → /etc/fstab の行がデバイス名（/dev/vd…）で書かれている"; ng=1;; esac
case ",$lopts," in *,noauto,*) echo "       → /etc/fstab の行に noauto が付いている（起動したときに使われない）"; ng=1;; esac
[ "$ng" = 0 ] || exit 1
echo "       vdb3 はいま使われていて、/etc/fstab の行も vdb3 を指している → 再起動しても、このスワップは使われる"
exit 0
