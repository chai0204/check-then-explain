#!/usr/bin/env bash
# 演習 03 の判定。観測型（NetworkManager に enp0s18 の状態と、使っている接続の中身を聞き、実際のアドレスを見る）。
set -uo pipefail
dev=$(lab-guest 'nmcli -t -f GENERAL.STATE,GENERAL.CONNECTION device show enp0s18' 2>&1); rc=$?
[ $rc -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }
[ $rc -ne 0 ] && { echo "前提不足: NetworkManager に聞けません（練習機の中で systemctl status NetworkManager）"; exit 2; }
state=$(sed -n 's/^GENERAL.STATE://p' <<<"$dev")
conn=$(sed -n 's/^GENERAL.CONNECTION://p' <<<"$dev")
method=""; auto=""
if [ -n "$conn" ]; then
  q=$(printf '%q' "$conn")
  method=$(lab-guest "nmcli -g ipv4.method connection show $q" 2>/dev/null)
  auto=$(lab-guest "nmcli -g connection.autoconnect connection show $q" 2>/dev/null)
fi
addr=$(lab-guest 'ip -o -4 addr show dev enp0s18' 2>/dev/null | grep -oE 'inet [0-9./]+.*' | awk '{print $2, ($0 ~ / dynamic /) ? "（DHCP で借りたもの: dynamic）" : "（固定: dynamic でない）"}' | paste -sd' ')

echo "判定 : 観測型（nmcli で enp0s18 の状態と接続の設定を聞き、ip で実際のアドレスを見た）"
echo "観測 : enp0s18 の状態       = ${state:-不明}"
echo "       使っている接続       = ${conn:-（なし）}"
echo "       接続の ipv4.method   = ${method:-—}"
echo "       自動で接続するか     = ${auto:-—}"
echo "       いまの enp0s18 の IPv4 = ${addr:-（なし）}"
ng=0
[[ "$state" == 100* ]] || { echo "       → enp0s18 が connected（100）ではない"; ng=1; }
[ "$method" = auto ] || { echo "       → 接続の ipv4.method が auto（DHCP）ではない"; ng=1; }
[ "$auto" = yes ] || { echo "       → 接続が autoconnect でない（起動しても自動ではつながらない）"; ng=1; }
grep -q 'dynamic' <<<"$addr" || { echo "       → enp0s18 に DHCP で借りたアドレスが無い"; ng=1; }
[ $ng = 0 ] || exit 1
echo "       NetworkManager の接続「$conn」が DHCP でアドレスを借り、起動時にも自動でつながる設定になっている"
exit 0
