# 外側のログインシェルで、練習機の状態を1行だけ出す。
# 対話シェルだけ（docker exec … lab check のような素通しでは出さない）。
case $- in *i*) ;; *) return ;; esac
export LIBVIRT_DEFAULT_URI=qemu:///session
if [ -x /usr/local/bin/vm ]; then
  /usr/local/bin/vm status --short 2>/dev/null
  printf '  vm start / vm ssh / vm console / vm stop   練習機の操作（中身は virsh と ssh）\n\n'
fi
