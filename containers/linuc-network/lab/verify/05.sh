#!/usr/bin/env bash
# 演習 05 の判定。観測型（判定の中で、router（別の機械）から練習機の 8080 番へ実際に HTTP で取りに行く）。
set -uo pipefail
listen=$(lab-guest "ss -Htln 'sport = :8080'" 2>&1); rc=$?
[ $rc -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }
lab-guest 'ip netns exec router true' >/dev/null 2>&1 || {
  echo "前提不足: 社内 LAN（lab-net.service）が動いていません。外で vm reset --yes で作り直せます"; exit 2; }
active=$(lab-guest 'systemctl is-active lab-board' 2>/dev/null)
body=$(lab-guest 'ip netns exec router curl -s -m 3 http://192.168.10.2:8080/' 2>/dev/null)
addrs=$(awk '{print $4}' <<<"$listen" | paste -sd' ')

echo "判定 : 観測型（判定の中で router から http://192.168.10.2:8080/ を取りに行った）"
echo "観測 : lab-board.service      = ${active:-不明}"
echo "       8080 番の待ち受け      = ${addrs:-（待ち受けていない）}"
echo "       router から取れた中身  = ${body:-（取れなかった）}"
grep -q '^lab-board:' <<<"$body" || exit 1
echo "       別の機械（router）から 192.168.10.2:8080 につながり、掲示板の応答が返った"
exit 0
