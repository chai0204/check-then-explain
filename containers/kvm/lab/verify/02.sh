#!/usr/bin/env bash
# 演習 02 の判定。観測型（この檻の /dev/kvm を実際に読み書きで開き、lab の権限を /proc/self/status で見る）。
set -uo pipefail
. /lab/bin/kvm-lib.sh

me=$(id -un)   # ふつうは lab（--user 0 で起動していれば root）
echo "判定 : 観測型（この檻の $me として /dev/kvm を読み書きで開き、自分の権限を /proc/self/status で見た）"
groups=$(sed -n 's/^Groups:[[:space:]]*//p' /proc/self/status | xargs)
capeff=$(sed -n 's/^CapEff:[[:space:]]*//p' /proc/self/status)
capbnd=$(sed -n 's/^CapBnd:[[:space:]]*//p' /proc/self/status)

if [ ! -e /dev/kvm ]; then
  if host_has_kvm; then
    echo "観測 : この檻の /dev に kvm が無い"
    echo "       docker が動いているカーネルには KVM がある（/sys/module/kvm）・CPU は $(grep -o -w -m1 -E 'vmx|svm' /proc/cpuinfo | head -1) を名乗っている"
    exit 1
  fi
  echo "前提不足: docker が動いているカーネルに KVM が見当たりません（/sys/module/kvm が無いか、CPU が vmx・svm を名乗っていない）。"
  echo "          この演習は、本文の記録で読んでください"
  exit 2
fi

num=$(printf '%d, %d' "0x$(stat -c %t /dev/kvm)" "0x$(stat -c %T /dev/kvm)")
echo "観測 : /dev/kvm → $(stat -c '%A %U:%g' /dev/kvm)（番号 $num）"
echo "       $me のグループ（Groups）→ ${groups:-なし}"
e=$(kvm_err)
if [ -n "$e" ]; then
  echo "       $me が /dev/kvm を読み書きで開こうとした → $e"
  case "$e" in
    *"not permitted"*) echo "       （ファイルの権限で断られたのではなく、カーネルが開くこと自体を断った）" ;;
  esac
  exit 1
fi
echo "       $me が /dev/kvm を読み書きで開けた"
# 渡しすぎていないか。起動のときに渡した特権は CapBnd（このコンテナのプロセスが持てる特権の上限）に出る。
# lab は root ではないので、--privileged で起動しても CapEff（いま効いている特権）は 0 のまま。CapEff が 0 でないのは root で動いているとき
extra=$(( 16#$capbnd & ~16#a80425fb ))
ng=0
if [ "$extra" -ne 0 ]; then
  echo "       CapBnd=$capbnd → docker の既定（00000000a80425fb）より多くの特権を持てる（--privileged・--cap-add など）"
  ng=1
fi
if [ "$capeff" != 0000000000000000 ]; then
  echo "       CapEff=$capeff → 特権が効いている。lab ではなく root として動いている（--user 0 など）"
  ng=1
fi
[ "$ng" = 0 ] || exit 1
echo "       CapBnd=$capbnd（docker の既定のまま）・CapEff=$capeff → 特権は増えていない"
echo "       → 渡したのはデバイスのファイル1つと、それを開けるグループだけ"
exit 0
