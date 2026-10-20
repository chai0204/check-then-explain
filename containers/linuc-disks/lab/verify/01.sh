#!/usr/bin/env bash
# 演習 01 の判定。観測型（/dev/vde の表と、vde1 の中の ext4 を直接読む。マウントはしない）。
# 中身の確認は debugfs（ext4 を開かずに読む道具）で行う。いまマウントしているかどうかは findmnt で別に見る。
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }
lab-guest 'test -b /dev/vde' >/dev/null 2>&1 || {
  echo "前提不足: 練習機に /dev/vde が見つかりません（vm reset --yes で初期状態に戻せます）"; exit 2; }

tbl=$(lab-guest 'sfdisk -d /dev/vde 2>/dev/null' 2>/dev/null)
rows=$(grep -c '^/dev/vde[0-9]' <<<"$tbl")
fs=""; st=""; mnt=""
if [ "$rows" -ge 1 ]; then
  fs=$(lab-guest 'blkid -p -o value -s TYPE /dev/vde1 2>/dev/null' 2>/dev/null)
  if [ "$fs" = ext4 ]; then
    st=$(lab-guest 'debugfs -R "stat /hello.txt" /dev/vde1 2>/dev/null | grep -o "Type: [a-z]*" | head -1' 2>/dev/null)
  fi
  mnt=$(lab-guest 'findmnt -n -o TARGET --source /dev/vde1 2>/dev/null | paste -sd " "' 2>/dev/null)
fi

echo "判定 : 観測型（vde の表と、vde1 の中の ext4 を直接読んだ。マウントはしていない）"
echo "観測 : vde の区画       = ${rows} 個"
if [ "$rows" -ge 1 ]; then
  echo "       vde1 の中身      = ${fs:-（ファイルシステムの印が見つからない）}"
  [ "$fs" = ext4 ] && echo "       vde1 の /hello.txt = $([ "$st" = "Type: regular" ] && echo ある || echo 無い)"
  echo "       vde1 のマウント先 = ${mnt:-（どこにもマウントされていない）}"
fi
[ "$rows" -ge 1 ] || { echo "       → vde にパーティションが無い"; exit 1; }
[ "$fs" = ext4 ] || { echo "       → vde1 が ext4 ではない"; exit 1; }
[ "$st" = "Type: regular" ] || { echo "       → vde1 の ext4 のいちばん上に hello.txt が無い"; exit 1; }
[ -z "$mnt" ] || { echo "       → まだマウントされている（最後に外す）"; exit 1; }
echo "       区切る → ext4 を作る → マウントして書く → 外す、が全部済んでいる"
echo "       → 外したあとも、hello.txt は vde1 の ext4 の中に残っている"
exit 0
