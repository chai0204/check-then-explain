# syntax=docker/dockerfile:1.9
# LinuC の「仮想マシン型の檻」の外側。中で QEMU が仮想マシン（Ubuntu 24.04）を1台動かす。
#   build: docker build -t lab-linuc-vmhost:1.0.0 containers/linuc-machine/host
#
# なぜ仮想マシンか（実測 2026-10-13）:
#   ブート・GRUB・ディスクの分割・mount・カーネルモジュール・NIC の設定・ファイアウォールは、
#   コンテナでは「ホストのカーネルを借りている」せいで触れないか、読者ごとに違う画面になる。
#   QEMU の完全エミュレーション（TCG）なら、ホストの特権を1つも借りずに本物のカーネルが動き、
#   仮想ハードウェアは起動オプションで決まるので全員に同じ画面が出る。
#   このマシン（Core Ultra 9 285H）で KVM なしの起動は 36 秒、停止は 4〜8 秒だった。
#
# libvirt は session モード（一般ユーザ lab の権限）で使う。出題範囲 1.01.2 が virsh を名指ししているため。
FROM lab-linuc-base:1.0.0
USER root
ARG APT_SNAPSHOT=20260929T000000Z

# ---- 1) 仮想化の道具 -------------------------------------------------------
#   qemu-system-x86 : エミュレータ本体。/dev/kvm が無くても TCG で動く
#   ovmf            : UEFI ファームウェア（1.01.1 / 1.05.2 の UEFI・ESP を本物で見せる）
#   libvirt-*       : virsh。session モードなら一般ユーザで仮想マシンを定義・起動できる
#   passt は入れない: libvirt 推奨のユーザモード網だが、自分を隔離するためにユーザ名前空間を作ろうとして
#                     docker の既定の制限で起動に失敗した（`Couldn't create user namespace: Operation not permitted`）。
#                     代わりに QEMU 内蔵の slirp を使う（domain.xml の qemu:commandline）。
#   socat           : 仮想マシンの中から外の lab に頼む中継（lab-remote）
#   tini            : PID 1。QEMU と libvirtd の子プロセスを刈り取り、停止シグナルを中継する
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      qemu-system-x86 qemu-utils ovmf \
      libvirt-daemon libvirt-daemon-driver-qemu libvirt-clients \
      openssh-client socat tini \
 && mandb -q \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin /var/cache/apt/archives/*.deb

# ---- 2) 道具 ---------------------------------------------------------------
COPY --chown=root:root --chmod=0755 bin/vm         /usr/local/bin/vm
COPY --chown=root:root --chmod=0755 bin/lab-guest  /usr/local/bin/lab-guest
COPY --chown=root:root --chmod=0755 sbin/lab-vm-init /usr/local/sbin/lab-vm-init
COPY --chown=root:root --chmod=0755 libexec/lab-remote /usr/local/libexec/lab-remote
COPY --chown=root:root --chmod=0644 etc/domain.xml.in /etc/lab-vm/domain.xml.in
COPY --chown=root:root --chmod=0644 etc/profile-vm.sh /etc/profile.d/98-lab-vm.sh

# ---- 3) 仮想マシンの永続領域と ssh の設定 ----------------------------------
#   overlay と UEFI 変数は /home/lab/vm に置く。ボリュームの所有者を合わせるため先に作る。
#   ssh の鍵はここでは作らない。練習機のディスクと対で作り、上の層（containers/linuc-machine/Dockerfile）で入れる。
#   ここで作ると、この層を作り直すたびに鍵が変わり、練習機の authorized_keys と合わなくなる。
RUN install -d -o lab -g lab -m 0700 /home/lab/.ssh \
 && install -d -o lab -g lab -m 0755 /home/lab/vm
COPY --chown=lab:lab --chmod=0644 etc/ssh_config /home/lab/.ssh/config

ENV LIBVIRT_DEFAULT_URI=qemu:///session LAB_VM_NAME=linuc
USER lab
WORKDIR /home/lab
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/sbin/lab-vm-init"]
