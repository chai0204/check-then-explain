#!/usr/bin/env bash
# 演習 07 の判定。観測型（hits.txt の各行が、配ったログの何行目でレベル欄が何かを調べる）。
#   正解は awk の欄比較（$3 が ERROR か WARN）で作る。読者の正規表現とは別の方法で決めるため。
set -uo pipefail
src=/lab/seed/07/server.log
hits="$HOME/work/07/hits.txt"
[ -f "$src" ] || { echo "前提不足: $src がありません（イメージが壊れている）"; exit 2; }
[ -d "$HOME/work/07" ] || { echo "前提不足: ~/work/07 がありません。先に lab start 07 を打ってください"; exit 2; }

echo "判定 : 観測型（hits.txt の各行を配ったログと突き合わせ、レベル欄を調べた）"
[ -f "$hits" ] || { echo "観測 : ~/work/07/hits.txt が存在しない"; exit 1; }

want=$(awk '$3=="ERROR"||$3=="WARN"' "$src")
nwant=$(printf '%s\n' "$want" | grep -c '')
ngot=$(grep -c '' "$hits")
echo "観測 : hits.txt の行数 = ${ngot}（レベル欄が ERROR か WARN の行はログに ${nwant} 行）"

ng=0
while IFS= read -r l; do
  no=$(grep -nxF -- "$l" "$src" | head -1 | cut -d: -f1)
  if [ -z "$no" ]; then
    echo "       「$l」: 配ったログに無い行"; ng=1; continue
  fi
  lv=$(printf '%s\n' "$l" | awk '{print $3}')
  case $lv in
    ERROR|WARN) ;;
    *) echo "       ${no}行目が入っている: レベル欄は ${lv}"; ng=1 ;;
  esac
done < "$hits"
while IFS= read -r l; do
  grep -qxF -- "$l" "$hits" || { echo "       $(grep -nxF -- "$l" "$src" | cut -d: -f1)行目（レベル欄 $(printf '%s' "$l" | awk '{print $3}')）が入っていない"; ng=1; }
done <<< "$want"
if [ "$ng" = 0 ] && [ "$(cat "$hits")" != "$want" ]; then
  echo "       → 行はそろっているが、順番か重複が元のログと違う"; ng=1
fi
[ "$ng" = 0 ] || exit 1
echo "       レベル欄が ERROR か WARN の行だけが、元の順で入っている"
exit 0
