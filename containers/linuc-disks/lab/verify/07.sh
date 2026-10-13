#!/usr/bin/env bash
# 演習 07 の判定。観測型。
# 「起動時にも有効になるか」を、再起動せずに確かめる。vdb3 のスワップをいったん外し（swapoff）、
# 起動時と同じ「/etc/fstab のスワップを全部有効にする」（swapon -a）を1回だけ実行して、戻ってくるかを見る。
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }
lab-guest 'test -b /dev/vdb3' >/dev/null 2>&1 || {
  echo "前提不足: /dev/vdb3 がありません（先に演習04 の切り方にしてください）"; exit 2; }

type=$(lab-guest 'blkid -p -o value -s TYPE /dev/vdb3 2>/dev/null' 2>/dev/null)
before=$(lab-guest 'grep -c "^/dev/vdb3 " /proc/swaps' 2>/dev/null)
fst=$(lab-guest 'findmnt --fstab -t swap -n -o SOURCE 2>/dev/null | paste -sd " "' 2>/dev/null)
fste=$(lab-guest 'findmnt --fstab -t swap -n --evaluate -o SOURCE 2>/dev/null | paste -sd " "' 2>/dev/null)
after=$(lab-guest 'swapoff /dev/vdb3 2>/dev/null; swapon -a 2>&1 >/dev/null | head -2; grep -c "^/dev/vdb3 " /proc/swaps' 2>/dev/null)
after_n=$(tail -1 <<<"$after"); after_msg=$(sed '$d' <<<"$after")

echo "判定 : 観測型（vdb3 をいったん swapoff し、起動時と同じ swapon -a を1回実行して、戻るかを見た）"
echo "観測 : vdb3 の中身              = ${type:-（印なし）}"
echo "       判定の前に使われていたか = $([ "${before:-0}" -ge 1 ] && echo はい || echo いいえ)"
echo "       /etc/fstab のスワップの行 = ${fst:-（無い）}${fste:+（実体: $fste）}"
echo "       swapon -a の後に使われているか = $([ "${after_n:-0}" -ge 1 ] && echo はい || echo いいえ)"
[ -n "$after_msg" ] && echo "       swapon -a の出力: $after_msg"
ng=0
[ "$type" = swap ] || { echo "       → vdb3 がスワップ領域として作られていない"; ng=1; }
[ "${after_n:-0}" -ge 1 ] || { echo "       → /etc/fstab から有効にすると、vdb3 は使われない"; ng=1; }
case " $fst " in *" /dev/vdb3 "*|*" /dev/vd"*)
  echo "       → /etc/fstab の行がデバイス名（/dev/vd…）で書かれている"; ng=1;; esac
[ "$ng" = 0 ] || exit 1
echo "       /etc/fstab の行から vdb3 が有効になった → 再起動しても、このスワップは使われる"
exit 0
