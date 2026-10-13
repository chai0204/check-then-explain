#!/usr/bin/env bash
# 演習 04 の判定。観測型（/dev/vdb の表を sfdisk の JSON で読み、課題の設計と1行ずつ比べる）。
# 大きさは ±1MiB まで許す（道具によって終わりの位置の丸め方が少し違うため）。
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }
js=$(lab-guest 'sfdisk -J /dev/vdb 2>/dev/null' 2>/dev/null)

ESP=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
LINUX=0FC63DAF-8483-4772-8E79-3D69D8477DE4
SWAP=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
name() { case "${1^^}" in $ESP) echo "EFI System";; $LINUX) echo "Linux filesystem";;
         $SWAP) echo "Linux swap";; "") echo "（種類なし）";; *) echo "$1";; esac; }
# 番号 種類 大きさ(MiB、0 は「残り全部」で 370MiB 以上)
want=( "1 $ESP 100" "2 $LINUX 300" "3 $SWAP 256" "4 $LINUX 600" "5 $LINUX 400" "6 $LINUX 0" )

echo "判定 : 観測型（/dev/vdb の表を読み、課題の6行と1行ずつ比べた）"
label=$(jq -r '.partitiontable.label // empty' <<<"$js" 2>/dev/null)
if [ -z "$label" ]; then
  echo "観測 : /dev/vdb に表が無い"
  exit 1
fi
echo "観測 : 表の形式 = $label（パーティション $(jq '.partitiontable.partitions | length' <<<"$js") 個）"
jq -r '.partitiontable.partitions[] | "\(.node) \(.size) \(.type)"' <<<"$js" |
while read -r node size type; do
  printf '       %-10s %5s MiB  %s\n' "${node#/dev/}" "$((size / 2048))" "$(name "$type")"
done

ng=0
[ "$label" = gpt ] || { echo "       → 表の形式が gpt ではない"; ng=1; }
for w in "${want[@]}"; do
  read -r n t mib <<<"$w"
  row=$(jq -r --arg n "/dev/vdb$n" '.partitiontable.partitions[] | select(.node==$n) | "\(.size) \(.type)"' <<<"$js")
  if [ -z "$row" ]; then echo "       → vdb$n が無い"; ng=1; continue; fi
  read -r size type <<<"$row"
  if [ "${type^^}" != "$t" ]; then
    echo "       → vdb$n の種類が $(name "$type")（課題の表では $(name "$t")）"; ng=1
  fi
  if [ "$mib" = 0 ]; then
    [ "$size" -ge $((370 * 2048)) ] || { echo "       → vdb$n が $((size / 2048))MiB しかない（残り全部のはず）"; ng=1; }
  else
    d=$(( size - mib * 2048 )); [ "$d" -lt 0 ] && d=$(( -d ))
    [ "$d" -le 2048 ] || { echo "       → vdb$n が $((size / 2048))MiB（課題の表では ${mib}MiB）"; ng=1; }
  fi
done
[ "$ng" = 0 ] || exit 1
echo "       GPT に6つ、種類と大きさが課題の表どおりに並んでいる"
echo "       → ESP の印（EF00）を付けた区画ができた。中身（FAT）は演習06 で作る"
exit 0
