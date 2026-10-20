# syntax=docker/dockerfile:1.9
# 「確かめて説明する KVM」の檻。土台は仮想マシン型の檻と同じ lab-linuc-machine（QEMU 8.2・OVMF・練習機のディスク・ssh の鍵）。
#   読者は libvirt（vm・virsh start）を通さず、qemu-linuc（qemu-system-x86_64 を直接打つ薄い包み。打つコマンド行を ▶ で表示する）で
#   練習機を起動し、同じ練習機（同じディスク）を TCG（-accel tcg）と KVM（-accel kvm）で起動して比べる。
#   KVM を使うには、読者が起動時に --device /dev/kvm と --group-add "$(stat -c %g /dev/kvm)" を渡す（ケーパビリティは渡さない）。
#   渡さなくても檻は起動し、KVM が要る演習は lab check が前提不足（exit 2）として理由を出す。
#
#   build: docker build --build-context labcmd=containers/base --build-context labvm=containers/linuc-machine/host -t lab-kvm:1.0.1 containers/kvm
#
# 起動はコンテナ型（docker run --rm -it。PID 1 は tini、その子が読者の bash -l）。土台の lab-vm-init（libvirt の練習機を
# 定義・自動起動する）は使わない。練習機の差分ディスクは ~/vm（ボリューム）に置き、コンテナを起動し直しても続きから使える。
FROM lab-linuc-machine:1.0.0
USER root

# ---- 1) 練習機を QEMU で直接起動する道具と、檻の入口 ---------------------------
COPY --chown=root:root --chmod=0755 bin/qemu-linuc /usr/local/bin/qemu-linuc
COPY --chown=root:root --chmod=0755 sbin/lab-kvm-init /usr/local/sbin/lab-kvm-init
#   土台の 98-lab-vm.sh（libvirt の練習機の状態を出す）を置き換える。この檻の練習機は libvirt に定義されていない
COPY --chown=root:root --chmod=0644 etc/profile-kvm.sh /etc/profile.d/98-lab-vm.sh

#   第1章で、練習機の中の KVM に小さな仮想マシンを作って動かすプログラム（ssh linuc sudo python3 - < … で渡す）
#   （ディレクトリごと写す。--chmod はコピー先に作るディレクトリにも効くので、読み込めるよう 0755 にする）
COPY --chown=root:root --chmod=0755 share/ /usr/local/share/lab-kvm/

# ---- 2) 演習 ---------------------------------------------------------------------
COPY --chown=root:root --chmod=0555 lab/ /lab/

LABEL org.opencontainers.image.source=https://github.com/chai0204/check-then-explain
LABEL org.opencontainers.image.description="KVM（CPU の仮想化支援と /dev/kvm）を、同じ練習機を TCG と KVM で起動して確かめる学習用コンテナ"
LABEL org.opencontainers.image.licenses=MIT
# ---- lab コマンドを最新にする（1.0.1、2026-10-20）--------------------
#   lab の正本は containers/base/bin/lab。土台（lab-base）から作り直すと上の層が全部作り直しになり、
#   本文の記録とずれうるので、最新の lab をここで重ねる。これより前の層は 1.0.0 とキャッシュで同一。
#   build: docker build --build-context labcmd=containers/base --build-context labvm=containers/linuc-machine/host -t lab-kvm:<版> containers/kvm
COPY --from=labcmd --chown=root:root --chmod=0755 bin/lab /usr/local/bin/lab
#   練習機の中の lab が外の lab に頼む中継（lab-remote）も最新にする（lab show を通すため）。
#   build には --build-context labvm=containers/linuc-machine/host も付ける。
COPY --from=labvm --chown=root:root --chmod=0755 libexec/lab-remote /usr/local/libexec/lab-remote
ENV LAB_THEME=kvm LAB_VERSION=1.0.1 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/chai0204/lab:kvm-1.0.1
ENV LAB_RESET_HINT="元に戻すには qemu-linuc reset --yes（練習機のディスクが最初の状態に戻ります）"
USER lab
WORKDIR /home/lab
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/sbin/lab-kvm-init"]
CMD ["/bin/bash", "-l"]
