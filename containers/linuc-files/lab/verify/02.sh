#!/usr/bin/env bash
# 演習 02 の判定。観測型（新しいログインシェルを1つ起動し、その中で実際に作って権限を見る）。
set -uo pipefail
W=/home/lab/work/02
mkdir -p "$W" 2>/dev/null || { echo "前提不足: $W を作れません"; exit 2; }
tok="labchk02-$$-${RANDOM}"
cur=$(umask)

# 読者が次に開くシェルと同じ「対話的なログインシェル」を起動する。
# ~/.bashrc は対話シェルのときしか最後まで読まれないので -i を付ける。
# 起動時の案内（/etc/profile.d/99-lab.sh）も出るので、印（@@）を付けた行だけ拾う。
#
# umask は親から子へ受け継がれる。いまのシェルで umask 027 と打っただけでも、
# そこから起動したシェルは 027 を受け継いで通ってしまう（2026-10-13 に実測して判明）。
# 新しく入ったときと同じ条件にするため、檻の起動時の値（0022）に戻してから起動する。
out=$(umask 0022; bash -lic "printf '@@U %s\n' \"\$(umask)\"; touch '$W/$tok.f'; mkdir '$W/$tok.d'; stat -c '@@M %a %n' '$W/$tok.f' '$W/$tok.d'" 2>/dev/null </dev/null)
rm -rf "$W/$tok.f" "$W/$tok.d"
nu=$(printf '%s\n' "$out" | sed -n 's/^@@U //p' | head -1)
fm=$(printf '%s\n' "$out" | awk '$1=="@@M" && $3 ~ /\.f$/ {print $2}' | head -1)
dm=$(printf '%s\n' "$out" | awk '$1=="@@M" && $3 ~ /\.d$/ {print $2}' | head -1)

echo "判定 : 観測型（umask を起動時の 0022 に戻して新しいログインシェルを起動し、その中で1つずつ作った）"
if [ -z "$nu" ] || [ -z "$fm" ] || [ -z "$dm" ]; then
  echo "観測 : 新しいシェルが、最後まで命令を実行しなかった（~/.bashrc の途中で止まった可能性）"
  exit 1
fi
echo "観測 : いまのシェルの umask           = $cur"
echo "       新しいシェルの umask           = $nu"
echo "       新しいシェルで作ったファイル     = $fm"
echo "       新しいシェルで作ったディレクトリ = $dm"
ng=0
[ "$fm" = 640 ] || { echo "       → ファイルが 640 で作られていない"; ng=1; }
[ "$dm" = 750 ] || { echo "       → ディレクトリが 750 で作られていない"; ng=1; }
[ "$ng" = 0 ] || exit 1
echo "       新しいシェルでも、作られた瞬間に 640 / 750 になった"
echo "       → umask はシェルごとの値で、起動時に読む設定ファイルから決まる"
exit 0
