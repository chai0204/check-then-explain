#!/usr/bin/env bash
# 演習 06 の判定。観測型（コマンドを実際に動かし、dpkg の台帳と apt の目録を見る）。
set -uo pipefail
command -v dpkg-query >/dev/null || { echo "前提不足: dpkg-query が見つかりません"; exit 2; }
command -v apt-cache  >/dev/null || { echo "前提不足: apt-cache が見つかりません"; exit 2; }

path=$(command -v labcalc 2>/dev/null)
echo "判定 : 観測型（labcalc を動かし、dpkg の台帳と apt の目録を見た）"
if [ -z "$path" ]; then
  echo "観測 : labcalc = コマンドとして見つからない"
  pol=$(apt-cache policy lab-mathtools 2>/dev/null | grep -c 'file:/srv/lab-tools')
  if [ "$pol" -ge 1 ]; then
    echo "       apt の目録には /srv/lab-tools の中身が載っている"
  else
    echo "       apt の目録に /srv/lab-tools の中身が載っていない"
  fi
  exit 1
fi

out=$(labcalc 2 3 2>&1)
owner=$(dpkg-query -S "$path" 2>/dev/null | head -1 | cut -d: -f1)
echo "観測 : labcalc = $path"
echo "       labcalc 2 3 の出力 = $out"
if [ -z "$owner" ]; then
  echo "       dpkg の台帳 = $path を持つパッケージが無い（手で置かれたファイル）"
  exit 1
fi
st=$(dpkg-query -W -f='${db:Status-Abbrev}' "$owner" 2>/dev/null | tr -d ' ')
pol=$(apt-cache policy "$owner" 2>/dev/null | grep -c 'file:/srv/lab-tools')
echo "       dpkg の台帳 = $owner（$st）"
if [ "$pol" -ge 1 ]; then
  echo "       apt の目録 = $owner を file:/srv/lab-tools から取れる"
else
  echo "       apt の目録 = $owner の取り先に /srv/lab-tools が無い"
fi

ng=0
[ "$out" = 5 ] || { echo "       → 2 と 3 を渡して 5 が返らない"; ng=1; }
[ "$st" = ii ] || { echo "       → $owner が ii（入っていて設定済み）になっていない"; ng=1; }
[ "$pol" -ge 1 ] || { echo "       → apt の目録に、/srv/lab-tools から取れる $owner が載っていない"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       labcalc は $owner のもので、apt は /srv/lab-tools から取れる"
exit 0
