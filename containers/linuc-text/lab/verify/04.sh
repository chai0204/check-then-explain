#!/usr/bin/env bash
# 演習 04 の判定。観測型（書き換えた後の app.conf と、残した app.conf.bak の中身を読む）。
set -uo pipefail
dir="$HOME/work/04"
orig=/lab/seed/04/app.conf
[ -f "$orig" ] || { echo "前提不足: $orig がありません（イメージが壊れている）"; exit 2; }
[ -d "$dir" ] || { echo "前提不足: ~/work/04 がありません。先に lab start 04 を打ってください"; exit 2; }

conf="$dir/app.conf"; bak="$dir/app.conf.bak"
echo "判定 : 観測型（app.conf と app.conf.bak の中身を、配ったときの中身と比べた）"
[ -f "$conf" ] || { echo "観測 : app.conf が存在しない"; exit 1; }

ng=0
j() { paste -sd' ' -; }   # 複数行を空白1つでつなぐ
port=$(grep -E '^port=' "$conf" | j)
admin=$(grep -E '^port_admin=' "$conf" | j)
url=$(grep -E '^url=' "$conf" | j)
ncomment=$(grep -c '^#' "$conf")
others=$(grep -vE '^(port|port_admin|url)=|^#' "$conf" | j)
echo "観測 : port の行       = ${port:-（無い）}"
echo "       port_admin の行 = ${admin:-（無い）}"
echo "       url の行        = ${url:-（無い）}"
echo "       # で始まる行    = ${ncomment} 行"
echo "       その他の行      = ${others:-（無い）}"
[ "$port" = "port=9090" ]                        || { echo "       → port の行が port=9090 の1行になっていない"; ng=1; }
[ "$admin" = "port_admin=8081" ]                 || { echo "       → port_admin の行が配ったときと違う"; ng=1; }
[ "$url" = "url=http://localhost:8080/health" ]  || { echo "       → url の行が配ったときと違う"; ng=1; }
[ "$ncomment" -eq 0 ]                             || { echo "       → コメント行が残っている"; ng=1; }
[ "$others" = "host=localhost log_level=info" ]  || { echo "       → 設定の行が足りないか、増えている"; ng=1; }

if [ ! -f "$bak" ]; then
  echo "       app.conf.bak    = 存在しない"
  ng=1
elif cmp -s "$bak" "$orig"; then
  echo "       app.conf.bak    = 配ったときの app.conf と同じ中身"
else
  echo "       app.conf.bak    = 配ったときの app.conf と違う（$(diff "$orig" "$bak" | grep -c '^[<>]') 行の差）"
  ng=1
fi
[ "$ng" = 0 ] || exit 1
echo "       port だけが 9090 になり、コメントが消え、元の中身が .bak に残っている"
exit 0
