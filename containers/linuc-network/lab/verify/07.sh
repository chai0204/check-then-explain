#!/usr/bin/env bash
# 演習 07 の判定。観測型（glibc の名前解決で www.lab.example を引き、判定の中で実際にその名前で HTTP を取りに行く）。
set -uo pipefail
lab-guest true >/dev/null 2>&1; [ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }
tok="t${RANDOM}x$$"
dns=$(lab-guest "getent ahostsv4 $tok.check.lab.example" 2>/dev/null | awk 'NR==1{print $1}')
[ "$dns" = 172.16.20.10 ] || { echo "前提不足: lab.example の名前を DNS から引けません（先に演習 06）"; exit 2; }
first=$(lab-guest 'getent ahostsv4 www.lab.example' 2>/dev/null | awk 'NR==1{print $1}')
body=$(lab-guest 'curl -s -m 3 http://www.lab.example/' 2>/dev/null)
lh=$(lab-guest 'getent ahostsv4 localhost' 2>/dev/null | awk 'NR==1{print $1}')
own=$(lab-guest 'getent ahostsv4 "$(hostname)"' 2>/dev/null | awk 'NR==1{print $1}')

echo "判定 : 観測型（getent で www.lab.example を引き、判定の中でその名前で http を取りに行った）"
echo "観測 : getent ahostsv4 www.lab.example = ${first:-（引けない）}"
echo "       http://www.lab.example/ の中身  = ${body:-（取れなかった）}"
echo "       localhost / 自分のホスト名       = ${lh:-（引けない）} / ${own:-（引けない）}"
ng=0
[ "$first" = 172.16.20.10 ] || { echo "       → www.lab.example が 172.16.20.10 以外になる"; ng=1; }
grep -q '^hello from www.lab.example' <<<"$body" || { echo "       → www.lab.example の Web の応答が返らない"; ng=1; }
[ "$lh" = 127.0.0.1 ] || { echo "       → localhost が 127.0.0.1 にならない（/etc/hosts の他の行まで消えていないか）"; ng=1; }
[ $ng = 0 ] || exit 1
echo "       ping も curl も使う名前解決（getent）が、DNS と同じ 172.16.20.10 を返した"
exit 0
