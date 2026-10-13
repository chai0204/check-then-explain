#!/bin/bash
# LinuC 主題1.05（ハードウェア・ディスク・パーティション・ファイルシステム）理論編 第1〜8章の端末表示の出どころ。
#
# 章本文の `$ ` 行を、本文と同じ順序・同じ文字で1行ずつ打つ。読者は第1章から順に同じ練習機で打っていくので、
# 状態（パーティション・ファイルシステム・/etc/fstab・読み込まれたモジュール）は章をまたいで持ち越される。
# ここに出ない出力は本文に書かない。
#
# 走らせ方（読者の起動コマンドと同じオプション。名前とボリューム名だけ probe 用。KVM なし）:
#   docker run -d --name linuc-disks-probe --hostname host --stop-timeout 30 \
#     -v linuc-disks-probe-vm:/home/lab/vm -v linuc-disks-probe-state:/home/lab/.lab lab-linuc-disks:1.0.0
#   docker exec linuc-disks-probe vm start            # 起動と初回の準備（provision.sh）を待つ
#   docker cp probe/linuc-disks-probe.sh linuc-disks-probe:/tmp/probe.sh
#   docker exec -u lab -w /home/lab linuc-disks-probe bash -l /tmp/probe.sh > logs/linuc-disks-probe.log 2>&1
#   docker rm -f linuc-disks-probe
# 読者と同じ lab のログインシェル（bash -l）で打つ。tty は付けない（付けると色や列揃えが混ざる）。
#
# 記録の約束:
#   H  … 外（lab@host）で打つもの。コマンド行を `$ ` 付きで書いてから実行する。
#   G  … 練習機の中（student@linuc）で打つもの。記録には読者が打つ形（ssh linuc を付けない形）を書き、
#        実際には ssh linuc で、読者と同じ条件の端末（pty・TERM=xterm・幅 80 桁・対話のログインシェルで
#        ~/.bashrc の alias も効く）を作って流す。非対話の ssh では ls が1行1件になり、lsblk・findmnt の
#        見出しの折り返し（util-linux 2.39 が端末に出すときだけ起きる）も出ないため（2026-10-13 に実測して改めた）。
#        表の幅が端末の幅で変わらないよう、本文で使う lsblk・findmnt は 80 桁に収まる列だけを指定する。
#   T  … 端末が要る対話的なコマンド（fdisk / gdisk / fsck）。練習機の中で端末（pty）を作り、
#        キーを1行ずつ間を置いて送る。記録には読者の画面と同じく「プロンプト + 打った文字」が残る。
#        端末の幅は 200 桁にする（80 桁だと fdisk の長いプロンプトが readline の横スクロールで欠ける）。
#   W  … 読者が次の行を打つまでの間（秒）。記録には出さない。USB の抜き差しや再起動は、
#        練習機の中で処理が終わるまで数秒かかる（KVM なしの完全エミュレーション）。
#   S  … 章の区切り。記録の見出しで、本文には出ない。
# 出力の制御文字（色・カーソル移動・バックスペース）は取り除く。mke2fs の進捗表示はバックスペースで
# 数字を消しながら書くので、端末で見たときに残る文字だけを残す。
set -u
LAST=0
CLEAN='s/\x1b\[[0-9;?]*[A-Za-z]//g; s/\x1b\][^\x07]*\x07//g; s/\x1b[=>]//g; :a; s/[^\x08]\x08//; ta'
S() { printf '\n\n========== %s ==========\n' "$*"; }
H() {
  printf '\n$ %s\n' "$1"
  (exit "$LAST"); eval "$1" 2>&1
  LAST=$?
}
G() {
  printf '\n$ %s\n' "$1"
  ssh -q -tt linuc "stty cols 80 rows 24; export TERM=xterm; bash -lic $(printf %q "$1")" < /dev/null 2>&1 \
    | tr -d '\r' | sed -E "$CLEAN"
  LAST=${PIPESTATUS[0]}
}
T() {
  local cmd=$1; shift
  printf '\n$ %s\n' "$cmd"
  local feed="sleep 3" k
  for k in "$@"; do feed+="; printf '%s\\n' $(printf %q "$k"); sleep 1"; done
  ssh -q linuc "( $feed ) | TERM=xterm script -qfec $(printf %q "stty cols 200 rows 50; $cmd") /dev/null" 2>&1 \
    | tr -d '\r' | sed -E "$CLEAN"
  LAST=${PIPESTATUS[0]}
}
W() { sleep "$1"; }

