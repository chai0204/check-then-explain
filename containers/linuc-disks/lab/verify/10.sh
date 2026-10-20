#!/usr/bin/env bash
# 演習 10 の判定。観測型。
# 判定の中で、判定専用の USB メモリ（シリアル LAB-USB-CHECK）を外側から1本挿し、
# 練習機がそれを「USB 機器」として見たうえで「ディスク」にするかを見てから、抜く。
# 設定ファイルの中身は読まない。どう止めたか（blacklist / install / それ以外）は問わない。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの設定に左右されないように固定する
DOM=${LAB_VM_NAME:-linuc}
X="$HOME/vm/extra/usb-check.xml"
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }
[ -f "$X" ] || { echo "前提不足: $X がありません（外で vm start を打つと作り直されます）"; exit 2; }

# 前回の判定が途中で止まって挿さったままなら、先に抜いておく
virsh detach-device "$DOM" "$X" --live >/dev/null 2>&1 && sleep 3
# 判定の前に読み込まれていた USB のドライバを控える（判定で挿したために読み込まれたものは、最後に外す）
pre_mods=$(lab-guest "lsmod | grep -oE '^(usb_storage|uas) ' | tr -d ' ' | paste -sd ' '" 2>/dev/null)
if ! virsh attach-device "$DOM" "$X" --live >/dev/null 2>&1; then
  echo "前提不足: 判定用の USB メモリを挿せませんでした（virsh attach-device）"; exit 2
fi

probe=$(cat <<'EOF'
dev=""
for i in $(seq 1 60); do
  for s in /sys/bus/usb/devices/*/serial; do
    [ "$(cat "$s" 2>/dev/null)" = LAB-USB-CHECK ] && { dev=$(dirname "$s"); break; }
  done
  [ -n "$dev" ] && break
  sleep 0.5
done
[ -n "$dev" ] || { echo "usb="; exit 0; }
# 挿した直後はドライバの読み込みとディスクの登録が続く。落ち着くまで待ってから見る
sleep 10
udevadm settle
d=$(basename "$dev")
echo "usb=$d"
drv=$(readlink "$dev/$d:1.0/driver" 2>/dev/null)
echo "driver=${drv##*/}"
id=$(ls /dev/disk/by-id/ 2>/dev/null | grep -m1 LAB-USB-CHECK)
if [ -n "$id" ]; then echo "disk=$(readlink -f "/dev/disk/by-id/$id")"; else echo "disk="; fi
echo "mods=$(lsmod | grep -oE '^(usb_storage|uas) ' | tr -d ' ' | paste -sd ' ')"
EOF
)
obs=$(lab-guest "$probe" 2>/dev/null)
virsh detach-device "$DOM" "$X" --live >/dev/null 2>&1
# 判定の前に無かったドライバが、判定で挿したために読み込まれていたら外す（判定は練習機の状態を変えない）
unloaded=""
if [ -z "$pre_mods" ]; then
  unloaded=$(lab-guest 'udevadm settle; for i in $(seq 1 20); do
      grep -qE "^(uas|usb_storage) " /proc/modules || break
      modprobe -r uas usb_storage 2>/dev/null; sleep 0.5; done
    grep -qE "^(uas|usb_storage) " /proc/modules && echo 外せなかった || echo 外した' 2>/dev/null)
fi

usb=$(sed -n 's/^usb=//p' <<<"$obs")
drv=$(sed -n 's/^driver=//p' <<<"$obs")
disk=$(sed -n 's/^disk=//p' <<<"$obs")
mods=$(sed -n 's/^mods=//p' <<<"$obs")

echo "判定 : 観測型（判定の中で USB メモリを1本挿し、練習機がそれをどう扱ったかを見て、抜いた）"
if [ -z "$usb" ]; then
  echo "観測 : 判定用の USB メモリが、30 秒待っても練習機の USB に現れなかった"
  echo "前提不足: USB の口（qemu-xhci）か練習機の状態を確かめてください（vm status）"
  exit 2
fi
echo "観測 : USB 機器として   = 見えた（/sys/bus/usb/devices/$usb）"
echo "       付いたドライバ   = ${drv:-なし}"
echo "       ディスクとして   = ${disk:-現れなかった}"
echo "       読み込まれていたモジュール = ${mods:-なし}"
if [ -n "$mods" ] && [ -z "$pre_mods" ]; then
  echo "       （判定の前は読み込まれていなかったので、判定のあと外した${unloaded:+: $unloaded}）"
fi
if [ -n "$drv" ] || [ -n "$disk" ]; then
  echo "       → 挿した USB メモリが、ディスクとして使える状態になった"
  exit 1
fi
echo "       USB 機器としては見えるが、ドライバが付かず、ディスクにならなかった"
echo "       → 装置はある。使えなくしたのは、カーネルにドライバを読み込ませる側の設定"
exit 0
