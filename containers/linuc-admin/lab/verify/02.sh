#!/usr/bin/env bash
# 演習 02 の判定。観測型（練習機の中で、グループ devs の行と、bob が実際にどのグループに属しているかを見る）。
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外の端末で vm start）"; exit 2; }
G() { lab-guest "$@" 2>/dev/null; }

idline=$(G 'id bob')
[ -n "$idline" ] || { echo "前提不足: 練習機に bob がいません（vm reset --yes で最初の状態に戻せます）"; exit 2; }

echo "判定 : 観測型（練習機の中で getent と id を引き、台帳から見た bob の所属を確かめた）"
grp=$(G 'getent group devs')
echo "観測 : getent group devs → ${grp:-（何も返らない）}"
echo "       id bob → $idline"
ng=0
if [ -z "$grp" ]; then
  echo "       グループ devs が無い"; ng=1
else
  gid=$(cut -d: -f3 <<<"$grp")
  [ "$gid" = 2000 ] || { echo "       devs の GID が 2000 ではない（$gid）"; ng=1; }
fi
groups=" $(G 'id -nG bob') "
for g in proj-a proj-b devs; do
  case "$groups" in
    *" $g "*) ;;
    *) echo "       bob は $g に入っていない"; ng=1 ;;
  esac
done
pg=$(G 'id -gn bob')
[ "$pg" = bob ] || { echo "       bob の主グループが bob ではない（$pg）"; ng=1; }

[ "$ng" = 0 ] || exit 1
echo "       bob は proj-a・proj-b に残ったまま devs にも入っている（主グループは bob のまま）"
echo "       → 所属の一覧は書き足された。置き換えられてはいない"
exit 0
