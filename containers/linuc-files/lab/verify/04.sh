#!/usr/bin/env bash
# 演習 04 の判定。観測型（元のファイルと backup/ の同名ファイルの中身・更新時刻・権限を突き合わせる）。
set -uo pipefail
W=/home/lab/work/04
B=$W/backup
[ -d "$W" ] && [ -f "$W/notes.txt" ] || {
  echo "前提不足: $W に配布ファイルがありません（lab start 04 で配られます）"; exit 2; }

# 対象は「配ったファイルのうち、名前が .conf で終わるもの」。隠しファイルを含む。
want=(.secret.conf app.conf db.conf)

echo "判定 : 観測型（元のファイルと backup/ の同名ファイルの中身・更新時刻・権限を比べた）"
if [ ! -d "$B" ]; then
  echo "観測 : $B が無い"
  exit 1
fi
have=$(cd "$B" && find . -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | paste -sd' ')
echo "観測 : backup/ の中身 = ${have:-（空）}"

ng=0
for f in "${want[@]}"; do
  if [ ! -f "$W/$f" ]; then echo "       → 元の $f が $W に無い"; ng=1; continue; fi
  if [ ! -f "$B/$f" ]; then echo "       → $f が backup/ に無い"; ng=1; continue; fi
  cmp -s "$W/$f" "$B/$f" || { echo "       → $f の中身が元と違う"; ng=1; }
  t1=$(stat -c %y "$W/$f"); t2=$(stat -c %y "$B/$f")
  if [ "$t1" != "$t2" ]; then
    echo "       → $f の更新時刻が違う（元 ${t1% *} / 写し ${t2% *}）"; ng=1
  fi
  m1=$(stat -c %a "$W/$f"); m2=$(stat -c %a "$B/$f")
  [ "$m1" = "$m2" ] || { echo "       → $f の権限が違う（元 $m1 / 写し $m2）"; ng=1; }
done
for f in $have; do
  case " ${want[*]} " in
    *" $f "*) ;;
    *) echo "       → backup/ に $f がある（名前が .conf で終わるファイルではない）"; ng=1 ;;
  esac
done
[ "$ng" = 0 ] || exit 1
echo "       .conf で終わる ${#want[@]} 個（隠しファイル .secret.conf を含む）が、中身・更新時刻・権限とも元と同じ"
echo "       → * が拾わない隠しファイルも渡り、cp が新しく作った中身に元の時刻が写されている"
exit 0
