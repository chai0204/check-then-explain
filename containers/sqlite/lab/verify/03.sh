#!/usr/bin/env bash
# 演習 03 の判定。観測型（行数）＋痕跡型（読者が測った時間の記録）。
set -uo pipefail
command -v sqlite3 >/dev/null || { echo "前提不足: sqlite3 が見つかりません"; exit 2; }

for f in 03/naive.db 03/txn.db; do
  [ -f "$f" ] || { echo "観測 : ~/work/$f が存在しない"; exit 1; }
done

na=$(sqlite3 03/naive.db "SELECT count(*) FROM a;" 2>&1) || { echo "観測 : naive.db の a テーブルを読めない（$na）"; exit 1; }
nb=$(sqlite3 03/txn.db   "SELECT count(*) FROM b;" 2>&1) || { echo "観測 : txn.db の b テーブルを読めない（$nb）"; exit 1; }
[ "$na" = "2000" ] || { echo "観測 : a の行数が $na（2000 を期待）"; exit 1; }
[ "$nb" = "2000" ] || { echo "観測 : b の行数が $nb（2000 を期待）"; exit 1; }

T="03/times.txt"
[ -s "$T" ] || { echo "観測 : $T が空、または存在しない"; exit 1; }
tn=$(sed -n 's/^naive=//p' "$T" | head -1)
tt=$(sed -n 's/^txn=//p'   "$T" | head -1)
[ -n "$tn" ] && [ -n "$tt" ] || {
  echo "観測 : $T から naive= と txn= の2行を読めない"
  echo "       実際の内容: $(tr '\n' ' ' < "$T")"
  exit 1
}
ok=$(awk -v a="$tn" -v b="$tt" 'BEGIN{print (a+0>0 && b+0>0) ? "y" : "n"}')
[ "$ok" = y ] || { echo "観測 : 秒数が数値として読めない（naive=$tn txn=$tt）"; exit 1; }

ratio=$(awk -v a="$tn" -v b="$tt" 'BEGIN{printf "%.0f", a/b}')
faster=$(awk -v a="$tn" -v b="$tt" 'BEGIN{print (a>b) ? "y" : "n"}')

echo "判定 : 観測型（両テーブルの行数）＋痕跡型（あなたが測った秒数の記録）"
echo "観測 : a=${na}行 / b=${nb}行 で同じ結果になっている"
echo "       naive=${tn}秒  txn=${tt}秒  → 約 ${ratio} 倍の差"
if [ "$faster" != y ]; then
  echo "       ※ トランザクション側が速くなっていません。測り方を見直す価値があります"
  exit 1
fi
echo "       （著者の環境では 12.996 秒 → 0.048 秒 ＝ 約270倍でした）"
exit 0
