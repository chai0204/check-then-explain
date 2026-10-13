#!/usr/bin/env bash
# 演習 02 の判定。観測型（ifupdown 自身の記録・起動時に上げる一覧・設定の読み取り結果・実際のアドレスを見る）。
# ifupdown は「自分が上げた NIC」を /run/network/ifstate に記録している。ifquery --state はそれを読む。
set -uo pipefail
lab-guest true >/dev/null 2>&1; [ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }
state=$(lab-guest 'ifquery --state enp0s17' 2>/dev/null)
list=$(lab-guest 'ifquery --list' 2>/dev/null | paste -sd' ')
conf=$(lab-guest 'ifquery enp0s17' 2>/dev/null | sed -n 's/^address: //p')
addrs=$(lab-guest 'ip -o -4 addr show dev enp0s17' 2>/dev/null | grep -oE 'inet [0-9./]+' | awk '{print $2}' | paste -sd' ')

echo "判定 : 観測型（ifupdown の記録と、enp0s17 の実際のアドレスを読んだ）"
echo "観測 : ifupdown が上げた記録（ifquery --state enp0s17） = ${state:-（記録なし）}"
echo "       起動時に上げる NIC（ifquery --list）            = ${list:-（なし）}"
echo "       設定ファイルのアドレス（ifquery enp0s17）        = ${conf:-（enp0s17 の設定が無い）}"
echo "       いまの enp0s17 の IPv4                          = ${addrs:-（なし）}"
ng=0
[ "$state" = "enp0s17=enp0s17" ] || { echo "       → ifupdown の記録に enp0s17 が無い"; ng=1; }
grep -qw enp0s17 <<<"$list" || { echo "       → 起動時に上げる一覧（auto）に enp0s17 が無い"; ng=1; }
[ "$conf" = "10.0.3.50" ] || { echo "       → 設定ファイルに enp0s17 の address 10.0.3.50 が無い"; ng=1; }
grep -qw '10.0.3.50/24' <<<"$addrs" || { echo "       → enp0s17 に 10.0.3.50/24 が付いていない"; ng=1; }
[ $ng = 0 ] || exit 1
echo "       設定ファイルに書かれ、ifupdown が自分で上げたと記録している（再起動しても ifup -a で同じになる）"
exit 0
