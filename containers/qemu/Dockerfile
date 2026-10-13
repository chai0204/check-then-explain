# syntax=docker/dockerfile:1.9
# 「QEMU」の記事の檻（コンテナ型・特権なし）。
#   土台 lab-linuc-machine:1.0.0 に入っている QEMU（qemu-system-x86_64・qemu-img）・ファームウェア（SeaBIOS・OVMF）・
#   練習機のディスク（/var/lib/lab-vm/linuc-guest.qcow2）を、読者が libvirt を通さずに直接使う。
#   KVM は使わない（/dev/kvm を渡さない）。CPU は QEMU の TCG が命令を翻訳して動かすので、読者の PC に特権を1つも求めない。
#
#   build: docker build -t lab-qemu:1.0.0 containers/qemu
FROM lab-linuc-machine:1.0.0
USER root
ARG APT_SNAPSHOT=20260929T000000Z

# ---- 1) 道具を1つ足す --------------------------------------------------------
#   iproute2: 外（コンテナ）で ss -tlnp を打ち、練習機への ssh の入口（127.0.0.1:2222）を
#             待ち受けているのが QEMU のプロセスそのものだと見せる（第5章）。
RUN apt-get update \
 && apt-get install -y --no-install-recommends iproute2 \
 && mandb -q \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin /var/cache/apt/archives/*.deb

# ---- 2) 仮想マシン型の檻の部品のうち、この記事では使わないものを止める ------------
#   土台は「コンテナの起動と同時に libvirt の練習機を用意する」仮想マシン型の檻（ENTRYPOINT が lab-vm-init）。
#   この記事の読者は qemu-system-x86_64 を自分で打つので、起動時の準備も、ログイン時の「練習機 linuc: …」の
#   1行（/etc/profile.d/98-lab-vm.sh）も要らない。libvirt と vm コマンド自体は残す（第7章で、libvirt が
#   組み立てる QEMU のコマンド行を読むのに使う）。
#   PID 1 は tini のままにする（-daemonize で親から離れた QEMU のプロセスを刈り取る）。
RUN rm -f /etc/profile.d/98-lab-vm.sh

COPY --chown=root:root --chmod=0555 lab/ /lab/

LABEL org.opencontainers.image.source=https://github.com/chai0204/check-then-explain
LABEL org.opencontainers.image.description="QEMU（マシン・ディスク・TCG・シリアルとモニタ・ユーザモードネットワーク・ファームウェア・スナップショット）を、qemu-system-x86_64 を直接打って確かめる学習用コンテナ"
LABEL org.opencontainers.image.licenses=MIT
ENV LAB_THEME=qemu LAB_VERSION=1.0.0 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/chai0204/lab:qemu-1.0.0
USER lab
WORKDIR /home/lab
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "-l"]
