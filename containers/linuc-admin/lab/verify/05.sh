#!/usr/bin/env bash
# 演習 05 の判定。観測型。
#   1) run-parts 自身に「/etc/cron.daily のうち、どれを走らせるか」を聞く（--test は走らせずに名前だけ出す）
#   2) スクリプトが実際に走った跡（/var/backups/lab-backup.log の行）を見る
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外の端末で vm start）"; exit 2; }
G() { lab-guest "$@" 2>/dev/null; }

echo "判定 : 観測型（run-parts --test に選ばれるかを聞き、スクリプトが走った跡を見た）"
sel=$(G 'run-parts --test /etc/cron.daily')
files=$(G 'ls -l /etc/cron.daily' | awk 'NR>1 && /lab-backup/ {print $1, $NF}')
logn=$(G 'grep -c "lab-backup ran" /var/backups/lab-backup.log')
loglast=$(G 'tail -1 /var/backups/lab-backup.log')

echo "観測 : run-parts --test /etc/cron.daily が選んだもの:"
sed 's/^/         /' <<<"${sel:-（何も選ばれない）}"
echo "       /etc/cron.daily の lab-backup → ${files:-（無い）}"
echo "       /var/backups/lab-backup.log → ${logn:-0} 行（最後: ${loglast:-なし}）"

ng=0
grep -q 'lab-backup' <<<"$sel" || { echo "       → run-parts は lab-backup を選ばない（毎日の実行で飛ばされる）"; ng=1; }
[ "${logn:-0}" -ge 1 ] 2>/dev/null || { echo "       → スクリプトが走った跡が無い"; ng=1; }

[ "$ng" = 0 ] || exit 1
echo "       run-parts が lab-backup を選び、実際に走った跡もある"
echo "       → 毎日の実行に入るかどうかを決めたのは、置き場所ではなく run-parts の選び方（名前と実行権）"
exit 0
