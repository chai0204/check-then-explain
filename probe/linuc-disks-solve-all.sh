#!/bin/bash
# LinuC 主題1.05 の全演習を、模範解答どおりに通す。目的は2つ。
#   1) 未達のとき判定が ✗ を出すこと（鳴らない検査は無いより悪い）。読者がやりがちな途中の状態でも ✗ になること
#   2) 模範解答どおりにやれば ✔ になること
#
# 走らせ方（probe と同じ。新しいボリュームで、練習機は工場出荷時の状態から始める）:
#   docker run -d --name linuc-disks-solve --hostname host --stop-timeout 30 \
#     -v linuc-disks-solve-vm:/home/lab/vm -v linuc-disks-solve-state:/home/lab/.lab lab-linuc-disks:1.0.1
#   docker exec linuc-disks-solve vm start
#   docker cp probe/linuc-disks-solve-all.sh linuc-disks-solve:/tmp/solve.sh
#   docker exec -u lab -w /home/lab linuc-disks-solve bash -l /tmp/solve.sh > logs/linuc-disks-solve-all.log 2>&1
#   docker rm -f linuc-disks-solve
# H は外（lab@host）、G は練習機の中（student@linuc、ssh で流す）、T は端末が要る対話コマンド。
set -u
CLEAN='s/\x1b\[[0-9;?]*[A-Za-z]//g; s/\x1b\][^\x07]*\x07//g; s/\x1b[=>]//g; :a; s/[^\x08]\x08//; ta'
S() { printf '\n\n########## %s ##########\n' "$*"; }
H() { printf '\n$ %s\n' "$1"; eval "$1" 2>&1; }
# 練習機の中のコマンドは、読者と同じ条件の端末（pty・TERM=xterm・幅 80 桁・対話のログインシェル）で流す
G() {
  printf '\n$ %s\n' "$1"
  ssh -q -tt linuc "stty cols 80 rows 24; export TERM=xterm; bash -lic $(printf %q "$1")" < /dev/null 2>&1 \
    | tr -d '\r' | sed -E "$CLEAN"
}
T() {
  local cmd=$1; shift
  printf '\n$ %s\n' "$cmd"
  local feed="sleep 3" k
  for k in "$@"; do feed+="; printf '%s\\n' $(printf %q "$k"); sleep 1"; done
  ssh -q linuc "( $feed ) | TERM=xterm script -qfec $(printf %q "stty cols 200 rows 50; $cmd") /dev/null" 2>&1 \
    | tr -d '\r' | sed -E "$CLEAN"
}

S "A. 何もしていない状態で lab check（全部 ✗ か ⚠ になるはず）"
H 'lab check; echo "exit=$?"'

S "B. 演習01 — vdb を SSD として扱わせる（再起動しても）"
H 'lab check 01; echo "exit=$?"'
G 'echo 0 | sudo tee /sys/block/vdb/queue/rotational'
H 'echo "--- 手で 0 を書いただけ（再起動すると戻る状態）---"; lab check 01; echo "exit=$?"'
G "echo 'ACTION==\"add|change\", SUBSYSTEM==\"block\", KERNEL==\"vdb\", ATTR{queue/rotational}=\"0\"' | sudo tee /etc/udev/rules.d/60-lab-ssd.rules"
G 'sudo udevadm trigger --action=add --subsystem-match=block --sysname-match=vdb'
G 'cat /sys/block/vdb/queue/rotational'
H 'lab check 01; echo "exit=$?"'

S "C. 演習02 — USB メモリを挿し直しても使えなくする"
H 'lab check 02; echo "exit=$?"'
G 'echo "blacklist usb_storage" | sudo tee /etc/modprobe.d/lab-usb.conf'
G 'sudo modprobe -r uas'
H 'echo "--- blacklist usb_storage だけ（uas の依存で読み込まれるはず）---"; lab check 02; echo "exit=$?"'
G 'printf "blacklist usb_storage\nblacklist uas\n" | sudo tee /etc/modprobe.d/lab-usb.conf'
G 'sudo modprobe -r uas'
H 'echo "--- 同じファイルを書き換えて uas も足しただけ（udev が書き換えに気づかないはず）---"; lab check 02; echo "exit=$?"'
G 'sudo systemctl restart systemd-udevd'
G 'sudo modprobe -r uas'
H 'echo "--- ヒント2のとおり udev を再起動した ---"; lab check 02; echo "exit=$?"'
# ファイルを消したことには udev が自分で気づく（使えるように戻るはず）。
# そのあと模範解答どおり、新しいファイルに2行を書く（udev の再起動なし）
G 'sudo rm /etc/modprobe.d/lab-usb.conf'
H 'echo "--- ファイルを消しただけ（udev が気づいて、また使えるようになるはず）---"; lab check 02; echo "exit=$?"'
G 'printf "blacklist usb_storage\nblacklist uas\n" | sudo tee /etc/modprobe.d/lab-usb.conf'
G 'sudo modprobe -r uas'
H 'echo "--- 模範解答: 新しいファイルに2行（udev の再起動なし）---"; lab check 02; echo "exit=$?"'

