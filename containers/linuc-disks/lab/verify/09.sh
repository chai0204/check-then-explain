#!/usr/bin/env bash
# 演習 09 の判定。観測型。
#   いまの状態      … vdb の rotational がいま 0 か（lsblk の ROTA と同じもの）
#   起動したあと    … 再起動せずに確かめる。値をいったん 1（装置が名乗った既定値）にし、起動時に udev が受け取るのと
#                     同じ add イベントを1回だけ送って、値がどうなるかを見る。手で書いただけの 0 は、ここで 1 に戻る。
# 判定のために変えた値は、最後に判定の前の値に戻す（判定は練習機の状態を変えない）。
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }

before=$(lab-guest 'cat /sys/block/vdb/queue/rotational' 2>/dev/null) || {
  echo "前提不足: 練習機に /dev/vdb が見つかりません"; exit 2; }
after=$(lab-guest 'echo 1 > /sys/block/vdb/queue/rotational &&
  udevadm trigger --action=add --subsystem-match=block --sysname-match=vdb --settle &&
  cat /sys/block/vdb/queue/rotational' 2>/dev/null)
rules=$(lab-guest 'grep -ls rotational /etc/udev/rules.d/*.rules | paste -sd " "' 2>/dev/null)
case "$before" in 0|1) lab-guest "echo $before > /sys/block/vdb/queue/rotational" >/dev/null 2>&1 ;; esac

echo "判定 : 観測型（いまの rotational を読み、次に 1 に戻して起動時と同じ add イベントを udev に1回送り、値を読んだ。最後に判定の前の値に戻した）"
echo "観測 : いまの値（判定の前）     = ${before:-?}"
echo "       add イベントの後の値     = ${after:-?}"
echo "       rotational を書く udev の規則 = ${rules:-（/etc/udev/rules.d に見当たらない）}"
ng=0
if [ "$before" != 0 ]; then
  if [ "$after" = 0 ]; then
    echo "       → 起動時と同じイベントでは 0 になるが、いまの値は ${before:-?}（いまはまだ SSD として扱われていない）"
  else
    echo "       → いまの値も、起動時と同じイベントの後の値も 1（vdb は回転する装置として扱われている）"
  fi
  ng=1
elif [ "$after" != 0 ]; then
  echo "       → いまは 0 だが、起動時と同じイベントの後は ${after:-?} に戻った（再起動すると HDD 扱いに戻る）"
  ng=1
fi
[ "$ng" = 0 ] || exit 1
echo "       いまも 0 で、起動時と同じイベントを受けても udev が 0 に書き換えた"
echo "       → 再起動しても、カーネルは vdb を回転しない装置（SSD）として扱う"
exit 0
