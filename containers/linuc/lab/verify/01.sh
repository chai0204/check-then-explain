#!/usr/bin/env bash
# 演習 01 の判定。観測型（3箇所の実効値を読むだけ）。
set -uo pipefail
command -v timedatectl >/dev/null || { echo "前提不足: timedatectl が見つかりません"; exit 2; }
systemctl is-system-running >/dev/null 2>&1 || {
  echo "前提不足: systemd が動いていません（timedatectl は systemd に問い合わせます）"
  echo "          起動コマンドの --cap-add SYS_ADMIN を確認してください"
  exit 2
}

z_date=$(date +%Z)
z_sys=$(timedatectl show -p Timezone --value 2>/dev/null)
z_link=$(readlink -f /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')
z_file=$(tr -d ' \t\n' < /etc/timezone 2>/dev/null)

echo "判定 : 観測型（3箇所の実効値をそのまま読む）"
echo "観測 : date +%Z                  = ${z_date:-（空）}"
echo "       timedatectl の Time zone  = ${z_sys:-（空）}"
echo "       /etc/localtime のリンク先 = ${z_link:-（リンクでない）}"
echo "       /etc/timezone の中身      = ${z_file:-（空）}"

ng=0
[ "$z_date" = "JST" ]            || { echo "       → date が JST ではない"; ng=1; }
[ "$z_sys"  = "Asia/Tokyo" ]     || { echo "       → timedatectl が Asia/Tokyo ではない"; ng=1; }
[ "$z_link" = "Asia/Tokyo" ]     || { echo "       → /etc/localtime が Asia/Tokyo を指していない"; ng=1; }
[ "$z_file" = "Asia/Tokyo" ]     || { echo "       → /etc/timezone が Asia/Tokyo ではない"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       4つすべてが Asia/Tokyo（date は JST）で一致している"
exit 0
