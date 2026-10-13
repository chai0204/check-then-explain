#!/usr/bin/env bash
# 演習 06 の判定。観測型（判定の中で systemd-resolved を再起動してから、glibc の名前解決 getent で実際に引く）。
#   再起動するのは、systemd-resolved が管理するファイル（/run/systemd/resolve/stub-resolv.conf）を直接書き換えた場合を
#   見分けるため。そのファイルは systemd-resolved が起動するたびに書き直す。
#   引く名前の1つは毎回変わる名前（<乱数>.check.lab.example）にする。/etc/hosts に書いて済ませた場合は引けない。
set -uo pipefail
lab-guest true >/dev/null 2>&1; [ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }
lab-guest 'ping -c 1 -W 2 172.16.20.10' >/dev/null 2>&1 || {
  echo "前提不足: DNS サーバ 172.16.20.10 に ping が届きません（演習 04 のデフォルトルート）"; exit 2; }
lab-guest 'systemctl restart systemd-resolved' >/dev/null 2>&1
sleep 1
tok="t${RANDOM}x$$"
a1=$(lab-guest "getent ahostsv4 $tok.check.lab.example" 2>/dev/null | awk 'NR==1{print $1}')
a2=$(lab-guest 'getent ahostsv4 ns' 2>/dev/null | awk 'NR==1{print $1}')
rc=$(lab-guest "grep -E '^(nameserver|search|domain)' /etc/resolv.conf" 2>/dev/null | paste -sd' ' | sed 's/  */ /g')
link=$(lab-guest 'readlink /etc/resolv.conf' 2>/dev/null)

echo "判定 : 観測型（判定の中で systemd-resolved を再起動し、そのあと getent で名前を引いた）"
if [ -n "$link" ]; then kind="シンボリックリンク → $link"; else kind="ふつうのファイル"; fi
echo "観測 : /etc/resolv.conf          = $kind"
echo "       その中の設定              = ${rc:-（nameserver も search も無い）}"
echo "       $tok.check.lab.example = ${a1:-（引けない）}"
echo "       ns（短い名前）            = ${a2:-（引けない）}"
ng=0
[ "$a1" = 172.16.20.10 ] || { echo "       → lab.example の名前が DNS から引けない"; ng=1; }
[ "$a2" = 172.16.20.10 ] || { echo "       → 短い名前 ns が ns.lab.example として引けない"; ng=1; }
[ $ng = 0 ] || exit 1
echo "       systemd-resolved を再起動したあとも、lab.example の名前を 172.16.20.10 の DNS から引けた（短い名前も）"
exit 0
