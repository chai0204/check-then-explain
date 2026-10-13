#!/usr/bin/env bash
# 演習03 の判定。観測型（2323 が待ち受けているか、サービスが次回も上がるかを実際に見る）。
set -uo pipefail
listen=$(lab-guest "ss -ltnH '( sport = :2323 )' 2>/dev/null"); rc=$?
[ "$rc" -eq 125 ] && { echo "前提不足: 練習機が応答しません（外の端末で vm start / vm status）"; exit 2; }
act=$(lab-guest 'systemctl is-active  lab-echo.service 2>/dev/null')
en=$(lab-guest  'systemctl is-enabled lab-echo.service 2>/dev/null')

echo "判定 : 観測型（ss で 2323 の待ち受けと、lab-echo の有効/無効を見た）"
echo "観測 : 2323 の待ち受け = $( [ -n "$listen" ] && echo あり || echo なし )"
echo "       lab-echo: is-active = ${act:-不明} / is-enabled = ${en:-不明}"

ng=0
[ -n "$listen" ] && { echo "       → まだ 2323 で待ち受けている（サービスが動いている）"; ng=1; }
[ "$act" = active ] && { echo "       → lab-echo がまだ active"; ng=1; }
case "$en" in
  enabled|enabled-runtime|static) echo "       → lab-echo が $en のまま（次の起動でまた上がる）"; ng=1 ;;
esac
[ "$ng" = 0 ] || exit 1

echo "       2323 は閉じ、lab-echo は停止・無効（次の起動でも上がらない）"
exit 0
