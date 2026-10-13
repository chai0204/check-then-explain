#!/usr/bin/env bash
# 演習 06 の判定。観測型（~/work/06 に残っているファイルを数える）。
#   消えるべきもの = 名前が .tmp で終わるファイル、残るべきもの = それ以外（配った一覧から作る）。
set -uo pipefail
dir="$HOME/work/06"
seed=/lab/seed/06
[ -d "$seed" ] || { echo "前提不足: $seed がありません（イメージが壊れている）"; exit 2; }
[ -d "$dir" ] || { echo "前提不足: ~/work/06 がありません。先に lab start 06 を打ってください"; exit 2; }

cd "$dir" || exit 2
left=$(find . -type f -name '*.tmp' | sort)
nleft=$(printf '%s' "$left" | grep -c '')
mapfile -t keep < <(cd "$seed" && find . -type f ! -name '*.tmp' | sort)
missing=()
for f in "${keep[@]}"; do [ -f "$f" ] || missing+=("$f"); done

echo "判定 : 観測型（~/work/06 の下に残っているファイルを数えた）"
echo "観測 : 残っている .tmp ファイル = ${nleft} 個"
[ "$nleft" -gt 0 ] && printf '%s\n' "$left" | sed 's/^/         /'
echo "       残すべきファイル ${#keep[@]} 個のうち、無くなったもの = ${#missing[@]} 個"
[ "${#missing[@]}" -gt 0 ] && printf '         %s\n' "${missing[@]}"

[ "$nleft" -eq 0 ] && [ "${#missing[@]}" -eq 0 ] || exit 1
echo "       .tmp だけが、名前の空白に関係なくすべて消え、ほかは残っている"
exit 0
