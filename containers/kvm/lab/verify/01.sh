#!/usr/bin/env bash
# 演習 01 の判定。観測型（QEMU のプロセスが開いているファイルと、練習機の中の OS の答えを見る）。
set -uo pipefail
. /lab/bin/kvm-lib.sh

echo "判定 : 観測型（QEMU のプロセスが開いているファイルと、練習機の中の OS の答えを見た）"
need_running
if uses_kvm "$QP"; then
  echo "観測 : QEMU（PID $QP）は anon_inode:kvm-vm を持っている → 命令は KVM（CPU の仮想化支援）で実行されている"
  echo "       練習機の中: $(guest_cpu)"
  exit 1
fi
echo "観測 : QEMU（PID $QP）は /dev/kvm も anon_inode:kvm-vm も持っていない → 命令を翻訳して動いている（TCG）"
echo "       練習機の中の OS が ssh に応答した（systemd-detect-virt → $(g systemd-detect-virt)）"
echo "       練習機の中の CPU: $(guest_cpu)"
echo "       練習機の中の /dev/kvm: $(guest_kvm)"
echo "       → あなたの PC の CPU とは別の、QEMU がソフトで作った CPU が、自分の名前と印を名乗っている"
exit 0
