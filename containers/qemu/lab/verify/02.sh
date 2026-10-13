#!/usr/bin/env bash
# 演習 02 の判定。観測型（~/work/02/linuc.qcow2 を qemu-img で調べる。土台は何か・書き込みがあるか・いま使われているか。
# それと、練習機を正しく止めたかを、ディスクの中の / の ext4 の印で見る）。
#   ext4 は、書き込める形で使っているあいだ superblock の needs_recovery（s_feature_incompat の 0x4）を立て、
#   正しく止まるとき（読み取り専用にし直す・外す）に下ろす。quit で電源を抜くと、立ったまま残る。
#   GPT の1番目の区画（練習機の /）の superblock を qemu-io で読む（-r で読むだけ、-U で使用中でも読む）。
set -uo pipefail
command -v qemu-img >/dev/null && command -v qemu-io >/dev/null && command -v jq >/dev/null || { echo "前提不足: qemu-img・qemu-io・jq のどれかが見つかりません"; exit 2; }
BASE=/var/lib/lab-vm/linuc-guest.qcow2
f=$HOME/work/02/linuc.qcow2

echo "判定 : 観測型（~/work/02/linuc.qcow2 を qemu-img info で読み、中の / の ext4 の印を qemu-io で読み、土台の指紋を測り直した）"
if [ ! -f "$f" ]; then
  echo "観測 : ~/work/02/linuc.qcow2 が無い"
  exit 1
fi
# -U: 使用中でも読む（使用中かどうかは、後で -U 無しで開けるかで別に見る）
info=$(qemu-img info -U --output=json "$f" 2>&1) || { echo "観測 : qemu-img info が読めない: $info"; exit 1; }
fmt=$(jq -r '.format' <<<"$info")
vsize=$(jq -r '."virtual-size"' <<<"$info")
actual=$(jq -r '."actual-size" // 0' <<<"$info")
back=$(jq -r '."full-backing-filename" // ."backing-filename" // ""' <<<"$info")
bfmt=$(jq -r '."backing-filename-format" // ""' <<<"$info")
inuse=no
qemu-img info "$f" >/dev/null 2>&1 || inuse=yes
# qcow2 の中の番地 $1 から $2 バイトを、16 進のバイトの並びで返す
rd() { qemu-io -r -U -f qcow2 -c "read -v $1 $2" "$f" 2>/dev/null | awk '/^[0-9a-f]+:/{for(i=2;i<=17;i++) printf "%s ", $i}'; }
le() { local s=0 i=0 b; for b in $1; do s=$(( s + (16#$b << (8*i)) )); i=$((i+1)); done; echo $s; }
recover=unknown
hdr=$(rd 512 96)
if [ "$(cut -d' ' -f1-8 <<<"$hdr")" = "45 46 49 20 50 41 52 54" ]; then          # "EFI PART"（GPT の見出し）
  ent=$(rd $(( $(le "$(cut -d' ' -f73-80 <<<"$hdr")") * 512 )) 128)                # 区画の表の1番目
  first=$(le "$(cut -d' ' -f33-40 <<<"$ent")")
  sb=$(rd $(( first * 512 + 1024 )) 128)                                           # ext4 の superblock
  if [ "$(cut -d' ' -f57-58 <<<"$sb")" = "53 ef" ]; then
    inc=$(le "$(cut -d' ' -f97-100 <<<"$sb")")
    if (( inc & 4 )); then recover=yes; else recover=no; fi
  fi
fi
sum=$(sha256sum "$BASE" | cut -d' ' -f1)
want=$(cut -d' ' -f1 /var/lib/lab-vm/linuc-guest.sha256)

echo "観測 : 形式 → $fmt / 練習機から見た大きさ → $vsize バイト"
echo "       土台（backing file）→ ${back:-なし}${bfmt:+（$bfmt）}"
echo "       ファイルが実際に使っている量 → $((actual / 1024)) KiB"
echo "       いま QEMU に開かれているか → $([ "$inuse" = yes ] && echo 開かれている || echo 開かれていない)"
echo "       練習機の / の ext4 の needs_recovery → $(case $recover in yes) echo "立っている（使用中か、電源を抜かれて止まった）";; no) echo "立っていない（正しく止まった）";; *) echo "読めない";; esac)"
echo "       土台の sha256 → $([ "$sum" = "$want" ] && echo "配った時と同じ" || echo "配った時と違う")"

ng=0
[ "$fmt" = qcow2 ] || { echo "       → qcow2 ではない"; ng=1; }
if [ -z "$back" ]; then
  echo "       → 土台（backing file）が無い。写しか、空のディスクになっている"; ng=1
elif [ "$back" != "$BASE" ]; then
  echo "       → 土台が $BASE ではない"; ng=1
fi
[ "$vsize" = 21474836480 ] || { echo "       → 練習機から見た大きさが 20GiB ではない"; ng=1; }
if [ "$actual" -lt $((4 * 1024 * 1024)) ]; then
  echo "       → 書き込みがほとんど無い（4 MiB 未満）。まだ一度も練習機が起動し終わっていない"; ng=1
fi
[ "$inuse" = no ] || { echo "       → まだ QEMU が開いている（練習機が止まっていない）"; ng=1; }
if [ "$inuse" = no ] && [ "$recover" = yes ]; then
  echo "       → 練習機の / が後片付けをしないまま止まっている（quit で電源を抜いた）。もう一度起動して、system_powerdown で止める"; ng=1
fi
[ "$recover" != unknown ] || { echo "       → 練習機の / のファイルシステムが読めない（ディスクの中身が練習機のものではない）"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       土台の上に重ねた差分に、起動のあいだの書き込みだけが入っている。土台は変わっていない"
echo "       → 練習機は後片付けをしてから止まった（/ の ext4 に「回復が要る」の印が残っていない）"
exit 0
