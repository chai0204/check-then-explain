#!/usr/bin/env bash
# 演習 03 の判定。観測型（配ったログを数え直し、answer.txt の中身と突き合わせる）。
#   正しい件数は配ったログ（/lab/seed/03/access.log）から awk で数える。
#   読者が使うはずの cut / sort / uniq とは別の道具で数えるのは、同じ間違いを共有しないため。
set -uo pipefail
src=/lab/seed/03/access.log
ans="$HOME/work/03/answer.txt"
[ -f "$src" ] || { echo "前提不足: $src がありません（イメージが壊れている）"; exit 2; }
[ -d "$HOME/work/03" ] || { echo "前提不足: ~/work/03 がありません。先に lab start 03 を打ってください"; exit 2; }

echo "判定 : 観測型（配ったログの9番目の欄を数え直し、answer.txt と突き合わせた）"
if [ ! -f "$ans" ]; then
  echo "観測 : ~/work/03/answer.txt が存在しない"
  exit 1
fi

# 正解: ステータス → 件数
declare -A want=()
while read -r n s; do want[$s]=$n; done < <(awk '{c[$9]++} END{for(s in c) print c[s], s}' "$src")
# 読者の答え（空白の数は問わない）
mapfile -t got < <(awk 'NF{print $1, $2}' "$ans")

echo "観測 : answer.txt の行数 = ${#got[@]}（ログの9番目の欄に出てくるステータスは ${#want[@]} 種類）"
ng=0
declare -A lines=() sum=()
counts=()
for line in "${got[@]}"; do
  n=${line%% *}; s=${line#* }
  if [[ ! $n =~ ^[0-9]+$ ]]; then
    echo "       「$line」: 1つ目が件数（数）になっていない"; ng=1; continue
  fi
  counts+=("$n")
  lines[$s]=$(( ${lines[$s]:-0} + 1 ))
  sum[$s]=$(( ${sum[$s]:-0} + n ))
done
for s in $(printf '%s\n' "${!want[@]}" "${!lines[@]}" | sort -u); do
  w=${want[$s]:-0}; l=${lines[$s]:-0}; t=${sum[$s]:-0}
  if [ "$l" -eq 0 ]; then
    echo "       $s: answer.txt に無い（ログでは $w 行）"; ng=1
  elif [ "$w" -eq 0 ]; then
    echo "       $s: ログの9番目の欄に出てこない値（answer.txt に $l 行）"; ng=1
  elif [ "$l" -gt 1 ]; then
    echo "       $s: answer.txt の $l 行に分かれて出てくる（件数の合計 $t / ログでは $w 行）"; ng=1
  elif [ "$t" -ne "$w" ]; then
    echo "       $s: 件数 $t（ログでは $w 行）"; ng=1
  fi
done
order_ok=1; prev=""
for n in "${counts[@]}"; do
  [ -n "$prev" ] && [ "$n" -gt "$prev" ] && order_ok=0
  prev=$n
done
shown=$(printf '%s ' "${counts[@]:0:10}"); [ "${#counts[@]}" -gt 10 ] && shown="$shown…"
echo "       件数の並び = $shown"
[ "$order_ok" = 1 ] || { echo "       → 件数の多い順になっていない"; ng=1; }
[ "$ng" = 0 ] || exit 1
echo "       各ステータスが1行ずつ、ログの実際の件数で、多い順に並んでいる"
exit 0