S "D. 演習03 — 消してしまったパーティションを取り戻す"
H 'lab check 03; echo "exit=$?"'
G 'sudo fdisk -l /dev/vdd'
G 'cat ~/vdd-before.txt'
T 'sudo fdisk /dev/vdd' n p 1 '' '' N w
G 'sudo mount -o ro /dev/vdd1 /mnt'
G 'cat /mnt/aikotoba.txt'
G 'sudo umount /mnt'
H 'lab check 03; echo "exit=$?"'

S "E. 演習04 — 新しいサーバのディスクを GPT で切る"
H 'lab check 04; echo "exit=$?"'
G 'sudo sgdisk -o -n 1:0:+100M -t 1:ef00 -n 2:0:+300M -t 2:8300 -n 3:0:+256M -t 3:8300 -n 4:0:+600M -t 4:8300 -n 5:0:+400M -t 5:8300 -n 6:0:0 -t 6:8300 /dev/vdb'
H 'echo "--- 3番の種類を 8300 のまま作った ---"; lab check 04; echo "exit=$?"'
G 'sudo sgdisk -o -n 1:0:+100M -t 1:ef00 -n 2:0:+300M -t 2:8300 -n 3:0:+256M -t 3:8200 -n 4:0:+600M -t 4:8300 -n 5:0:+400M -t 5:8300 -n 6:0:0 -t 6:8300 /dev/vdb'
G 'lsblk -o NAME,SIZE,PARTTYPENAME /dev/vdb'
H 'lab check 04; echo "exit=$?"'

S "F. 演習05 — 2台のディスクにまたがる箱を作り、中身ごと広げる"
H 'lab check 05; echo "exit=$?"'
G 'sudo pvcreate /dev/vdc /dev/sda'
G 'sudo vgcreate vg0 /dev/vdc /dev/sda'
G 'sudo lvcreate -L 600M -n data vg0'
G 'sudo mkfs.ext4 -q /dev/vg0/data'
G 'sudo mkdir -p /srv/data'
G 'sudo mount /dev/vg0/data /srv/data'
G 'sudo lvextend -L 1.2G vg0/data'
G 'df -h /srv/data'
H 'echo "--- 箱（LV）だけ広げた ---"; lab check 05; echo "exit=$?"'
G 'sudo resize2fs /dev/vg0/data'
G 'df -h /srv/data'
H 'lab check 05; echo "exit=$?"'

S "G. 演習06 — 5種類のファイルシステムを作り、ext4 の予約を減らす"
H 'lab check 06; echo "exit=$?"'
G 'sudo mkfs.vfat -F 32 /dev/vdb1'
G 'sudo mkfs -t ext3 -L NEWBOOT /dev/vdb2'
G 'sudo mkfs.xfs -L ROOT /dev/vdb4'
G 'sudo mkfs.btrfs -L VAR /dev/vdb5'
G 'sudo mkfs.ext4 -L HOME /dev/vdb6'
H 'echo "--- 予約は既定の 5% のまま ---"; lab check 06; echo "exit=$?"'
G 'sudo tune2fs -m 1 /dev/vdb6'
G 'lsblk -o NAME,FSTYPE,LABEL,UUID /dev/vdb'
H 'lab check 06; echo "exit=$?"'

S "H. 演習07 — スワップを作り、起動しても有効にする"
H 'lab check 07; echo "exit=$?"'
G 'sudo mkswap -L SWAP /dev/vdb3'
G 'sudo swapon /dev/vdb3'
G 'swapon --show'
H 'echo "--- swapon しただけ（/etc/fstab に無い）---"; lab check 07; echo "exit=$?"'
G 'echo "UUID=$(sudo blkid -s UUID -o value /dev/vdb3)  none  swap  sw  0  0" | sudo tee -a /etc/fstab'
H 'lab check 07; echo "exit=$?"'

S "I. 演習08 — 一般ユーザが光学メディアをマウントできるようにする"
H 'lab check 08; echo "exit=$?"'
G 'mount /media/cdrom'
G 'sudo mkdir -p /media/cdrom'
G 'echo "/dev/sr0  /media/cdrom  iso9660  ro,noauto  0  0" | sudo tee -a /etc/fstab'
G 'sudo systemctl daemon-reload'
H 'echo "--- user を書き忘れた ---"; lab check 08; echo "exit=$?"'
G "sudo sed -i 's|ro,noauto|ro,user,noauto|' /etc/fstab"
G 'grep cdrom /etc/fstab'
G 'sudo systemctl daemon-reload'
H 'lab check 08; echo "exit=$?"'

S "J. 全問通した状態で lab check（完走メッセージが出るはず）"
H 'lab check; echo "exit=$?"'
H 'lab ls'

S "K. 練習機の中から lab を打つ（外の lab に頼む中継）"
G 'lab check 08'
