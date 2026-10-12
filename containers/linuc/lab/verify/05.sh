#!/usr/bin/env bash
# 演習 05 の判定。観測型（世代ファイルが実在するか）。
set -uo pipefail
command -v logrotate >/dev/null || { echo "前提不足: logrotate が見つかりません"; exit 2; }
[ -f /var/log/lab-app.log ] || {
  echo "前提不足: /var/log/lab-app.log がありません。先に演習 03 を終わらせてください"
  exit 2; }

gz=$(ls -1 /var/log/lab-app.log.1.gz 2>/dev/null | head -1)
plain=$(ls -1 /var/log/lab-app.log.1 2>/dev/null | head -1)
gens=$(ls -1 /var/log/lab-app.log.[0-9]* 2>/dev/null | wc -l)
conf=$(grep -rl 'lab-app' /etc/logrotate.d/ 2>/dev/null | head -1)

echo "判定 : 観測型（世代ファイルが実在するか）"
echo "観測 : 世代ファイル = $(ls -1 /var/log/lab-app.log.[0-9]* 2>/dev/null | tr '\n' ' ')"
echo "       世代数       = $gens"
if [ -n "$conf" ]; then
  echo "       設定ファイル = $conf（権限 $(stat -c %a "$conf")）"
else
  echo "       設定ファイル = /etc/logrotate.d に lab-app を含むものが無い"
fi

if [ -z "$gz" ]; then
  if [ -n "$plain" ]; then
    echo "       → 切れてはいるが圧縮されていない（.1 のまま。compress が効いていない）"
  else
    echo "       → 1世代も切れていない"
  fi
  exit 1
fi
if [ "$gens" -gt 3 ]; then
  echo "       → 世代が $gens 本あり、3世代に収まっていない"
  exit 1
fi
echo "       1k 超で切られ、圧縮された世代が残り、3世代以内に収まっている"
exit 0
