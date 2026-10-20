#!/usr/bin/env bash
# 演習 01 の判定。観測型（labhello を実際に動かし、dpkg の台帳の状態を見る）。
set -uo pipefail
command -v dpkg-query >/dev/null || { echo "前提不足: dpkg-query が見つかりません"; exit 2; }

st=$(dpkg-query -W -f='${db:Status-Abbrev}' labhello 2>/dev/null | tr -d ' ')
ver=$(dpkg-query -W -f='${Version}' labhello 2>/dev/null)
echo "判定 : 観測型（labhello を動かし、dpkg の台帳を見た）"
if [ -x /usr/bin/labhello ]; then
  out=$(/usr/bin/labhello 2>&1); rc=$?
  echo "観測 : labhello の出力 = $out（終了コード $rc）"
else
  out=""; rc=127
  echo "観測 : /usr/bin/labhello = 無い（labhello と打っても見つからない）"
fi
echo "       dpkg の台帳 = ${st:-labhello の行が無い}${ver:+（版 $ver）}"

ng=0
[ "$rc" = 0 ] || { echo "       → labhello が動かない"; ng=1; }
case "$out" in "labhello "*) ;; *) [ "$rc" != 0 ] || { echo "       → 自分の版を出していない"; ng=1; } ;; esac
[ "$st" = ii ] || { echo "       → 台帳で labhello が ii（入っていて、使える状態）になっていない"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       labhello はパッケージとして入っていて（ii）、動いて版を出した"
exit 0
