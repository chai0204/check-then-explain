#!/usr/bin/env bash
# 演習05 の判定。観測型（iptables の INPUT を実際に読み、管理 ssh が生きているかを外から確かめる）。
set -uo pipefail
rules=$(lab-guest 'iptables -S INPUT 2>/dev/null'); rc=$?
[ "$rc" -eq 125 ] && { echo "前提不足: 練習機が応答しません（外の端末で vm start / vm status）"; exit 2; }

# 2323 を落とすルールがあるか（DROP か REJECT。--dport 2323 を含む行）
drop2323=$(printf '%s\n' "$rules" | grep -E -- '--dport 2323' | grep -E 'DROP|REJECT' | head -1)
# 22 を落とすルールが無いか
drop22=$(printf '%s\n' "$rules" | grep -E -- '--dport 22( |$)' | grep -E 'DROP|REJECT' | head -1)
# 管理 ssh が実際に生きているか（外側から鍵で入れるか）
ssh -o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=accept-new linuc true 2>/dev/null
sshrc=$?

echo "判定 : 観測型（iptables -S INPUT を読み、外側から ssh linuc を試した）"
echo "観測 : 2323 を落とすルール = ${drop2323:-（無い）}"
echo "       22 を落とすルール   = ${drop22:-（無い＝良い）}"
echo "       外側からの ssh linuc = $( [ "$sshrc" = 0 ] && echo '通る' || echo '通らない' )"

ng=0
[ -n "$drop2323" ] || { echo "       → 2323 を落とすルールが無い"; ng=1; }
[ -n "$drop22" ]   && { echo "       → 22 を落とすルールがある（管理 ssh を巻き込んでいる）"; ng=1; }
[ "$sshrc" = 0 ]   || { echo "       → 管理 ssh が通らない（締め出し。vm console か vm reset --yes で戻す）"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       2323 は落とし、22 は残している（自分は締め出されていない）"
exit 0
