#!/usr/bin/env bash
# 演習 04 の判定。観測型（labbackup を動かした結果と、dpkg の台帳との照らし合わせを見る）。
set -uo pipefail
command -v dpkg-query >/dev/null || { echo "前提不足: dpkg-query が見つかりません"; exit 2; }

st=$(dpkg-query -W -f='${db:Status-Abbrev}' labbackup 2>/dev/null | tr -d ' ')
echo "判定 : 観測型（labbackup を動かした結果と、dpkg -V labbackup の結果を見た）"
echo "観測 : dpkg の台帳 = ${st:-labbackup の行が無い}"
ver=""
if [ -n "$st" ]; then
  ver=$(dpkg -V labbackup 2>&1)
  if [ -n "$ver" ]; then
    echo "       dpkg -V labbackup（台帳と違うファイル）:"
    printf '%s\n' "$ver" | sed 's/^/       │ /'
  else
    echo "       dpkg -V labbackup = 何も出ない（どのファイルも台帳の記録のまま）"
  fi
fi
if [ -x /usr/bin/labbackup ]; then
  out=$(/usr/bin/labbackup 2>&1); rc=$?
  echo "       labbackup の出力 = $out（終了コード $rc）"
else
  out=""; rc=127
  echo "       /usr/bin/labbackup = 無い（labbackup と打っても見つからない）"
fi

ng=0
case "$st" in
  ii) ;;
  "") echo "       → labbackup が台帳に無い（消すのではなく、入れたときの状態に戻す）"; ng=1 ;;
  *)  echo "       → labbackup が ii になっていない（$st）"; ng=1 ;;
esac
[ -z "$ver" ] || { echo "       → 台帳の記録と違うファイルが残っている"; ng=1; }
[ "$rc" = 0 ] || { echo "       → labbackup が動かない"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       labbackup のファイルはすべて台帳の記録どおりで、コマンドも動いた"
exit 0
