#!/usr/bin/env bash
# 演習 03 の判定。観測型（実際に1行投げて、どのファイルに現れたかを見る）。
set -uo pipefail
command -v logger >/dev/null || { echo "前提不足: logger が見つかりません"; exit 2; }
systemctl is-active rsyslog >/dev/null 2>&1 || {
  echo "前提不足: rsyslog が動いていません（systemctl status rsyslog）"; exit 2; }

tok="labchk03-$$-${RANDOM}"
logger -p local3.info "$tok"
sleep 2

app=/var/log/lab-app.log
sys=/var/log/syslog
n_app=$(grep -c -- "$tok" "$app" 2>/dev/null || true); n_app=${n_app:-0}
n_sys=$(grep -c -- "$tok" "$sys" 2>/dev/null || true); n_sys=${n_sys:-0}

echo "判定 : 観測型（判定の中で local3.info に1行投げ、どこに現れたかを見た）"
echo "観測 : 投げた目印 = $tok"
echo "       $app  に $n_app 行"
echo "       $sys        に $n_sys 行"

ng=0
[ -f "$app" ] || { echo "       → $app が存在しない"; ng=1; }
[ "$n_app" -ge 1 ] 2>/dev/null || { echo "       → $app に現れなかった"; ng=1; }
[ "$n_sys" -ge 1 ] 2>/dev/null || { echo "       → $sys から消えている（移してしまった）"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       同じ1行が2つのファイルに入っている"
echo "       → 宛先を決めたのは logger ではなく /etc/rsyslog.d の設定"
exit 0
