#!/usr/bin/env bash
# 演習 01 の判定。観測型（dpkg の台帳の状態と、設定ファイルの有無を見る）。
set -uo pipefail
command -v dpkg-query >/dev/null || { echo "前提不足: dpkg-query が見つかりません"; exit 2; }

# 台帳の状態（ii / rc / iU など）。台帳に行が無ければ空
st() { dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null | tr -d ' '; }
s_svc=$(st labsvc)
s_com=$(st labsvc-common)
conf=無い; [ -e /etc/labsvc.conf ] && conf=在る

echo "判定 : 観測型（dpkg の台帳の状態と、設定ファイルの有無を見た）"
echo "観測 : labsvc        の台帳 = ${s_svc:-行が無い}"
echo "       labsvc-common の台帳 = ${s_com:-行が無い}"
echo "       /etc/labsvc.conf     = $conf"

ng=0
case "$s_svc" in
  ""|un|pn) ;;
  rc) echo "       → labsvc の行が rc（設定ファイルだけ残っている）で台帳に残っている"; ng=1 ;;
  *)  echo "       → labsvc がまだ台帳にある（$s_svc）"; ng=1 ;;
esac
[ "$conf" = 在る ] && { echo "       → /etc/labsvc.conf が残っている"; ng=1; }
case "$s_com" in
  ""|un|pn) ;;
  *) echo "       → labsvc-common が残っている（$s_com）"; ng=1 ;;
esac
[ "$ng" = 0 ] || exit 1

echo "       labsvc は台帳にも /etc にも残っておらず、一緒に入った labsvc-common も消えている"
exit 0
