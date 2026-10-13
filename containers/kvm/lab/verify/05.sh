#!/usr/bin/env bash
# 演習 05 の判定。観測型（練習機の中の CPU の名乗り・印と /dev/kvm を見る）。TCG でも KVM でもよい。
# 「もともと印を持たない型」を選んだだけでは、消したことにしない（事実確認で3回指摘された抜け道）。
# 練習機の中の観測からは「その型がもともと印を名乗っていたか」が分からないので、名乗りが決まっている型だけを見分ける:
#   TCG: qemu64（AuthenticAMD・family 15・model 107・stepping 1）と max（AuthenticAMD・6・6・3、QEMU TCG CPU）の名乗りのまま
#        印が無いときだけ合格にする。どちらも TCG では svm を名乗る。QEMU 8.2 で svm を名乗る型はほかにも
#        phenom・Opteron_G2〜G5・EPYC（-Rome・-Milan・-Genoa）・Dhyana があるが、判定はそれを見分けない。
#        Nehalem などの Intel の型には初めから印が無く、モデル名だけ付け替えた型（model-id=…）は型番で見分ける。
#   KVM: 本物の CPU をそのまま名乗る型（-cpu host）から消したことを求める。Intel の PC の KVM の既定の型（qemu64）には
#        初めから無く、モデル名だけ付け替えた型（-cpu qemu64,model-id=…）も型番（family・model・stepping）で見分ける。
#        あなたの PC の KVM が入れ子を許していない（nested が N / 0）と -cpu host にも初めから印が無いので、判定できない（前提不足）
set -uo pipefail
. /lab/bin/kvm-lib.sh

echo "判定 : 観測型（練習機の中の CPU の名乗り・印と /dev/kvm を、練習機の中で見た）"
need_running
acc=TCG; uses_kvm "$QP" && acc=KVM
flags=$(g "grep -o -w -E 'vmx|svm' /proc/cpuinfo | sort | uniq -c | xargs")
gi=$(guest_ident)
echo "観測 : QEMU（PID $QP）は $acc で動いている"
echo "       練習機の中の CPU: $(ident_show <<<"$gi")"
echo "       練習機の中の /proc/cpuinfo の vmx・svm → ${flags:-無い}"
k=$(guest_kvm)
echo "       練習機の中の /dev/kvm → $k"
[ -z "$flags" ] && [ "$k" = "無い" ] || exit 1
if [ "$acc" = TCG ]; then
  case "$gi" in
    "AuthenticAMD|15|107|1|QEMU Virtual CPU version 2.5+" | "AuthenticAMD|6|6|3|QEMU TCG CPU version 2.5+") ;;
    *)
      echo "       TCG のこの判定が見分けられるのは、qemu64 と max（どちらも TCG では svm を名乗る QEMU の型）の名乗りだけ"
      echo "       → 練習機の CPU はそのどちらの名乗りでもなく、印を消した結果かどうかが、この観測からは分からない"
      exit 1 ;;
  esac
  echo "       練習機の CPU は qemu64 か max の名乗りのまま（どちらも TCG では svm を名乗る型）、仮想化支援の印だけが無い"
else
  hi=$(host_ident)
  if [ "$gi" != "$hi" ]; then
    echo "       あなたの PC の CPU は「$(ident_show <<<"$hi")」。練習機の CPU はそれと違う型で、もともと印を持たない型でも印は出ない"
    echo "       → 印を消した結果かどうかが、この観測からは分からない"
    exit 1
  fi
  n=$(host_nested)
  case "$n" in
    N | 0)
      echo "前提不足: あなたの PC の KVM は入れ子の仮想化を許していません（nested → $n）。-cpu host にも初めから印が無いので、"
      echo "          消したかどうかをこの観測では確かめられません。TCG でやってください（qemu-linuc -accel tcg -cpu qemu64,-svm）"
      exit 2 ;;
  esac
  echo "       練習機はあなたの PC の CPU を名乗っているのに、仮想化支援の印だけが無い"
fi
echo "       → CPU が仮想化支援を名乗らないので、練習機のカーネルは KVM を用意しなかった（入れ子の仮想化はできない）"
exit 0
