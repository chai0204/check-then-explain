#!/usr/bin/env bash
# 演習02 の判定。観測型（アカウントデータベースの有効期限を実際に読む）。
# sshd が拒否するのと同じ条件＝「有効期限が今日以前」を見る。パスワードのロックだけでは通さない。
set -uo pipefail
line=$(lab-guest 'getent shadow olduser'); rc=$?
[ "$rc" -eq 125 ] && { echo "前提不足: 練習機が応答しません（外の端末で vm start / vm status）"; exit 2; }
[ -n "$line" ] || { echo "前提不足: olduser が見つかりません（vm reset --yes で戻せます）"; exit 2; }

pw=$(printf '%s' "$line"  | cut -d: -f2)
exp=$(printf '%s' "$line" | cut -d: -f8)
today=$(( $(date +%s) / 86400 ))

locked="いいえ"
case "$pw" in '!'*|'*'*) locked="はい（! か *）";; esac

echo "判定 : 観測型（getent shadow olduser の有効期限フィールドを見た）"
echo "観測 : パスワードのロック = $locked"
if [ -n "$exp" ]; then
  echo "       アカウント有効期限 = 1970 から $exp 日目（今日 = $today 日目）"
else
  echo "       アカウント有効期限 = 未設定（never）"
fi

if [ -n "$exp" ] && printf '%s' "$exp" | grep -qE '^[0-9]+$' && [ "$exp" -le "$today" ]; then
  echo "       有効期限が今日以前 → sshd はこのアカウントのログインを拒否する"
  exit 0
fi
echo "       → 期限切れになっていない。パスワードをロックしても鍵では入れてしまう"
echo "         （本当に止めるには有効期限を切る: usermod -e / chage -E）"
exit 1
