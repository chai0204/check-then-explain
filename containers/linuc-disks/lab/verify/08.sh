#!/usr/bin/env bash
# 演習 08 の判定。観測型（LVM の状態と、論理ボリュームの中の ext4 の大きさを直接読む）。
# 「箱（LV）の大きさ」と「中身（ファイルシステム）の大きさ」を別々に測って比べる。マウントの有無は問わない。
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }

pvs=$(lab-guest 'pvs --noheadings -o pv_name,vg_name 2>/dev/null' 2>/dev/null)
lv=$(lab-guest 'lvs --noheadings --units b --nosuffix -o lv_size vg0/data 2>/dev/null' 2>/dev/null | tr -d ' ')
devs=$(lab-guest 'lvs --noheadings -o devices vg0/data 2>/dev/null' 2>/dev/null | tr -d ' ' | tr '\n' ',')
# 中の ext4 を読むには、論理ボリュームが動いて（活性になって）いる必要がある。止まっていたら、読んだあと止め直す
act=$(lab-guest 'lvs --noheadings -o lv_active vg0/data 2>/dev/null' 2>/dev/null | tr -d ' ')
fsinfo=$(lab-guest 'lvchange -ay vg0/data >/dev/null 2>&1; tune2fs -l /dev/vg0/data 2>/dev/null' 2>/dev/null)
[ -n "$lv" ] && [ "$act" != active ] && lab-guest 'lvchange -an vg0/data' >/dev/null 2>&1
bc=$(sed -nE 's/^Block count: *([0-9]+)$/\1/p' <<<"$fsinfo")
bs=$(sed -nE 's/^Block size: *([0-9]+)$/\1/p' <<<"$fsinfo")
fsb=$(( ${bc:-0} * ${bs:-0} ))
mib() { echo $(( $1 / 1048576 )); }

# 物理ボリュームは、ディスクそのもの（/dev/vdc）でも、その区画（/dev/vdc1。第3章の種類 8e）でもよい
in_vg() { awk -v d="$1" '($1==d || $1 ~ ("^" d "[0-9]+$")) && $2=="vg0"{f=1} END{exit !f}' <<<"$pvs"; }
echo "判定 : 観測型（LVM の表と、vg0/data の中の ext4 の大きさを別々に読んで比べた）"
pvlist=$(awk '$2=="vg0"{print $1}' <<<"$pvs" | paste -sd ' ')
echo "観測 : vg0 の物理ボリューム = ${pvlist:-（無い。ボリュームグループ vg0 がまだ無い）}"
if [ -z "$lv" ]; then
  echo "       論理ボリューム vg0/data が無い"
  exit 1
fi
echo "       vg0/data の大きさ     = $(mib "$lv") MiB（使っている物理ボリューム: ${devs%,}）"
if [ "$fsb" -gt 0 ]; then
  echo "       中の ext4 の大きさ    = $(mib "$fsb") MiB"
else
  echo "       中の ext4 の大きさ    = （ext4 が見つからない）"
fi

ng=0
in_vg /dev/vdc || { echo "       → /dev/vdc（かその区画）が vg0 に入っていない"; ng=1; }
in_vg /dev/sda || { echo "       → /dev/sda（かその区画）が vg0 に入っていない"; ng=1; }
[ "$lv" -gt 1073741824 ] || { echo "       → vg0/data が 1GiB を超えていない（どちらか1台に収まる大きさ）"; ng=1; }
case "$devs" in *vdc*sda*|*sda*vdc*) ;; *) echo "       → vg0/data が2台にまたがっていない"; ng=1;; esac
if [ "$fsb" -le 0 ]; then ng=1
elif [ $(( fsb * 100 )) -lt $(( lv * 99 )) ]; then
  echo "       → 箱（LV）は $(mib "$lv") MiB なのに、中身（ext4）は $(mib "$fsb") MiB のまま"; ng=1
fi
[ "$ng" = 0 ] || exit 1
echo "       1台より大きな箱が2台にまたがってでき、中身の ext4 も箱いっぱいに広がっている"
echo "       → 箱と中身は別の段。広げるときは両方を広げる（lvextend -r か resize2fs）"
exit 0
