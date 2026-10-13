#!/usr/bin/env bash
# 演習 03 の判定。観測型（alice・bob・carol として実際に作り、消し、一覧しようとする）。
set -uo pipefail
D=/srv/share
sudo -n true 2>/dev/null || { echo "前提不足: sudo が使えません（判定は3人の立場を sudo で借ります）"; exit 2; }
for u in alice bob carol; do
  id "$u" >/dev/null 2>&1 || { echo "前提不足: ユーザ $u がいません"; exit 2; }
done

echo "判定 : 観測型（alice・bob・carol として実際にファイルを作り、消し、一覧しようとした）"
if [ ! -d "$D" ]; then
  echo "観測 : $D が存在しない"
  exit 1
fi

tok="labchk03-$$-${RANDOM}"
A="$D/$tok.alice"; B="$D/$tok.bob"
as() { local u=$1; shift; sudo -n -u "$u" "$@" >/dev/null 2>&1; }
# lab は devs に入っていないので、中のファイルの有無は root として確かめる
ex() { sudo -n test -e "$1"; }

as alice touch "$A"; a_mk=$(ex "$A" && echo 作れた || echo 作れない)
a_grp=$(sudo -n stat -c %G "$A" 2>/dev/null || echo -)
as bob touch "$B";   b_mk=$(ex "$B" && echo 作れた || echo 作れない)
if ex "$A"; then
  as bob rm -f "$A"; b_rm_a=$(ex "$A" && echo 消せなかった || echo 消せた)
else
  b_rm_a="（alice のファイルが無いので試せない）"
fi
if ex "$B"; then
  as bob rm -f "$B"; b_rm_b=$(ex "$B" && echo 消せなかった || echo 消せた)
else
  b_rm_b="（bob のファイルが無いので試せない）"
fi
c_ls=できなかった; as carol ls "$D" && c_ls=できた
sudo -n rm -f "$A" "$B" 2>/dev/null

echo "観測 : $D  $(stat -c '%A %U:%G' "$D")"
echo "       alice がファイルを作る        → $a_mk（グループ $a_grp）"
echo "       bob がファイルを作る          → $b_mk"
echo "       bob が alice のファイルを消す → $b_rm_a"
echo "       bob が自分のファイルを消す    → $b_rm_b"
echo "       carol が一覧する              → $c_ls"

ng=0
[ "$a_mk" = 作れた ]        || { echo "       → alice が作れない"; ng=1; }
[ "$a_grp" = devs ]         || { echo "       → alice のファイルのグループが devs ではない"; ng=1; }
[ "$b_mk" = 作れた ]        || { echo "       → bob が作れない"; ng=1; }
[ "$b_rm_a" = 消せなかった ] || { echo "       → bob が alice のファイルを消せる、または試せない"; ng=1; }
[ "$b_rm_b" = 消せた ]      || { echo "       → bob が自分のファイルを消せない、または試せない"; ng=1; }
[ "$c_ls" = できなかった ]  || { echo "       → carol が中を一覧できる"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       グループは自動で devs になり、他人のファイルは消せず、部外者は覗けない"
echo "       → SGID（グループを受け継ぐ）とスティッキービット（消せるのは持ち主だけ）が両方効いている"
exit 0
