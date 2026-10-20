#!/usr/bin/env bash
# 演習 02 の判定。観測型（dpkg の台帳に記録された、入っているパッケージの状態と分類（Section）を見る）。
# 未達のときも、どれが遊びのパッケージかは名指ししない（それを調べるのがこの演習なので）。
set -uo pipefail
command -v dpkg-query >/dev/null || { echo "前提不足: dpkg-query が見つかりません"; exit 2; }

# 台帳の状態（ii / rc など）。台帳に行が無ければ空
st() { dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null | tr -d ' '; }
installed() { case "$(st "$1")" in i?) return 0 ;; esac; return 1; }
# 入っている lab* のうち、分類が games のものの数
games=$(dpkg-query -W -f='${db:Status-Abbrev} ${Section}\n' 'lab*' 2>/dev/null | awk '$1 ~ /^i/ && $2 == "games"' | wc -l)

echo "判定 : 観測型（台帳で、lab で始まるパッケージの状態と分類（Section）を見た）"
echo "観測 : 入っていて、分類が games のパッケージ = ${games} 個"
for p in labbackup labsvc labsvc-common labweb labweb-data; do
  s=$(st "$p")
  printf '       %-14s の台帳 = %s\n' "$p" "${s:-行が無い}"
done

ng=0
[ "$games" = 0 ] || { echo "       → 分類（Section）が games のパッケージが、まだ入っている"; ng=1; }
for p in labbackup labsvc labsvc-common; do
  installed "$p" || { echo "       → $p は遊びのパッケージではないのに、消えている"; ng=1; }
done
# labweb は演習05 で跡形なく消す。その終わりの形（2つとも台帳に無く、設定ファイルも無い）なら数えない
if ! installed labweb || ! installed labweb-data; then
  if [ -z "$(st labweb)" ] && [ -z "$(st labweb-data)" ] && [ ! -e /etc/labweb.conf ]; then
    :
  else
    echo "       → labweb（と labweb-data）は遊びのパッケージではないのに、消えている"; ng=1
  fi
fi
[ "$ng" = 0 ] || exit 1

echo "       分類が games のパッケージは無くなり、ほかのパッケージは入ったまま"
exit 0
