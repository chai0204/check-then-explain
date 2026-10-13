#!/usr/bin/env bash
# 演習 04 の判定。観測型（cron が実際にジョブを動かし、2つのファイルが増えていくかを見る）。
#   cron は毎分0秒に起きるので、最近書かれていなければ次の分まで待つ（最大 75 秒）。
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外の端末で vm start）"; exit 2; }
G() { lab-guest "$@" 2>/dev/null; }
G 'systemctl is-active cron' >/dev/null || { echo "前提不足: 練習機の cron が動いていません（sudo systemctl start cron）"; exit 2; }

T=/home/student/tick.log
W=/var/log/lab-whoami.log
# 1回の観測: 「行数 所有者 最終更新からの秒数」を2つぶん
snap() {
  G "now=\$(date +%s); for f in $T $W; do if [ -f \$f ]; then echo \$(wc -l < \$f) \$(stat -c %U \$f) \$(( now - \$(stat -c %Y \$f) )); else echo '- - -'; fi; done"
}
read -r t_n t_u t_age w_n w_u w_age < <(snap | tr '\n' ' ')

echo "判定 : 観測型（cron が実際にジョブを動かし、2つのファイルが増えるかを見た）"
fresh() { [ "$1" != - ] && [ "$1" -le 65 ]; }
if ! { fresh "$t_age" && fresh "$w_age"; }; then
  echo "待機 : cron は毎分0秒に起きます。次の実行を待っています（最大 75 秒）…"
  t0_n=$t_n; w0_n=$w_n
  for _ in $(seq 1 15); do
    sleep 5
    read -r t_n t_u t_age w_n w_u w_age < <(snap | tr '\n' ' ')
    t_grew=0; w_grew=0
    { [ "$t_n" != - ] && { [ "$t0_n" = - ] || [ "$t_n" -gt "$t0_n" ]; }; } && t_grew=1
    { [ "$w_n" != - ] && { [ "$w0_n" = - ] || [ "$w_n" -gt "$w0_n" ]; }; } && w_grew=1
    [ "$t_grew" = 1 ] && [ "$w_grew" = 1 ] && break
  done
fi

last=$(G "tail -1 $W")
cronfile=$(G 'ls -l /etc/cron.d/lab-whoami' | awk '{print $1, $3, $4, $NF}')
show() { if [ "$2" = - ]; then echo "無い"; else echo "$2 行（所有者 $3・最後に書かれたのは $4 秒前）"; fi; }
echo "観測 : $T → $(show x "$t_n" "$t_u" "$t_age")"
echo "       $W → $(show x "$w_n" "$w_u" "$w_age")"
echo "       $W の最後の行 → ${last:-（無い）}"
echo "       /etc/cron.d/lab-whoami → ${cronfile:-無い}"

ng=0
if [ "$t_n" = - ]; then echo "       → tick.log ができていない"; ng=1
elif [ "$t_n" -eq 0 ]; then echo "       → tick.log はあるが 0 行（ジョブは動いたが date の出力が入っていない）"; ng=1
elif ! fresh "$t_age"; then echo "       → tick.log が直近の1分で書かれていない"; ng=1
fi
[ "$t_n" != - ] && [ "$t_u" != student ] && { echo "       → tick.log を作ったのは student ではない（$t_u）"; ng=1; }
if [ "$w_n" = - ]; then echo "       → lab-whoami.log ができていない"; ng=1
elif ! fresh "$w_age"; then echo "       → lab-whoami.log が直近の1分で書かれていない"; ng=1
fi
[ "$w_n" != - ] && [ "$last" != root ] && { echo "       → lab-whoami.log の最後の行が root ではない"; ng=1; }
[ -n "$cronfile" ] || ng=1

[ "$ng" = 0 ] || exit 1
echo "       student の表のジョブは student として、/etc/cron.d のジョブは root として、毎分動いている"
echo "       → 誰として動くかは、表の置き場所（と /etc/cron.d の6列目）が決めた"
exit 0