S "0. 環境（検証環境ブロックの版の出どころ）"
H 'lab env'
H 'vm status'
H 'virsh list --all'
H 'virsh --version'
H 'qemu-system-x86_64 --version | head -1'
G 'uname -r'
G 'dpkg-query -W -f="\${Package} \${Version}\n" util-linux fdisk e2fsprogs xfsprogs btrfs-progs dosfstools gdisk parted lvm2 udev kmod usbutils pciutils efibootmgr'

S "0b. ログインしたときに出る表示（実践編の入口に載せる）"
H 'bash -lic exit 2>/dev/null'
printf '\n$ %s\n' 'ssh linuc'
(sleep 4; printf 'exit\n'; sleep 2) | script -qfec 'stty cols 200 rows 50; ssh linuc' /dev/null 2>&1 \
  | tr -d '\r' | sed -E "$CLEAN"
H 'lab'

S "第1章 HDD か SSD かは、装置の申告で決まる（1.05.1）"
G 'findmnt -t proc,sysfs,devtmpfs -o TARGET,SOURCE,FSTYPE'
G 'ls -l /proc/cpuinfo'
G 'grep -m1 "model name" /proc/cpuinfo'
G 'grep -c ^processor /proc/cpuinfo'
G 'head -3 /proc/meminfo'
G 'head -4 /proc/interrupts'
G 'head -5 /proc/ioports'
G 'sudo head -5 /proc/ioports'
G 'cat /proc/dma'
G 'cat /proc/partitions'
G 'ls /sys/block'
G 'cat /sys/block/vdb/size'
G 'ls -l /dev/vda /dev/sda /dev/sr0'
G 'lspci'
G 'lspci -k -s 00:1f.2'
G 'lspci -nn -s 03:00.0'
G 'lsusb'
G 'lsusb -t'
H 'virsh domblklist linuc'
G 'lsblk -d -o NAME,TRAN,ROTA,RM,RO,SIZE,MODEL'
H 'ls -l ~/vm/extra/*.qcow2'
H 'virsh dumpxml linuc | grep rotation_rate'
G 'cat /sys/block/sda/queue/rotational /sys/block/vdb/queue/rotational'
G 'echo 0 | sudo tee /sys/block/vdb/queue/rotational'
G 'lsblk -d -o NAME,ROTA /dev/vdb'
G 'sudo mount /dev/sr0 /mnt'
G 'cat /mnt/README.TXT'
G 'touch /mnt/test.txt'
G 'sudo umount /mnt'
H 'virsh change-media linuc sdb --eject'
W 3
G 'lsblk -d -o NAME,TYPE,RM,RO,SIZE /dev/sr0'
G 'sudo mount /dev/sr0 /mnt'
H 'virsh change-media linuc sdb /usr/share/lab-disks/linuc-media.iso --insert'
W 3
G 'lsblk -d -o NAME,TYPE,RM,RO,SIZE /dev/sr0'

