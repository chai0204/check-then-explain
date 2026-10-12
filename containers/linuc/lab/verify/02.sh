#!/usr/bin/env bash
# 演習 02 の判定。観測型（chronyd 自身が報告する状態を読む）。
set -uo pipefail
command -v chronyc >/dev/null || { echo "前提不足: chronyc が見つかりません"; exit 2; }
t=$(chronyc tracking 2>&1) || { echo "前提不足: chronyd に問い合わせできません"; echo "$t" | sed 's/^/       /'; exit 2; }

refid=$(awk '/^Reference ID/{print $4}' <<<"$t")
leap=$(sed -n 's/^Leap status *: *//p' <<<"$t")
nsrc=$(chronyc -c sources 2>/dev/null | grep -c . || true)

echo "判定 : 観測型（chronyd 自身が報告する Reference ID と Leap status）"
echo "観測 : Reference ID = ${refid:-（空）}"
echo "       Leap status  = ${leap:-（空）}"
echo "       ソース本数   = ${nsrc}"

ng=0
[ "$refid" = "7F000001" ] || { echo "       → Reference ID が 7F000001（127.0.0.1）ではない"; ng=1; }
[ "$leap" = "Normal" ]    || { echo "       → Leap status が Normal ではない"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       檻の中の基準サーバ（127.0.0.1）を選び、同期状態になっている"
echo "       （時計は動かしていない。chronyd は -x で起動している）"
exit 0
