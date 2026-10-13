#!/usr/bin/env bash
# 演習 01 の判定。観測型。
# 「再起動しても続くか」を、再起動せずに確かめる。値をいったん 1（装置が名乗った既定値）に戻し、
# 起動時に udev が受け取るのと同じ add イベントを1回だけ送って、値がどうなるかを見る。
# 手で書いた 0 は、この判定で 1 に戻る（再起動したのと同じことが起きる）。
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }

before=$(lab-guest 'cat /sys/block/vdb/queue/rotational' 2>/dev/null) || {
  echo "前提不足: 練習機に /dev/vdb が見つかりません"; exit 2; }
after=$(lab-guest 'echo 1 > /sys/block/vdb/queue/rotational &&
  udevadm trigger --action=add --subsystem-match=block --sysname-match=vdb --settle &&
  cat /sys/block/vdb/queue/rotational' 2>/dev/null)
rules=$(lab-guest 'grep -ls rotational /etc/udev/rules.d/*.rules | paste -sd " "' 2>/dev/null)

echo "判定 : 観測型（rotational をいったん 1 に戻し、起動時と同じ add イベントを udev に1回送って、値を読んだ）"
echo "観測 : 判定の前の値             = ${before:-?}"
echo "       add イベントの後の値     = ${after:-?}"
echo "       rotational を書く udev の規則 = ${rules:-（/etc/udev/rules.d に見当たらない）}"
if [ "$after" != "0" ]; then
  if [ "$before" = "0" ]; then
    echo "       → 判定の前は 0 だったが、起動時と同じイベントの後は 1 に戻った"
  else
    echo "       → 判定の前も後も 1（vdb は回転する装置として扱われている）"
  fi
  exit 1
fi
echo "       起動時と同じイベントを受けて、udev が 0 に書き換えた"
echo "       → 再起動しても、カーネルは vdb を回転しない装置（SSD）として扱う"
exit 0