S "第2章 ドライバは、外しても戻ってくる（1.05.1）"
G 'lsmod | head -5'
G 'lsmod | wc -l'
G 'grep -E "/(vfat|ext4|sr_mod)\.ko" /lib/modules/$(uname -r)/modules.builtin'
G 'lspci -k -s 00:1f.2'
G 'lsmod | grep ahci'
G 'sudo modprobe -r ahci'
W 3
G 'lsblk -d -o NAME,TRAN,SIZE'
G 'lspci -k -s 00:1f.2'
G 'sudo modprobe ahci'
W 5
G 'lsblk -d -o NAME,TRAN,SIZE'
G 'modinfo -F depends btrfs'
G 'sudo insmod /lib/modules/$(uname -r)/kernel/fs/btrfs/btrfs.ko.zst'
G 'sudo dmesg | tail -4'
G 'sudo modprobe -v btrfs'
G 'lsmod | grep -E "^(btrfs|xor|raid6_pq|libcrc32c|blake2b_generic) "'
G 'sudo modprobe -rv btrfs'
# USB メモリを挿す。udevadm monitor は読者が別の端末で打つ。記録では練習機の中で裏で走らせておき、
# 外で挿したあと、監視が終わってから出力を出す（打つコマンドは読者と同じ。timeout で 30 秒後に自分で終わる）
MON='sudo timeout 30 udevadm monitor --subsystem-match=usb --subsystem-match=block'
ssh -n linuc "sudo setsid timeout 30 udevadm monitor --subsystem-match=usb --subsystem-match=block > /tmp/udevmon.log 2>&1 < /dev/null &"
W 3
H 'virsh attach-device linuc ~/vm/extra/usb-a.xml'
W 30
printf '\n$ %s\n' "$MON"
ssh -n linuc 'cat /tmp/udevmon.log' 2>&1 | tr -d '\r'
G 'lsusb'
G 'lsusb -t'
G 'lsblk -d -o NAME,TRAN,ROTA,RM,SIZE,MODEL,SERIAL'
G 'lsmod | grep -E "usb_storage|uas"'
G 'sudo dmesg | tail -12'
G 'ls -l /dev/disk/by-id/ | grep usb'
G 'sudo modprobe -r usb_storage'
G 'sudo rmmod usb_storage'
G 'sudo modprobe -r uas'
G 'lsmod | grep -E "usb_storage|uas"'
G 'lsblk -d -o NAME,TRAN,SIZE,SERIAL'
G 'lsusb'
G 'lsusb -t'
H 'virsh detach-device linuc ~/vm/extra/usb-a.xml'
W 4
H 'virsh attach-device linuc ~/vm/extra/usb-a.xml'
W 10
G 'lsmod | grep -E "usb_storage|uas"'
G 'lsblk -d -o NAME,TRAN,SIZE,SERIAL'
G 'cat /sys/bus/usb/devices/2-1:1.0/modalias'
G 'modprobe --resolve-alias $(cat /sys/bus/usb/devices/2-1:1.0/modalias)'
G 'modinfo usb_storage | grep -m3 alias'
G 'grep -n "kmod load" /usr/lib/udev/rules.d/80-drivers.rules | head -1'
G 'ls /etc/modprobe.d/'
G 'cat /etc/modules'
# 止める（1回目）: blacklist を書いただけ
G 'echo "blacklist usb_storage" | sudo tee /etc/modprobe.d/lab-usb.conf'
G 'sudo modprobe -r uas'
H 'virsh detach-device linuc ~/vm/extra/usb-a.xml'
W 4
H 'virsh attach-device linuc ~/vm/extra/usb-a.xml'
W 10
G 'lsmod | grep -E "usb_storage|uas"'
# 止める（2回目）: udev に設定を読み直させる
G 'sudo systemctl restart systemd-udevd'
G 'sudo modprobe -r uas'
H 'virsh detach-device linuc ~/vm/extra/usb-a.xml'
W 4
H 'virsh attach-device linuc ~/vm/extra/usb-a.xml'
W 10
G 'lsmod | grep -E "usb_storage|uas"'
G 'modprobe --show-depends uas'
# 止める（3回目）: install で読み込みそのものを失敗させる
G 'echo "install usb_storage /bin/false" | sudo tee /etc/modprobe.d/lab-usb.conf'
G 'sudo systemctl restart systemd-udevd'
G 'sudo modprobe -r uas'
H 'virsh detach-device linuc ~/vm/extra/usb-a.xml'
W 4
H 'virsh attach-device linuc ~/vm/extra/usb-a.xml'
W 10
G 'lsmod | grep -E "usb_storage|uas"'
G 'lsusb -t'
G 'lsblk -d -o NAME,TRAN,SIZE,SERIAL'
G 'sudo modprobe usb_storage'
H 'virsh detach-device linuc ~/vm/extra/usb-a.xml'
W 4
G 'busctl list --no-pager | grep -E "^org\.freedesktop\.(systemd1|login1|hostname1|timedate1|network1)"'

S "第3章 パーティションの表は、目次にすぎない（1.05.2 / 1.05.3 MBR）"
G 'sudo fdisk -l /dev/vdb'
T 'sudo fdisk /dev/vdb' n p 1 '' +200M p w
G 'lsblk /dev/vdb'
G 'sudo mkfs.ext4 -q /dev/vdb1'
G 'sudo mount /dev/vdb1 /mnt'
G 'echo "まだここにある" | sudo tee /mnt/memo.txt'
G 'sudo umount /mnt'
T 'sudo fdisk /dev/vdb' d w
G 'lsblk /dev/vdb'
G 'sudo mount /dev/vdb1 /mnt'
T 'sudo fdisk /dev/vdb' n p 1 '' +200M N w
G 'sudo mount /dev/vdb1 /mnt'
G 'cat /mnt/memo.txt'
G 'sudo umount /mnt'
G 'sudo dd if=/dev/vdb bs=1 skip=446 count=66 status=none | od -A d -t x1'
T 'sudo fdisk /dev/vdb' n p 2 '' +100M n e 3 '' '' n '' +100M n '' +100M p w
G 'sudo fdisk -l /dev/vdb'
G 'sudo gdisk -l /dev/vdb'
G 'sudo parted /dev/vdb print'
G 'sudo parted /dev/vdb rm 6'
G 'sudo parted /dev/vdb print'
G 'sudo fdisk -l /dev/vdd'

