#!/usr/bin/env bash
# 演習 04 の判定。観測型（~/work/04/tcg.log を読む。翻訳した塊の数と、最初の塊の番地とバイト列）。
set -uo pipefail
f=$HOME/work/04/tcg.log

echo "判定 : 観測型（~/work/04/tcg.log の「IN:」の塊を数え、最初の塊を読んだ）"
if [ ! -f "$f" ]; then
  echo "観測 : ~/work/04/tcg.log が無い"
  exit 1
fi
n=$(grep -c '^IN:' "$f")
# 最初の塊: 「IN:」の次の行が番地、その次が命令のバイト列（この QEMU は逆アセンブラが無いので OBJD-T: で出す）
first=$(awk '/^IN:/{getline a; getline b; print a" "b; exit}' "$f")
addr=$(awk '{print $1}' <<<"$first" | tr -d ': ')
bytes=$(sed -n 's/.*OBJD-T: *\([0-9a-f]*\).*/\1/p' <<<"$first")
second=$(awk '/^IN:/{c++; getline a; if (c == 2) {print a; exit}}' "$f" | tr -d ': ')
echo "観測 : 翻訳した塊（IN:）→ $n 個"
echo "       最初の塊の番地 → ${addr:-（読めない）}  命令のバイト列 → ${bytes:-（読めない）}"
echo "       2つ目の塊の番地 → ${second:-（無い）}"

ng=0
[ "$n" -ge 100 ] 2>/dev/null || { echo "       → 翻訳した塊が少なすぎる（100 未満）。-d in_asm の記録ではないか、動かした時間が短い"; ng=1; }
[ "$addr" = 0xfffffff0 ] || { echo "       → 最初の塊がリセットベクタ 0xfffffff0 ではない（電源を入れた直後からの記録ではない）"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       電源を入れた直後の 0xfffffff0 から、命令を塊ごとに翻訳した記録が残っている"
[ "$bytes" = ea5be000f0 ] && echo "       → ea 5b e0 00 f0 は「f000:e05b へ跳べ」。跳んだ先（${second:-?}）が SeaBIOS の本体"
exit 0
