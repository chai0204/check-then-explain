#!/usr/bin/env bash
# 演習 08 の判定。観測型（number.sh に alice bob carol を渡して実際に実行し、出力を期待の6行と比べる）。
set -uo pipefail
s="$HOME/work/08/number.sh"
[ -d "$HOME/work/08" ] || { echo "前提不足: ~/work/08 がありません。先に lab start 08"; exit 2; }
echo "判定 : 観測型（bash number.sh alice bob carol を実行し、出力を期待の6行と比べた）"
if [ ! -f "$s" ]; then echo "観測 : $s が無い"; exit 1; fi

bar="--------------------"
want=$(printf '%s\n' "1: alice" "$bar" "2: bob" "$bar" "3: carol" "$bar")
out=$(cd /tmp && timeout 10 bash "$s" alice bob carol 2>&1); rc=$?
nums=$(grep -oE '^[0-9]+:' <<<"$out" | tr -d ':' | tr '\n' ' ')

echo "観測 : 終了ステータス $rc / 番号の並び = ${nums:-（なし）}"
sed 's/^/         /' <<<"$out" | head -8

if [ "$out" != "$want" ]; then
  [ "$nums" = "1 2 3 " ] || echo "       → 番号が 1 2 3 と並んでいない"
  [ "$(grep -cxF -- "$bar" <<<"$out")" = 3 ] || echo "       → 20文字の区切り線が3本ではない"
  echo "       → 出力が期待の6行と一致しない"
  exit 1
fi
echo "       番号が 1 2 3 と続き、区切り線も3本ある"
echo "       → 関数は子のプロセスではない。local を付けない変数は、呼んだ側と同じもの"
exit 0
