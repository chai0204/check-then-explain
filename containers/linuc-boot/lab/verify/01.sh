#!/usr/bin/env bash
# 演習 01 の判定。観測型（libvirt が持っている練習機の状態と、練習機の中の OS の応答を見る）。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値（system）に引きずられないよう固定する

st=$(virsh domstate linuc 2>/dev/null | head -1)
[ -n "$st" ] || { echo "前提不足: 練習機 linuc が libvirt に定義されていません（vm define で定義し直せます）"; exit 2; }
auto=$(virsh dominfo linuc 2>/dev/null | sed -n 's/^Autostart: *//p')

echo "判定 : 観測型（libvirt に練習機の状態を尋ね、練習機の中の OS からの応答を受け取った）"
echo "観測 : virsh domstate linuc          → $st"
echo "       virsh dominfo linuc の Autostart → ${auto:-?}"

ng=0
if [ "$st" = running ]; then
  up=$(lab-guest 'cut -d" " -f1 /proc/uptime' 2>/dev/null); rc=$?
  if [ "$rc" -eq 0 ] && [ -n "$up" ]; then
    echo "       練習機の中の OS が応答した（起動から ${up%.*} 秒）"
  else
    echo "       → 電源は入っているが、中の OS がまだ応答しない（起動の途中か、GRUB などで止まっている）"
    ng=1
  fi
else
  echo "       → 練習機の電源が入っていない"
  ng=1
fi
[ "$auto" = enable ] || { echo "       → 自動起動の印が付いていない"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       電源が入り、中の OS が応答し、自動起動の印も付いている"
echo "       → 電源（libvirt の状態）と、中の OS が動いていること（応答）は別々に確かめた"
exit 0
