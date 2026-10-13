#!/usr/bin/env bash
# 演習 07 の判定。観測型（current が何で、どこに辿り着き、何が読めるかを見る）。
set -uo pipefail
W=/home/lab/work/07
C=$W/current
[ -d "$W/releases/v2" ] || { echo "前提不足: $W/releases がありません（lab start 07 で配られます）"; exit 2; }

if   [ -L "$C" ]; then kind="シンボリックリンク（中身 = $(readlink "$C")）"
elif [ -d "$C" ]; then kind="ディレクトリ（リンクではない）"
elif [ -e "$C" ]; then kind="通常ファイル"
else                   kind="存在しない"
fi
ver=$(cat "$C/VERSION" 2>/dev/null || echo 読めない)
dest=$(readlink -f "$C" 2>/dev/null || echo -)
stray=$(cd "$W" && find releases -type l -printf '%p -> %l\n' 2>/dev/null | sort)

echo "判定 : 観測型（current が何で、どこに辿り着き、何が読めるかを見た）"
echo "観測 : current         = $kind"
echo "       辿り着く先      = $dest"
echo "       current/VERSION = $ver"
if [ -n "$stray" ]; then
  echo "       releases/ の中のリンク:"
  printf '%s\n' "$stray" | sed 's/^/         /'
fi

ng=0
[ -L "$C" ]                        || { echo "       → current がシンボリックリンクではない"; ng=1; }
[ "$dest" = "$W/releases/v2" ]     || { echo "       → current の行き先が releases/v2 ではない"; ng=1; }
[ -z "$stray" ]                    || { echo "       → releases/ の中にリンクができている"; ng=1; }
[ -f "$W/releases/v1/VERSION" ] && [ -f "$W/releases/v2/VERSION" ] \
                                   || { echo "       → releases/v1 か v2 の VERSION が無い"; ng=1; }
[ "$ng" = 0 ] || exit 1
echo "       current はリンクのまま、行き先だけが releases/v2 に変わった"
echo "       → リンクは「道順を書いた別のファイル」。付け替えても版の中身には触れない"
exit 0
