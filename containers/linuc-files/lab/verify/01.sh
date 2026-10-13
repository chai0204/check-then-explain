#!/usr/bin/env bash
# 演習 01 の判定。観測型（alice として実際に読み、一覧しようとする）。
set -uo pipefail
F=/home/lab/work/01/memo.txt
[ -f "$F" ] || { echo "前提不足: $F がありません（課題の最初の echo を打ってください）"; exit 2; }
sudo -n true 2>/dev/null || { echo "前提不足: sudo が使えません（判定は alice の立場を sudo で借ります）"; exit 2; }
id alice >/dev/null 2>&1 || { echo "前提不足: ユーザ alice がいません"; exit 2; }

as_alice() { sudo -n -u alice "$@" >/dev/null 2>&1; }
r_cat=NG;  as_alice cat "$F"                && r_cat=OK
r_home=NG; as_alice ls /home/lab            && r_home=OK
r_dir=NG;  as_alice ls /home/lab/work/01    && r_dir=OK

echo "判定 : 観測型（alice として実際に読み、一覧しようとした）"
echo "観測 : 経路の権限"
for p in /home/lab /home/lab/work /home/lab/work/01 "$F"; do
  printf '         %s  %s\n' "$(stat -c '%A %U:%G' "$p" 2>/dev/null || echo '(見えない)')" "$p"
done
printf '       alice が cat %s  → %s\n' "$F" "$([ "$r_cat" = OK ] && echo 読めた || echo 読めない)"
printf '       alice が ls /home/lab                    → %s\n' "$([ "$r_home" = OK ] && echo 一覧できた || echo 一覧できない)"
printf '       alice が ls /home/lab/work/01            → %s\n' "$([ "$r_dir" = OK ] && echo 一覧できた || echo 一覧できない)"

ng=0
[ "$r_cat" = OK ]  || { echo "       → alice が memo.txt を読めない"; ng=1; }
[ "$r_home" = NG ] || { echo "       → alice が /home/lab の一覧を見られる"; ng=1; }
[ "$r_dir" = NG ]  || { echo "       → alice が /home/lab/work/01 の一覧を見られる"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       名前を知っている memo.txt は読めて、2つのディレクトリはどちらも一覧できない"
echo "       → ディレクトリの x は「通り抜け」、r は「名前の一覧」で、別々に渡せる"
exit 0
