#!/usr/bin/env bash
# 演習 04 の判定。観測型（練習機の中の /proc/cpuinfo と、この檻（＝あなたの PC のカーネル）の /proc/cpuinfo を比べる）。
set -uo pipefail
. /lab/bin/kvm-lib.sh

need_kvm
echo "判定 : 観測型（練習機の中の CPU の名乗りを、あなたの PC の CPU と比べた）"
need_running
ng=0
if uses_kvm "$QP"; then
  echo "観測 : QEMU（PID $QP）は KVM で動いている"
else
  echo "観測 : QEMU（PID $QP）は KVM を使っていない（TCG）"
  ng=1
fi
# モデル名は -cpu …,model-id= で付け替えられるので、メーカー・型番（family・model・stepping）も比べる
hi=$(host_ident); gi=$(guest_ident)
echo "       あなたの PC の CPU : $(ident_show <<<"$hi")"
echo "       練習機の中の CPU   : $(ident_show <<<"$gi")"
if [ "$gi" != "$hi" ]; then
  if [ "${gi##*|}" = "${hi##*|}" ]; then
    echo "       → モデル名は同じだが、メーカーか型番（family・model・stepping）が違う（名前だけを付け替えた別の型）"
  else
    echo "       → 名乗りが違う"
  fi
  ng=1
fi
[ "$ng" = 0 ] || exit 1
echo "       練習機の中の仮想化支援の印: $(g "grep -o -w -m1 -E 'vmx|svm' /proc/cpuinfo | head -1" | grep . || echo なし) / 練習機の中の /dev/kvm: $(guest_kvm)"
echo "       → 練習機は、あなたの PC の CPU をそのまま名乗っている（中から見える画面が、読む人の PC で変わる）"
exit 0
