#!/usr/bin/env bash
# 演習 03 の判定。観測型（いまの QEMU が KVM を使っているかを、QEMU のプロセスが開いているファイルで見る。
# 同じディスクに残った起動の記録（journal）も、練習機の中で見る）。
# KVM かどうかの決め手は、外から見た QEMU のファイル（anon_inode:kvm-vm）だけにする。練習機の中の答え
# （systemd-detect-virt と、journal の「Detected virtualization X.」）は練習機の名乗りで、-cpu …,kvm=off で
# 名前を消すと KVM の上でも qemu になる（第5章）。名乗りは表示するが、合否には使わない（事実確認で指摘）。
# 比べる相手（TCG の起動）は journal にしか残らないので、「練習機が qemu と記録した起動」があることを求める。
set -uo pipefail
. /lab/bin/kvm-lib.sh

need_kvm
echo "判定 : 観測型（QEMU のプロセスが開いているファイルと、練習機の中の起動の記録を見た）"
need_running
ng=0
if uses_kvm "$QP"; then
  echo "観測 : QEMU（PID $QP）は anon_inode:kvm-vm を持っている → KVM で動いている"
else
  echo "観測 : QEMU（PID $QP）は anon_inode:kvm-vm を持っていない → 命令を翻訳して動いている（TCG）"
  ng=1
fi
virt=$(g systemd-detect-virt)
echo "       練習機の中の systemd-detect-virt → ${virt:-?}（練習機の名乗り。合否には使わない）"

# 同じディスクの起動の記録: 起動するたびに systemd が「Detected virtualization X.」を1行、
# 起動し終わると「Startup finished in …(kernel) + …(userspace) = ….」を1行残す（並びは起動の順。いちばん新しい1回が、いまの起動）。
# X は練習機の名乗りなので、いまの起動は上の fd の観測で扱い、比べる相手（TCG の起動）は、いまより前の qemu の記録から探す
rec=$(g "journalctl --no-pager -o cat -g 'Detected virtualization|Startup finished in .*kernel'")
summary=$(awk '
  /Detected virtualization/ { b++; v[b] = $3; sub(/\.$/, "", v[b]); next }
  /Startup finished in/     { if (b) s[b] = $0 }
  END { for (i = 1; i <= b; i++) print v[i] "\t" s[i] }' <<<"$rec")
nq=$(grep -c '^qemu' <<<"$summary"); nk=$(grep -c '^kvm' <<<"$summary")
echo "       このディスクの起動の記録（練習機の名乗り）: qemu $nq 回・kvm $nk 回（いちばん新しい1回が、いまの起動）"
now=$(tail -n 1 <<<"$summary"); before=$(head -n -1 <<<"$summary")
[ -n "$now" ] && echo "       いまの起動（練習機の名乗りは ${now%%$'\t'*}）: ${now#*$'\t'}"
lastq=$(grep '^qemu' <<<"$before" | cut -f2- | grep . | tail -1)
[ -n "$lastq" ] && echo "       それより前に qemu と記録した起動（最後に起動し終わったもの）: $lastq"
if ! grep -q '^qemu' <<<"$before"; then
  echo "       → いまより前に、このディスクを TCG で起動した記録が無い（練習機が qemu と記録した起動が無い。比べる相手がいない）"
  ng=1
fi
[ "$ng" = 0 ] || exit 1
echo "       → 同じ練習機（同じディスク）を、いまは KVM で動かしている（起動の時間は、上の2行で比べる）"
exit 0
