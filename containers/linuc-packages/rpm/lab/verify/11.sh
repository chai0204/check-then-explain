#!/usr/bin/env bash
# 演習 11 の判定。観測型（rpm の台帳と照らし合わせた結果と、labmotd を動かした結果を見る）。
set -uo pipefail
command -v rpm >/dev/null || { echo "前提不足: rpm が見つかりません"; exit 2; }
rpm -q labmotd >/dev/null 2>&1 || {
  echo "前提不足: labmotd が rpm の台帳にありません（消した場合は sudo yum install labmotd で戻せます）"
  exit 2; }

want='今日のひとこと: 台帳と照らし合わせれば、変わったファイルが分かる。'
ver=$(rpm -V labmotd 2>&1); vrc=$?
bin=/usr/bin/labmotd
if [ -x "$bin" ]; then
  out=$("$bin" 2>&1); orc=$?
  run="$out（終了コード $orc）"
else
  out=""; orc=126
  run="実行できない（$bin の権限 $(stat -c %a "$bin" 2>/dev/null || echo 不明)）"
fi

echo "判定 : 観測型（rpm -V labmotd の結果と、labmotd を動かした結果を見た）"
echo "観測 : rpm -V labmotd の終了コード = $vrc"
if [ -n "$ver" ]; then
  printf '%s\n' "$ver" | sed 's/^/       │ /'
else
  echo "       （台帳と違うファイルは無い）"
fi
echo "       labmotd = $run"

ng=0
{ [ "$vrc" = 0 ] && [ -z "$ver" ]; } || { echo "       → 台帳と違うファイルが残っている"; ng=1; }
[ "$orc" = 0 ] || { echo "       → labmotd が動かない"; ng=1; }
[ "$orc" != 0 ] || [ "$out" = "$want" ] || { echo "       → 出力がパッケージに入っていた1行と違う"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       labmotd のファイルはすべて台帳どおりで、パッケージの1行を出した"
exit 0
