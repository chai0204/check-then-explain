#!/usr/bin/env bash
# 演習 05 の判定。観測型（停止の予約を持っている systemd-logind に、予約の中身を尋ねる）。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値（system）に引きずられないよう固定する

prop=$(lab-guest 'busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager ScheduledShutdown' 2>/dev/null); rc=$?
[ $rc -eq 125 ] && { echo "前提不足: 練習機の中から応答がありません（電源が切れている・起動の途中・systemd を通らない起動（init=/bin/bash など）のどれか）。virsh domstate linuc と virsh console linuc で状態を見てください"; exit 2; }
now=$(lab-guest 'date +%s' 2>/dev/null)
msg=$(lab-guest 'sed -n "s/^WALL_MESSAGE=//p" /run/systemd/shutdown/scheduled 2>/dev/null' 2>/dev/null)
# logind は文を \xe3\x83… の形で保存している（実測）。読める形に戻して見せる
msg=$(printf '%b' "$msg")

# 形: (st) "poweroff" 1791885737658869   予約が無いとき: (st) "" 18446744073709551615（実測。種類が空で判断する）
mode=$(sed -E 's/^\(st\) "([^"]*)" .*/\1/' <<<"$prop")
usec=$(sed -E 's/^\(st\) "[^"]*" ([0-9]+).*/\1/' <<<"$prop")

echo "判定 : 観測型（systemd-logind が持っている停止の予約を、練習機の中で尋ねた）"
echo "観測 : ScheduledShutdown → ${prop:-（読めない）}"
if [ -z "$mode" ]; then
  echo "       → 停止の予約は入っていない"
  exit 1
fi
left=$(( (usec / 1000000 - now) / 60 ))
echo "       種類 → $mode / いまから約 ${left} 分後"
echo "       知らせる文 → ${msg:-（無い）}"

ng=0
[ "$mode" = poweroff ] || { echo "       → 予約の種類が poweroff（電源を切る）ではない"; ng=1; }
[ "$left" -ge 15 ] || { echo "       → 予約の時刻が 15 分より近い"; ng=1; }
[ -n "$msg" ] || { echo "       → ログイン中の人に送る文が付いていない"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       電源を切る予約が先の時刻に入り、知らせる文が付いている"
echo "       （確かめたら shutdown -c で取り消してください。取り消さないと、その時刻に本当に止まります）"
exit 0
