#!/usr/bin/env bash
# 演習 07 の判定。観測型（logs/ を別の場所に写して4本目を足し、count.sh を実際に実行して wc -l と比べる）。
set -uo pipefail
s="$HOME/work/07/count.sh"
src="$HOME/work/07/logs"
[ -d "$src" ] || { echo "前提不足: ~/work/07/logs がありません。先に lab start 07"; exit 2; }
echo "判定 : 観測型（logs/ を別の場所に写して d.log（4行）を足し、そこで count.sh を実行して wc -l と比べた）"
if [ ! -f "$s" ]; then echo "観測 : $s が無い"; exit 1; fi

t=$(mktemp -d /tmp/labchk07.XXXXXX)
mkdir -p "$t/logs"
cp "$src"/*.log "$t/logs/" 2>/dev/null
printf '%s\n' "13:00 起動" "13:01 接続" "13:02 切断" "13:03 停止" > "$t/logs/d.log"
out=$(cd "$t" && timeout 10 bash "$s" 2>&1); rc=$?

want=""; total=0
for f in "$t"/logs/*.log; do
  n=$(wc -l < "$f"); rel="logs/$(basename "$f")"
  want+="$rel: $n 行"$'\n'
  total=$((total + n))
done
want+="合計: $total 行"
find "$t" -mindepth 1 -delete; rmdir "$t"

echo "観測 : count.sh の出力（終了ステータス $rc）"
sed 's/^/         /' <<<"$out"
echo "       wc -l で数えた値"
sed 's/^/         /' <<<"$want"

if [ "$out" != "$want" ]; then
  echo "       → 出力が wc -l の値と一致しない"
  exit 1
fi
echo "       ファイルごとの行数も合計も wc -l と一致した（足した d.log も数えている）"
echo "       → パイプの右側は子のプロセスで回る。そこで増やした数は親に戻らない"
exit 0
