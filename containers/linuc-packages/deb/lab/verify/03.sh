#!/usr/bin/env bash
# 演習 03 の判定。観測型（dpkg の台帳の状態と、labnote を実際に動かした結果を見る）。
set -uo pipefail
command -v dpkg-query >/dev/null || { echo "前提不足: dpkg-query が見つかりません"; exit 2; }

st() { dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null | tr -d ' '; }
s_note=$(st labnote)
s_data=$(st labnote-data)
echo "判定 : 観測型（dpkg の台帳の状態と、labnote を動かした結果を見た）"
echo "観測 : labnote      の台帳 = ${s_note:-行が無い}"
echo "       labnote-data の台帳 = ${s_data:-行が無い}"
if command -v labnote >/dev/null 2>&1; then
  out=$(labnote 2>&1); rc=$?
  echo "       labnote の出力 = $out（終了コード $rc）"
else
  out=""; rc=127
  echo "       labnote = コマンドとして見つからない"
fi

ng=0
case "$s_note" in
  ii) ;;
  iU) echo "       → labnote が iU（展開済み・設定前）で止まっている"; ng=1 ;;
  "") echo "       → labnote が台帳に無い"; ng=1 ;;
  *)  echo "       → labnote が ii になっていない（$s_note）"; ng=1 ;;
esac
[ "$s_data" = ii ] || { echo "       → labnote-data が ii になっていない（${s_data:-台帳に無い}）"; ng=1; }
[ "$rc" = 0 ] || { echo "       → labnote が終了コード $rc で終わった"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       labnote と labnote-data がどちらも ii で、labnote が動いた"
exit 0
