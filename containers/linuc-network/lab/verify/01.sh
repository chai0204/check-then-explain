#!/usr/bin/env bash
# 演習 01 の判定。観測型（練習機の enp0s17 の状態を読み、判定の中で 10.0.3.2 に ping を1回打つ）。
# 外のコンテナで lab として走る。練習機の中は lab-guest（qemu-guest-agent 経由・root）で見る。
set -uo pipefail
st=$(lab-guest 'cat /sys/class/net/enp0s17/operstate; ip -o -4 addr show dev enp0s17' 2>&1); rc=$?
[ $rc -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }
link=$(head -1 <<<"$st")
addrs=$(grep -oE 'inet [0-9./]+' <<<"$st" | awk '{print $2}' | paste -sd' ')
lab-guest 'ping -c 1 -W 2 -I enp0s17 10.0.3.2' >/dev/null 2>&1; prc=$?

echo "判定 : 観測型（enp0s17 の状態を読み、判定の中で 10.0.3.2 に ping を1回打った）"
echo "観測 : enp0s17 のリンク = ${link:-不明}"
echo "       enp0s17 の IPv4  = ${addrs:-（なし）}"
echo "       ping 10.0.3.2    = $([ $prc -eq 0 ] && echo '返事あり' || echo '返事なし')"
ng=0
[ "$link" = up ] || { echo "       → enp0s17 のリンクが up ではない"; ng=1; }
grep -qw '10.0.3.50/24' <<<"$addrs" || { echo "       → enp0s17 に 10.0.3.50/24 が無い"; ng=1; }
[ $prc -eq 0 ] || { echo "       → 10.0.3.2 から返事が来ない"; ng=1; }
[ $ng = 0 ] || exit 1
echo "       enp0s17 に 10.0.3.50/24 が付き、同じネットワークの 10.0.3.2 と直接話せた（ルータを通らない）"
exit 0
