#!/usr/bin/env bash
# 演習 06 の判定。観測型（アーカイブを実際に検査・展開し、元のディレクトリと比べる）。
set -uo pipefail
W=/home/lab/work/06
A=$W/project.tar.xz
[ -d "$W/project" ] || { echo "前提不足: $W/project がありません（lab start 06 で配られます）"; exit 2; }

echo "判定 : 観測型（アーカイブを実際に検査・展開して、元の project/ と比べた）"
if [ ! -f "$A" ]; then
  echo "観測 : $A が無い"
  exit 1
fi
echo "観測 : file の判定 = $(file -b "$A" | cut -d, -f1)"
if ! xz -t "$A" 2>/dev/null; then
  echo "       → xz として展開できない"
  exit 1
fi
mapfile -t ent < <(tar -tJf "$A" 2>/dev/null)
echo "       中の項目 ${#ent[@]} 個（先頭 ${ent[0]:-なし}）"
# ./project/... も展開すれば同じ場所に出るので認める
bad=$(printf '%s\n' "${ent[@]}" | grep -v -E '^(\./)?project(/|$)' | head -3 | tr '\n' ' ')
if [ -n "$bad" ]; then
  echo "       → project/ で始まらないパスがある: $bad"
  exit 1
fi
tmp=$(mktemp -d)
tar -xJf "$A" -C "$tmp" 2>/dev/null
if diff -r "$W/project" "$tmp/project" >/dev/null 2>&1; then same=1; else same=0; fi
rm -rf "$tmp"
if [ "$same" != 1 ]; then
  echo "       → 展開した中身が、いまの project/ と一致しない"
  exit 1
fi
echo "       xz として壊れておらず、展開すると project/ と同じ中身が出てくる"
echo "       → tar が束ね、xz が縮めた。中のパスは tar に渡した project のまま"
exit 0