S "第4章 起動の入口は、マウントしなくても見つかる（1.05.2）"
G 'lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,MOUNTPOINTS /dev/vda'
G 'cat /etc/fstab'
G 'df -h / /boot /boot/efi'
G 'swapon --show'
G 'free -h'
G 'ls /boot/efi'
G 'sudo ls -R /boot/efi/EFI'
G 'sudo efibootmgr'
G 'sudo blkid /dev/vda15 /dev/vda16'
G 'sudo cat /boot/efi/EFI/ubuntu/grub.cfg'
G 'sudo iconv -f UTF-16 -t UTF-8 /boot/efi/EFI/ubuntu/BOOTX64.CSV'
G 'sudo cp /etc/fstab /etc/fstab.bak'
G "sudo sed -i 's|^LABEL=UEFI|#&|' /etc/fstab"
G 'grep UEFI /etc/fstab'
G 'sudo reboot'
W 20
H 'vm start'
G 'findmnt -o TARGET,SOURCE,FSTYPE /boot/efi'
G 'ls -la /boot/efi'
G 'systemctl is-system-running'
G 'sudo efibootmgr | head -3'
G 'sudo cp /etc/fstab.bak /etc/fstab'
G 'sudo systemctl daemon-reload'
G 'sudo mount /boot/efi'
G 'findmnt -o TARGET,SOURCE,FSTYPE /boot/efi'
T 'sudo gdisk /dev/vdb' o Y n '' '' +100M ef00 n '' '' +300M 8300 n '' '' +256M 8200 n '' '' +600M 8300 n '' '' +400M 8300 n '' '' '' '' p w Y
G 'lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME /dev/vdb'
G 'sudo parted /dev/vdb print'

S "第5章 LV を広げても、ファイルシステムは広がらない（1.05.2）"
G 'lsblk -o NAME,SIZE,TYPE,TRAN /dev/vdc /dev/sda'
G 'sudo pvcreate /dev/vdc /dev/sda'
G 'sudo pvs'
G 'sudo vgcreate vg0 /dev/vdc /dev/sda'
G 'sudo vgs'
G 'sudo vgdisplay vg0'
G 'sudo lvcreate -L 600M -n data vg0'
G 'sudo lvs'
G 'ls -l /dev/vg0/data /dev/mapper/vg0-data'
G 'sudo mkfs.ext4 -q /dev/vg0/data'
G 'sudo mkdir -p /srv/data'
G 'sudo mount /dev/vg0/data /srv/data'
G 'df -h /srv/data'
G 'sudo lvextend -L +800M vg0/data'
G 'sudo lvs vg0/data'
G 'df -h /srv/data'
G 'sudo resize2fs /dev/vg0/data'
G 'df -h /srv/data'
G 'sudo lvs -o lv_name,lv_size,devices vg0'
G 'sudo lvextend -r -L +200M vg0/data'
G 'df -h /srv/data'
G 'sudo umount /srv/data'
G 'sudo lvreduce -r -L 1.2G vg0/data'
G 'sudo mount /dev/vg0/data /srv/data'
G 'df -h /srv/data'
G 'sudo lvcreate -L 300M -n logs vg0'
G 'sudo mkfs.xfs -q /dev/vg0/logs'
G 'sudo mkdir -p /srv/logs'
G 'sudo mount /dev/vg0/logs /srv/logs'
G 'sudo lvreduce -r -L 200M vg0/logs'
G 'sudo umount /srv/logs'
G 'sudo lvremove -y vg0/logs'
G 'echo "スナップショットの前" | sudo tee /srv/data/note.txt'
G 'sudo lvcreate -s -L 100M -n snap vg0/data'
G 'sudo lvs vg0'
G 'sudo rm /srv/data/note.txt'
G 'sudo dd if=/dev/urandom of=/srv/data/big bs=1M count=40 status=none; sync'
G 'sudo lvs vg0'
G 'sudo mkdir -p /mnt/snap'
G 'sudo mount -o ro /dev/vg0/snap /mnt/snap'
G 'ls /srv/data /mnt/snap'
G 'cat /mnt/snap/note.txt'
G 'sudo cp /mnt/snap/note.txt /srv/data/'
G 'sudo umount /mnt/snap'
G 'sudo lvremove -y vg0/snap'
G 'sudo rm /srv/data/big'
G 'sudo pvs'
G 'sudo lvs -o lv_name,lv_size,devices vg0'

