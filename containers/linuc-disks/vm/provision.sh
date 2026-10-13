#!/usr/bin/env bash
# 初回の起動で1回だけ、練習機の中で root として走る（vm が qemu-guest-agent 経由で流す）。
# 演習03 の「パーティションを1つ消してしまったディスク」（/dev/vdd）を作る。
#
#   消す前:  vdd1  2048〜206847（100MiB） ext4 ラベル OLDDATA … 取り戻したいファイルがある
#            vdd2  206848〜411647（100MiB） ext4 ラベル KEEP
#   消した後: 表から vdd1 の行だけを消す。中身（ext4 の構造とファイル）はディスク上にそのまま残る。
#
# UUID と表の識別子は固定値にする（読者全員の画面と、判定が見る値を揃えるため）。
set -euo pipefail
D=/dev/vdd
[ -b "$D" ] || { echo "provision: $D がありません（domain.xml.in の vdd を確認）" >&2; exit 1; }

# すでに準備済みなら何もしない（provision はふつう1回しか呼ばれないが、念のため）
if blkid -p -n ext4 -o value -s LABEL "${D}2" 2>/dev/null | grep -qx KEEP; then
  echo "provision: $D は準備済み"; exit 0
fi

wipefs -aq "$D"
sfdisk -q "$D" <<'EOF'
label: dos
label-id: 0x4c696e75
unit: sectors

start=2048, size=204800, type=83
start=206848, size=204800, type=83
EOF
udevadm settle

mkfs.ext4 -q -F -L OLDDATA -U 7a1e0c5e-0105-4d15-a5e5-0123456789ab "${D}1"
mkfs.ext4 -q -F -L KEEP    -U 7a1e0c5e-0105-4d15-a5e5-0123456789cd "${D}2"

m=$(mktemp -d)
mount "${D}1" "$m"
printf '%s\n' '合言葉: やまびこ' '（このファイルは /dev/vdd1 の中にありました）' > "$m/aikotoba.txt"
umount "$m"
mount "${D}2" "$m"
printf '%s\n' 'このディスクには、もう1つパーティションがありました。' > "$m/README.txt"
umount "$m"
rmdir "$m"

# 消す前の表を、student が読める場所に残す（「消す前に sfdisk -d で保存しておいた」という設定）
sfdisk -d "$D" > /home/student/vdd-before.txt
chown student:student /home/student/vdd-before.txt
chmod 644 /home/student/vdd-before.txt

# 表から1行だけ消す。中身には触らない
sfdisk -q --delete "$D" 1
udevadm settle
echo "provision: $D を準備しました"
