#!/usr/bin/env bash
# 演習01 の判定。観測型（練習機の中で catfile の SUID ビットを実際に見る）。
set -uo pipefail
out=$(lab-guest 'ls -l /usr/local/bin/catfile 2>/dev/null; echo "===MARK==="; find /usr/local/bin/catfile -perm -4000 -type f 2>/dev/null'); rc=$?
[ "$rc" -eq 125 ] && { echo "前提不足: 練習機が応答しません（外の端末で vm start / vm status）"; exit 2; }

ls_line=$(printf '%s\n' "$out" | sed -n '1{/===MARK===/!p}')
suid=$(printf '%s\n' "$out" | sed -n '/===MARK===/,$p' | sed '1d' | head -1)

echo "判定 : 観測型（練習機の中で /usr/local/bin/catfile の SUID を見た）"
if [ -n "$ls_line" ]; then
  echo "観測 : $ls_line"
else
  echo "観測 : catfile は存在しない（削除した）"
fi

if [ -n "$suid" ]; then
  echo "       → まだ SUID が立っている（find -perm -4000 が当たった）"
  exit 1
fi
echo "       SUID ビットは立っていない（find -perm -4000 が当たらなかった）"
echo "       → 一般ユーザは catfile 経由で /etc/shadow を読めない"
exit 0
