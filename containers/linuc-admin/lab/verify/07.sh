#!/usr/bin/env bash
# 演習 07 の判定。観測型（lab-report を3通りのロケールで実際に呼び、出力を比べる）。
#   呼び方: LANG=C.UTF-8 / LANG=ja_JP.UTF-8 / LC_ALL=ja_JP.UTF-8（どれも env -i で他の変数を消してから）
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外の端末で vm start）"; exit 2; }
G() { lab-guest "$@" 2>/dev/null; }
G 'test -x /usr/local/bin/lab-report' >/dev/null \
  || { echo "前提不足: /usr/local/bin/lab-report が無いか、実行できません（vm reset --yes で最初の状態に戻せます）"; exit 2; }

echo "判定 : 観測型（lab-report を3通りのロケールで呼び、出力を比べた）"
have=$(G 'locale -a' | grep -ix 'ja_JP.utf8')
# 標準出力だけを比べる（生成していないロケールを LC_ALL で指すと bash が警告を標準エラーに出すが、それは出力の差ではない）
run() { G "env -i PATH=/usr/local/bin:/usr/bin:/bin $1 /usr/local/bin/lab-report 2>/dev/null"; }
o1=$(run 'LANG=C.UTF-8')
o2=$(run 'LANG=ja_JP.UTF-8')
o3=$(run 'LC_ALL=ja_JP.UTF-8')
mon=$(G 'LC_ALL=C date +%b')

echo "観測 : locale -a の ja_JP.utf8 → ${have:-無い}"
for k in 1 2 3; do
  case $k in 1) v=LANG=C.UTF-8; o=$o1 ;; 2) v=LANG=ja_JP.UTF-8; o=$o2 ;; 3) v=LC_ALL=ja_JP.UTF-8; o=$o3 ;; esac
  printf '       %-19s で呼ぶと → %s\n' "$v" "$(tr '\n' '|' <<<"$o" | sed 's/|$//; s/|/ ／ /g')"
done

ng=0
[ -n "$have" ] || { echo "       → ja_JP.UTF-8 が生成されていないので、日本語ロケールで呼んでも差が出ない（確かめられない）"; ng=1; }
[ "$o1" = "$o2" ] || { echo "       → LANG を変えると出力が変わる"; ng=1; }
[ "$o1" = "$o3" ] || { echo "       → LC_ALL を変えると出力が変わる"; ng=1; }
grep -q "/var/log/archive/$mon\$" <<<"$o1" || { echo "       → 今月の欄が $mon（C ロケールの月名）になっていない"; ng=1; }

[ "$ng" = 0 ] || exit 1
echo "       3通りとも同じ出力で、今月の欄は $mon（C ロケールの表記）"
echo "       → スクリプトが自分で LC_ALL を決めたので、呼ぶ側のロケールが届かなくなった"
exit 0
