#!/usr/bin/env bash
# 演習 05 の判定。観測型（3つのファイルに、どちらの出力の行が、どの順で入ったかを読む）。
#   check.sh は OK を標準出力、NG を標準エラー出力に出す。行の中身でどちらから来たかが分かる。
set -uo pipefail
dir="$HOME/work/05"
[ -d "$dir" ] || { echo "前提不足: ~/work/05 がありません。先に lab start 05 を打ってください"; exit 2; }

ok_want=$'OK: disk\nOK: network\nOK: clock'
ng_want=$'NG: memory\nNG: cpu'
all_want=$'OK: disk\nNG: memory\nOK: network\nNG: cpu\nOK: clock'

show() {  # show NAME
  local f="$dir/$1"
  if [ ! -f "$f" ]; then printf '       %-8s= 存在しない\n' "$1"; return; fi
  printf '       %-8s= %s 行（OK %s 行 / NG %s 行）: %s\n' "$1" \
    "$(grep -c '' "$f")" "$(grep -c '^OK:' "$f")" "$(grep -c '^NG:' "$f")" \
    "$(paste -sd'|' "$f")"
}
echo "判定 : 観測型（ok.log / ng.log / all.log の中身と行の順番を読んだ）"
echo "観測 :"
show ok.log; show ng.log; show all.log

ng=0
[ "$(cat "$dir/ok.log" 2>/dev/null)" = "$ok_want" ]   || { echo "       → ok.log が「標準出力の3行だけ」になっていない"; ng=1; }
[ "$(cat "$dir/ng.log" 2>/dev/null)" = "$ng_want" ]   || { echo "       → ng.log が「標準エラー出力の2行だけ」になっていない"; ng=1; }
[ "$(cat "$dir/all.log" 2>/dev/null)" = "$all_want" ] || { echo "       → all.log が「5行すべてを画面と同じ順で」になっていない"; ng=1; }
[ "$ng" = 0 ] || exit 1
echo "       標準出力と標準エラー出力が、それぞれの行き先に分かれて入っている"
exit 0
