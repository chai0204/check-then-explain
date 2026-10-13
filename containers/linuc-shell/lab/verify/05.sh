#!/usr/bin/env bash
# 演習 05 の判定。観測型（isuser.sh を4通りの引数で実際に実行し、終了ステータスを見る）。
set -uo pipefail
s="$HOME/work/05/isuser.sh"
[ -d "$HOME/work/05" ] || { echo "前提不足: ~/work/05 がありません。先に lab start 05"; exit 2; }
echo "判定 : 観測型（isuser.sh を4通りで実行し、\$? を読んだ）"
if [ ! -f "$s" ]; then echo "観測 : $s が無い"; exit 1; fi

run() { (cd /tmp && timeout 10 bash "$s" "$@" >/dev/null 2>&1); echo $?; }
r_lab=$(run lab)
r_none=$(run nosuchuser)
r_la=$(run la)
r_noarg=$(run)

echo "観測 : bash isuser.sh lab         → \$? = $r_lab"
echo "       bash isuser.sh nosuchuser  → \$? = $r_none"
echo "       bash isuser.sh la          → \$? = $r_la"
echo "       bash isuser.sh（引数なし） → \$? = $r_noarg"

ng=0
[ "$r_lab" = 0 ]   || { echo "       → 居るユーザ（lab）で 0 にならない"; ng=1; }
[ "$r_none" = 1 ]  || { echo "       → 居ないユーザ（nosuchuser）で 1 にならない"; ng=1; }
[ "$r_la" = 1 ]    || { echo "       → la（lab の先頭部分）で 1 にならない"; ng=1; }
[ "$r_noarg" = 2 ] || { echo "       → 引数なしで 2 にならない"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       居る 0 / 居ない 1 / 引数なし 2 を、表示ではなく終了ステータスで返している"
echo "       → スクリプトが親に返せるのは、この 0〜255 の数1つだけ"
exit 0
