# 外側のログインシェルで、練習機と /dev/kvm の様子を1行だけ出す（土台の 98-lab-vm.sh を置き換える）。
# この檻では libvirt（vm・virsh start）を使わず、qemu-linuc で QEMU を直接起動する。
# 対話シェルだけ（docker exec … lab check のような素通しでは出さない）。
case $- in *i*) ;; *) return ;; esac
if [ -x /usr/local/bin/qemu-linuc ]; then
  /usr/local/bin/qemu-linuc status --short 2>/dev/null
  printf '  qemu-linuc -accel tcg / -accel kvm   練習機の起動（中身は qemu-system-x86_64）。止めるのは qemu-linuc stop\n\n'
fi
