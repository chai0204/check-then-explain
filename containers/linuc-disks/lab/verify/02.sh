#!/usr/bin/env bash
# 演習 02 の判定。観測型（/dev/vdd の表の行と、vdd1 の中身を直接読む。マウントはしない）。
# 中身の確認は debugfs（ext4 を開かずに読む道具）で行う。読者がマウントしていてもいなくても読める。
set -uo pipefail
UUID_WANT=7a1e0c5e-0105-4d15-a5e5-0123456789ab
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }
tbl=$(lab-guest 'sfdisk -d /dev/vdd' 2>/dev/null) || {
  echo "前提不足: 練習機の /dev/vdd に表が読めません（vm reset --yes で初期状態に戻せます）"; exit 2; }

p1=$(grep -E '^/dev/vdd1 ' <<<"$tbl")
start=$(sed -nE 's/.*start= *([0-9]+).*/\1/p' <<<"$p1")
fs=""; word=""
if [ -n "$p1" ]; then
  fs=$(lab-guest 'blkid -p -o export /dev/vdd1' 2>/dev/null)
  word=$(lab-guest 'debugfs -R "cat /aikotoba.txt" /dev/vdd1 2>/dev/null | head -1' 2>/dev/null)
fi
type=$(sed -n 's/^TYPE=//p' <<<"$fs"); uuid=$(sed -n 's/^UUID=//p' <<<"$fs")

echo "判定 : 観測型（/dev/vdd の表と、vdd1 の中身を直接読んだ。マウントはしていない）"
echo "観測 : 表の vdd1 の行 = ${p1:-（表に vdd1 が無い）}"
if [ -n "$p1" ]; then
  echo "       vdd1 の中身    = ${type:-（ファイルシステムの印が見つからない）}${uuid:+ UUID=$uuid}"
  echo "       /aikotoba.txt  = ${word:-（読めない）}"
fi
[ -n "$p1" ] || exit 1
if [ "$start" != 2048 ]; then
  echo "       → vdd1 の開始位置が 2048 ではない（$start）。中身の先頭とずれている"
  exit 1
fi
if [ "$type" != ext4 ] || [ "$uuid" != "$UUID_WANT" ] || [ -z "$word" ]; then
  echo "       → 表の行はあるが、消す前の ext4（UUID $UUID_WANT）として読めない"
  exit 1
fi
echo "       消す前と同じ位置に表の行を書き戻したら、中身は1バイトも失われずに読めた"
echo "       → 表は目次で、消したのは目次の1行だけだった"
exit 0
