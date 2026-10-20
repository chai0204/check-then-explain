#!/usr/bin/env bash
# 練習機を定義・起動する前に、外側（コンテナの lab ユーザ）で走る（vm が呼ぶ）。
# 追加のディスクと、抜き差しする USB メモリの定義を $VMDIR/extra/ に作る。
# 何度呼ばれてもよいように、無いものだけ作る（vm reset --yes で extra/ ごと消え、次の起動で作り直される）。
#
# ディスクは qcow2 で作る。中身が空のうちはホストのディスクをほとんど使わない（書いた分だけ増える）。
set -eu
X="$VMDIR/extra"
mkdir -p "$X"

disk() {  # disk 名前 大きさ
  [ -f "$X/$1.qcow2" ] || qemu-img create -q -f qcow2 "$X/$1.qcow2" "$2"
}
disk vdb 2G
disk vdc 1G
disk vdd 256M
disk vde 512M
disk sda 1G
disk usb-a 64M
disk usb-b 64M
disk usb-check 16M

# USB メモリを挿すための定義。外で `virsh attach-device linuc ~/vm/extra/usb-a.xml` と打つと挿さり、
# `virsh detach-device linuc ~/vm/extra/usb-a.xml` で抜ける。
# target の dev は libvirt の中での呼び名で、練習機の中の名前（sdb など）とは関係ない。
# SATA の2台が sda / sdb を使っているので、USB は sdc 以降にする。
usb() {  # usb 名前 libvirt上の名前 シリアル
  [ -f "$X/$1.xml" ] && return 0
  cat > "$X/$1.xml" <<EOF
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2'/>
  <source file='$X/$1.qcow2'/>
  <target dev='$2' bus='usb' removable='on'/>
  <serial>$3</serial>
</disk>
EOF
}
usb usb-a sdc LAB-USB-A
usb usb-b sdd LAB-USB-B
# 演習10 の判定が使う。判定の中で一度だけ挿して、すぐ抜く
usb usb-check sde LAB-USB-CHECK
