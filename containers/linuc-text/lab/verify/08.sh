#!/usr/bin/env bash
# 演習 08 の判定。観測型（保存された todo.txt の中身を、4つの指示ごとに確かめる）。
set -uo pipefail
f="$HOME/work/08/todo.txt"
[ -d "$HOME/work/08" ] || { echo "前提不足: ~/work/08 がありません。先に lab start 08 を打ってください"; exit 2; }
echo "判定 : 観測型（保存された todo.txt の中身を読んだ）"
[ -f "$f" ] || { echo "観測 : ~/work/08/todo.txt が存在しない"; exit 1; }
if ls "$HOME/work/08"/.todo.txt.sw? >/dev/null 2>&1; then
  echo "観測 : vi のスワップファイル（.todo.txt.swp）が残っている。vi がまだ開いているか、途中で落ちた"
  exit 2
fi

want=$'TODO\nbuy bread\nbuy eggs\ncall bob\nwrite summary\nbuy milk'
n_call=$(grep -cx 'call bob' "$f")
after_bread=$(grep -A1 -x 'buy bread' "$f" | sed -n 2p)
summary=$(grep -cx 'write summary' "$f")
report=$(grep -cx 'write report' "$f")
last=$(tail -n 1 "$f")
n_milk=$(grep -cx 'buy milk' "$f")

echo "観測 : 行数 = $(grep -c '' "$f")"
echo "       1. call bob の行     = ${n_call} 行"
echo "       2. buy bread の次の行 = ${after_bread:-（無い）}"
echo "       3. write summary     = ${summary} 行 / write report = ${report} 行"
echo "       4. 最後の行           = ${last:-（空）}（buy milk は全部で ${n_milk} 行）"
if [ -f "$HOME/.viminfo" ]; then
  echo "       （参考: ~/.viminfo がある = この檻で vim を使って終了したことがある）"
fi

if [ "$(cat "$f")" = "$want" ]; then
  echo "       4か所とも指示どおりで、ほかの行は変わっていない"
  exit 0
fi
[ "$n_call" -eq 1 ] && [ "$after_bread" = "buy eggs" ] && [ "$summary" -eq 1 ] && [ "$report" -eq 0 ] \
  && [ "$last" = "buy milk" ] && [ "$n_milk" -eq 1 ] \
  && echo "       → 4か所は合っているが、ほかの行が増えたか、並びが違う"
exit 1