S "第6章 ファイルシステムは、作った大きさより小さく見える（1.05.3）"
G 'ls /sbin/mkfs*'
G 'sudo wipefs /dev/vdb1'
G 'sudo mkfs.vfat -F 32 -n ESP /dev/vdb1'
G 'sudo wipefs /dev/vdb1'
G 'sudo mkfs -t ext3 -L BOOT /dev/vdb2'
G 'sudo mkfs.xfs -L ROOT /dev/vdb4'
G 'sudo mkfs.btrfs -L VAR /dev/vdb5'
G 'sudo mkfs.ext4 -L HOME /dev/vdb6'
G 'lsblk -o NAME,FSTYPE,LABEL,UUID /dev/vdb'
G 'sudo mount /dev/vdb6 /mnt'
G 'df -h /mnt'
G 'df -m /mnt'
G 'sudo tune2fs -l /dev/vdb6 | grep -E "^(Block count|Reserved block count|Block size|Reserved blocks uid)"'
G 'sudo tune2fs -m 1 /dev/vdb6'
G 'df -m /mnt'
G 'sudo umount /mnt'
G 'for p in 1 2 4 5 6; do sudo mount /dev/vdb$p /mnt && df -h --output=source,fstype,size,used,avail /mnt | tail -1; sudo umount /mnt; done'
G 'sudo dumpe2fs -h /dev/vdb2 2>/dev/null | grep -i features'
G 'sudo dumpe2fs -h /dev/vdb6 2>/dev/null | grep -i features'
T 'sudo fsck /dev/vdb6'
T 'sudo fsck -f /dev/vdb6'
G 'sudo fsck /dev/vdb4'
G 'sudo xfs_repair -n /dev/vdb4 2>&1 | tail -3'
G 'sudo fsck /dev/vdb5'

S "第7章 tmpfs は、メモリを先に取らない（1.05.3）"
G 'free -h'
G 'sudo mkswap -L SWAP /dev/vdb3'
G 'free -h'
G 'sudo swapon /dev/vdb3'
G 'swapon --show'
G 'cat /proc/swaps'
G 'swapon -s'
G 'free -h'
G 'sudo dd if=/dev/zero of=/swapfile bs=1M count=128 status=none'
G 'ls -l /swapfile'
G 'sudo mkswap /swapfile'
G 'sudo chmod 600 /swapfile'
G 'sudo swapon -p 10 /swapfile'
G 'swapon --show'
G 'sudo swapoff /swapfile'
G 'sudo rm /swapfile'
G 'echo "UUID=$(sudo blkid -s UUID -o value /dev/vdb3)  none  swap  sw  0  0" | sudo tee -a /etc/fstab'
G 'sudo systemctl daemon-reload'
G 'sudo swapoff /dev/vdb3'
G 'swapon --show'
G 'sudo swapon -a'
G 'swapon --show'
G 'findmnt -t tmpfs -o TARGET,FSTYPE,SIZE'
G 'free -m'
G 'sudo mkdir -p /mnt/ram'
G 'sudo mount -t tmpfs -o size=4G tmpfs /mnt/ram'
G 'df -h /mnt/ram'
G 'free -m'
G 'sudo dd if=/dev/zero of=/mnt/ram/fill bs=1M count=300 status=none'
G 'free -m'
G 'df -h /mnt/ram'
G 'sudo umount /mnt/ram'
G 'free -m'

