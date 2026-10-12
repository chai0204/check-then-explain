#!/usr/bin/env bash
# 演習 04 の判定。観測型（journald 自身が報告した上限の行を読む）。
set -uo pipefail
command -v journalctl >/dev/null || { echo "前提不足: journalctl が見つかりません"; exit 2; }
systemctl is-active systemd-journald >/dev/null 2>&1 || {
  echo "前提不足: systemd-journald が動いていません"; exit 2; }

line=$(journalctl -t systemd-journald --no-pager 2>/dev/null | grep -E 'max [0-9.]+[KMG]' | tail -1)
found=$(grep -oE 'max [0-9.]+[KMG]' <<<"$line" | tail -1)

echo "判定 : 観測型（systemd-journald 自身がログに書いた上限の行を読む）"
if [ -z "$line" ]; then
  echo "観測 : journald が上限を報告した行が1本も無い"
  echo "       （この行は journald が起動／再起動したときに出ます）"
  exit 1
fi
echo "観測 : $line"
echo "       読み取った上限 = $found"

[ "$found" = "max 8.0M" ] || { echo "       → max 8.0M ではない"; exit 1; }
echo "       journald は上限 8.0M で動いていると自分で言っている"
exit 0
