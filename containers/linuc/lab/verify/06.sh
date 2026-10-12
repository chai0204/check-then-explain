#!/usr/bin/env bash
# 演習 06 の判定。観測型（判定の中で1通送り、どのメールボックスに入ったかを見る）。
set -uo pipefail
command -v mail >/dev/null || { echo "前提不足: mail コマンドが見つかりません"; exit 2; }
systemctl is-active postfix >/dev/null 2>&1 || {
  echo "前提不足: postfix が動いていません（systemctl status postfix）"; exit 2; }
id alice >/dev/null 2>&1 || { echo "前提不足: ユーザ alice がいません"; exit 2; }

tok="labchk06-$$-${RANDOM}"
echo "$tok" | mail -s "$tok" alice
sleep 4

n_root=$(grep -c -- "$tok" /var/mail/root  2>/dev/null || true); n_root=${n_root:-0}
n_bob=$(grep  -c -- "$tok" /var/mail/bob   2>/dev/null || true); n_bob=${n_bob:-0}
n_ali=$(grep  -c -- "$tok" /var/mail/alice 2>/dev/null || true); n_ali=${n_ali:-0}
logline=$(journalctl -t postfix/local --no-pager 2>/dev/null | grep -- "orig_to=<alice>" | tail -1)

echo "判定 : 観測型（判定の中で alice 宛に1通送り、どこに入ったかを見た）"
echo "観測 : 送った目印 = $tok （宛先に書いた名前は alice）"
echo "       /var/mail/root  に $n_root 行"
echo "       /var/mail/bob   に $n_bob 行"
echo "       /var/mail/alice に $n_ali 行"
[ -n "$logline" ] && echo "       ログ最終行: $(sed 's/.*postfix\/local\[[0-9]*\]: //' <<<"$logline")"

if [ "$n_root" -lt 1 ] 2>/dev/null; then
  echo "       → root のメールボックスに入っていない"
  if [ "$n_bob" -ge 1 ] 2>/dev/null; then
    echo "         1段目（alice→bob）までは効いている。2段目が効いていない"
    if [ -f /home/bob/.forward ]; then
      echo "         /home/bob/.forward は存在する（権限 $(stat -c %a /home/bob/.forward)・所有 $(stat -c %U /home/bob/.forward)）"
      echo "         postfix がそれを読んだかどうかはログに書いてあります"
    else
      echo "         /home/bob/.forward が無い"
    fi
  elif [ "$n_ali" -ge 1 ] 2>/dev/null; then
    echo "         1段目（alice→bob）も効いていない"
  fi
  exit 1
fi

echo "       alice と書いたものが root に届いている（2回書き換わった）"
exit 0
