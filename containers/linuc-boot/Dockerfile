# syntax=docker/dockerfile:1.9
# LinuC 主題1.01（インストールと仮想マシン・コンテナ／ブートと systemd／プロセス）の檻。
#   外側のコンテナ（lab@host）の中で、練習機（student@linuc）を読者が自分で virsh start する。
#   電源・GRUB・ブートターゲット・停止・ssh の鍵・シグナルを、本物のカーネルと systemd で確かめる。
#
#   build: docker build -t lab-linuc-boot:1.0.1 containers/linuc-boot
FROM lab-linuc-machine:1.0.0
USER root

# ---- 1) ssh は「鍵を作るところ」から読者にやらせる（1.01.1） -------------------
#   土台は外から練習機に入る鍵と known_hosts を入れてあるが、このコースでは外す。
#   ssh の設定からも IdentityFile を外し、ssh 自身に既定の名前（id_rsa / id_ed25519 …）を探させる。
#   練習機の側（パスワード認証を許す・authorized_keys を空にする）は初回の provision.sh が行う。
RUN rm -f /home/lab/.ssh/id_ed25519 /home/lab/.ssh/id_ed25519.pub /home/lab/.ssh/known_hosts
COPY --chown=lab:lab --chmod=0644 etc/ssh_config /home/lab/.ssh/config

# ---- 2) 演習と、初回の準備 -----------------------------------------------------
COPY --chown=root:root --chmod=0555 lab/ /lab/
COPY --chown=root:root --chmod=0644 vm/provision.sh /etc/lab-vm/provision.sh

LABEL org.opencontainers.image.source=https://github.com/chai0204/check-then-explain
LABEL org.opencontainers.image.description="LinuC 主題1.01（起動・仮想マシン・コンテナ・プロセス）を仮想マシンで確かめる学習用コンテナ"
LABEL org.opencontainers.image.licenses=MIT

# LAB_VM_AUTOSTART=0: 練習機の電源は読者が入れる（virsh start そのものが 1.01.2 の題材）
ENV LAB_THEME=linuc-boot LAB_VERSION=1.0.1 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/chai0204/lab-linuc:boot-1.0.1 LAB_VM_AUTOSTART=0
USER lab
