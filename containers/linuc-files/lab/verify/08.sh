#!/usr/bin/env bash
# 演習 08 の判定。観測型（locate needle.txt を実際に引く）。
set -uo pipefail
P1=/home/lab/work/08/needle.txt
P2=/tmp/needle.txt
command -v locate >/dev/null || { echo "前提不足: locate が見つかりません"; exit 2; }
[ -e "$P1" ] && [ -e "$P2" ] || {
  echo "前提不足: $P1 と $P2 を先に作ってください（課題の最初の touch）"; exit 2; }

res=$(locate needle.txt 2>&1)
db=/var/lib/plocate/plocate.db

echo "判定 : 観測型（locate needle.txt を実際に引いた）"
echo "観測 : locate needle.txt の結果:"
printf '%s\n' "${res:-（何も出ない）}" | sed 's/^/         /'
echo "       索引の更新時刻   = $(stat -c %y "$db" 2>/dev/null | cut -d. -f1)"
echo "       needle.txt の作成 = $(stat -c %y "$P1" 2>/dev/null | cut -d. -f1)（~/work/08）"
echo "       PRUNEPATHS       = $(sed -n 's/^PRUNEPATHS=//p' /etc/updatedb.conf)"

ng=0
grep -qx -- "$P1" <<<"$res" || { echo "       → $P1 が出ない"; ng=1; }
grep -qx -- "$P2" <<<"$res" || { echo "       → $P2 が出ない"; ng=1; }
[ "$ng" = 0 ] || exit 1
echo "       2つとも locate の結果に出た"
echo "       → locate は索引を引くだけ。索引を作り直し、/tmp を外す設定を消したので両方が載った"
exit 0
