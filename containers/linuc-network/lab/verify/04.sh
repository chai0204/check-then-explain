#!/usr/bin/env bash
# 演習 04 の判定。観測型（いまの経路表・判定の中での ping・ifupdown が読んだ設定の gateway）。
set -uo pipefail
routes=$(lab-guest 'ip -4 route show default' 2>&1); rc=$?
[ $rc -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }
lab-guest 'ip netns exec router true' >/dev/null 2>&1 || {
  echo "前提不足: 社内 LAN（lab-net.service）が動いていません。外で vm reset --yes で作り直せます"; exit 2; }
lab-guest 'ping -c 1 -W 2 172.16.20.10' >/dev/null 2>&1; prc=$?
gw=$(lab-guest 'ifquery lab0' 2>/dev/null | sed -n 's/^gateway: //p')

echo "判定 : 観測型（経路表を読み、判定の中で 172.16.20.10 に ping を1回打ち、ifupdown が読む lab0 の設定を見た）"
echo "観測 : デフォルトルート       = $(paste -sd'|' <<<"${routes:-（なし）}" | sed 's/|/ ／ /g')"
echo "       ping 172.16.20.10      = $([ $prc -eq 0 ] && echo '返事あり' || echo '返事なし')"
echo "       設定の gateway（ifquery lab0） = ${gw:-（無し）}"
ng=0
grep -q 'via 192.168.10.1 ' <<<"$routes " || { echo "       → デフォルトルートが 192.168.10.1 を向いていない"; ng=1; }
grep -q 'via 192.168.10.254' <<<"$routes" && { echo "       → 192.168.10.254 へのデフォルトルートが残っている"; ng=1; }
[ $prc -eq 0 ] || { echo "       → 172.16.20.10 から返事が来ない"; ng=1; }
[ "$gw" = 192.168.10.1 ] || { echo "       → 設定ファイルの gateway が 192.168.10.1 ではない（ifdown / ifup や再起動のたびにこの値に戻る）"; ng=1; }
[ $ng = 0 ] || exit 1
echo "       いまの経路表も設定ファイルも 192.168.10.1 を向き、サーバの LAN（172.16.20.0/24）に届いた"
exit 0
