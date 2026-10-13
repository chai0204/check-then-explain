#!/usr/bin/env bash
# 演習 06 の判定。観測型（vdb の各パーティションの先頭にある、ファイルシステムの印を blkid で直接読む。
# vdb6 は ext4 の管理情報（tune2fs -l）から予約ブロックの割合を計算する）。マウントの有無は問わない。
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }
n=$(lab-guest 'lsblk -nr -o NAME /dev/vdb 2>/dev/null | grep -c "^vdb[0-9]"' 2>/dev/null)
if [ "${n:-0}" -lt 6 ]; then
  echo "前提不足: /dev/vdb にパーティションが6つありません（先に演習04 の切り方にしてください）"; exit 2
fi

# 番号 種類 ラベル（- はラベルを問わない）
want=( "1 vfat -" "2 ext3 -" "4 xfs ROOT" "5 btrfs VAR" "6 ext4 HOME" )
echo "判定 : 観測型（各パーティションのファイルシステムの印を直接読んだ）"
ng=0; first=1
for w in "${want[@]}"; do
  read -r p t l <<<"$w"
  info=$(lab-guest "blkid -p -o export /dev/vdb$p 2>/dev/null" 2>/dev/null)
  type=$(sed -n 's/^TYPE=//p' <<<"$info"); label=$(sed -n 's/^LABEL=//p' <<<"$info")
  [ "$first" = 1 ] && pre="観測 :" || pre="      "; first=0
  echo "$pre vdb$p = ${type:-（印なし）}${label:+ ラベル $label}"
  [ "$type" = "$t" ] || { echo "       → vdb$p が $t ではない"; ng=1; }
  if [ "$l" != - ] && [ "$label" != "$l" ]; then echo "       → vdb$p のラベルが $l ではない"; ng=1; fi
done

fsinfo=$(lab-guest 'tune2fs -l /dev/vdb6 2>/dev/null' 2>/dev/null)
bc=$(sed -nE 's/^Block count: *([0-9]+)$/\1/p' <<<"$fsinfo")
rc=$(sed -nE 's/^Reserved block count: *([0-9]+)$/\1/p' <<<"$fsinfo")
if [ -n "$bc" ] && [ -n "$rc" ]; then
  pm=$(( (rc * 1000 + bc / 2) / bc ))   # 千分率（四捨五入）
  echo "       vdb6 の予約ブロック = $rc / $bc ブロック（$((pm / 10)).$((pm % 10))%）"
  if [ "$pm" -lt 5 ] || [ "$pm" -gt 15 ]; then
    echo "       → 予約が 1% ではない"; ng=1
  fi
fi
[ "$ng" = 0 ] || exit 1
echo "       5つの種類のファイルシステムができ、vdb6 は root 用の予約が 1% になっている"
echo "       → df の Avail が Size − Used より小さかった分の正体は、この予約"
exit 0