S "第8章 マウントは、名前ではなく中身の印で指す（1.05.3）"
G 'sudo mount /dev/vdb4 /mnt/newroot'
G 'sudo mkdir -p /mnt/newroot'
G 'sudo touch /mnt/newroot/HIDDEN'
G 'ls /mnt/newroot'
G 'sudo mount /dev/vdb4 /mnt/newroot'
G 'ls -a /mnt/newroot'
G 'findmnt -o TARGET,SOURCE,FSTYPE /mnt/newroot'
G 'cd /mnt/newroot && sudo umount /mnt/newroot'
G 'sudo umount /mnt/newroot'
G 'ls /mnt/newroot'
G 'sudo rm /mnt/newroot/HIDDEN'
# 第2章で止めた USB メモリのドライバを戻す
G 'sudo rm /etc/modprobe.d/lab-usb.conf'
G 'sudo systemctl restart systemd-udevd'
H 'virsh attach-device linuc ~/vm/extra/usb-a.xml'
W 10
G 'lsblk -d -o NAME,TRAN,SIZE,SERIAL /dev/sdb'
G 'sudo mkfs.vfat -n STICK_A /dev/sdb'
G 'sudo mkdir -p /media/stick'
G 'sudo mount /dev/sdb /media/stick'
G 'echo "これは A" | sudo tee /media/stick/who.txt'
G 'sudo umount /media/stick'
H 'virsh detach-device linuc ~/vm/extra/usb-a.xml'
W 4
H 'virsh attach-device linuc ~/vm/extra/usb-b.xml'
W 10
G 'lsblk -d -o NAME,TRAN,SIZE,SERIAL /dev/sdb'
G 'sudo mkfs.ext4 -q -L STICK_B /dev/sdb'
H 'virsh attach-device linuc ~/vm/extra/usb-a.xml'
W 10
G 'lsblk -o NAME,TRAN,FSTYPE,LABEL,SERIAL /dev/sdb /dev/sdc'
G 'sudo mount /dev/sdb /media/stick'
G 'cat /media/stick/who.txt'
G 'findmnt -o TARGET,SOURCE,FSTYPE /media/stick'
G 'sudo umount /media/stick'
G 'sudo blkid /dev/sdb /dev/sdc'
G 'ls -l /dev/disk/by-label/'
G 'sudo mount LABEL=STICK_A /media/stick'
G 'cat /media/stick/who.txt'
G 'sudo umount /media/stick'
G 'sudo findmnt --verify'
G 'sudo blkid -t LABEL=BOOT'
G 'sudo blkid -L BOOT'
G 'sudo e2label /dev/vdb2 NEWBOOT'
G 'sudo e2label /dev/vdb2'
G 'sudo xfs_admin -l /dev/vdb4'
G 'sudo findmnt --verify'
G 'cat /etc/fstab'
G 'echo "UUID=$(sudo blkid -s UUID -o value /dev/vdb6)  /srv/home  ext4  defaults,nofail  0  2" | sudo tee -a /etc/fstab'
G 'sudo mkdir -p /srv/home'
G 'sudo mount -a'
G 'findmnt -o TARGET,SOURCE,FSTYPE /srv/home'
G 'sudo systemctl daemon-reload'
G 'sudo mount -o remount,ro /srv/home'
G 'sudo touch /srv/home/test'
G 'sudo mount -o remount,rw /srv/home'
G 'sudo touch /srv/home/test'
G 'ls -l /dev/disk/by-uuid/ | grep vdb'
G 'mount /media/cdrom'
G 'sudo mkdir -p /media/cdrom'
G 'echo "/dev/sr0  /media/cdrom  iso9660  ro,user,noauto  0  0" | sudo tee -a /etc/fstab'
G 'sudo systemctl daemon-reload'
G 'mount /media/cdrom'
G 'mount | grep /media/cdrom'
G 'lsmod | grep isofs'
G 'ls -l /media/cdrom'
G 'umount /media/cdrom'
G 'echo "LABEL=STICK_A  /media/stick  vfat  user,noauto  0  0" | sudo tee -a /etc/fstab'
G 'sudo systemctl daemon-reload'
G 'mount /media/stick'
G 'ls -l /media/stick'
G 'touch /media/stick/mine.txt'
G 'umount /media/stick'
G 'sudo mount /media/stick'
G 'ls -l /media/stick'
G 'sudo umount /media/stick'
G 'sudo findmnt --verify'
H 'virsh detach-device linuc ~/vm/extra/usb-a.xml'
H 'virsh detach-device linuc ~/vm/extra/usb-b.xml'
W 4
G 'sudo reboot'
W 20
H 'vm start'
G 'findmnt -o TARGET,SOURCE,FSTYPE /srv/home'
G 'swapon --show'
G 'findmnt -o TARGET,SOURCE,FSTYPE /media/cdrom'
G 'lsblk -o NAME,FSTYPE,LABEL,MOUNTPOINTS /dev/vdb'
G 'df -h /boot'

S "おわり"
H 'lab env'
