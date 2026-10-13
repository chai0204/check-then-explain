#!/usr/bin/env bash
# 演習 05 の判定。観測型（消えているべきもの・残っているべきものを1つずつ見る）。
set -uo pipefail
W=/home/lab/work/05
# lab start 05 が ~/work/05 を作って配る。ディレクトリごと無いときだけ前提不足とする
# （中身が消えているのは読者の操作の結果なので、判定の対象にする）。
[ -d "$W" ] || { echo "前提不足: $W がありません（lab start 05 で配られます）"; exit 2; }

# 消えているべきもの: 名前が .tmp で終わり、1024 バイトより大きい通常ファイル
gone=(f.tmp cache/a.tmp cache/deep/c.tmp cache/deep/.e.tmp)
# 残っているべきもの
keep=(g.TMP cache/b.tmp cache/keep.txt cache/deep/d.tmp cache/big.tmp/inner.txt)

echo "判定 : 観測型（消えているべきもの ${#gone[@]} 個・残っているべきもの ${#keep[@]} 個を1つずつ見た）"
echo "観測 :"
ng=0
for f in "${gone[@]}"; do
  if [ -e "$W/$f" ]; then
    printf '         残っている  %-24s %s バイト\n' "$f" "$(stat -c %s "$W/$f")"
    echo "       → $f が消えていない"; ng=1
  else
    printf '         消えた      %s\n' "$f"
  fi
done
for f in "${keep[@]}"; do
  if [ -e "$W/$f" ]; then
    printf '         残っている  %-24s %s バイト\n' "$f" "$(stat -c %s "$W/$f")"
  else
    printf '         消えた      %s\n' "$f"
    echo "       → $f は条件に当てはまらないのに消えている"; ng=1
  fi
done
if [ -d "$W/cache/big.tmp" ]; then
  echo "         残っている  cache/big.tmp/（ディレクトリ）"
else
  echo "         消えた      cache/big.tmp/（ディレクトリ）"
  echo "       → ディレクトリ cache/big.tmp が消えている（消すのはファイルだけ）"; ng=1
fi
[ "$ng" = 0 ] || exit 1
echo "       1024 バイトより大きい .tmp ファイルだけが、深さ・隠しファイルに関係なく消えた"
echo "       → -type f・-name \"*.tmp\"・-size +1k の3条件が、どれも効いている"
exit 0
