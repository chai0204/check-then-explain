# syntax=docker/dockerfile:1.9
# Podman の記事の檻（仮想マシン型）。
#   外側のコンテナ（lab@host）の中で、練習機（student@linuc。Ubuntu 24.04）が起動する。練習機の中には
#   podman 4.9.3（rootless の道具一式）と、小さなイメージ2つ（alpine:3.24.2・busybox:1.38.0。student の置き場所）が入っている
#   （土台 lab-ctr-machine。docker の記事と同じディスク）。この檻では docker のデーモンを止めておく（初回の準備）。
#   rootless のユーザ名前空間・/etc/subuid・pasta と slirp4netns・systemd との統合を、本物のカーネルで確かめる。
#   読者に渡してもらう権限は無い。
#
#   build: docker build --build-context labcmd=containers/base -t lab-podman:1.0.1 containers/podman
FROM lab-ctr-machine:1.0.0
USER root
COPY --chown=root:root --chmod=0555 lab/ /lab/
COPY --chown=root:root --chmod=0644 vm/provision.sh /etc/lab-vm/provision.sh
LABEL org.opencontainers.image.source=https://github.com/chai0204/check-then-explain
LABEL org.opencontainers.image.description="Podman を仮想マシン（練習機）の中で確かめる学習用コンテナ"
LABEL org.opencontainers.image.licenses=MIT
# LAB_VM_AUTOSTART=1: コンテナを起動すると練習機も起動する（この記事は練習機の中の podman が題材）
# ---- lab コマンドを最新にする（1.0.1、2026-10-20）--------------------
#   lab の正本は containers/base/bin/lab。土台（lab-base）から作り直すと上の層が全部作り直しになり、
#   本文の記録とずれうるので、最新の lab をここで重ねる。これより前の層は 1.0.0 とキャッシュで同一。
#   build: docker build --build-context labcmd=containers/base -t lab-podman:<版> containers/podman
COPY --from=labcmd --chown=root:root --chmod=0755 bin/lab /usr/local/bin/lab
ENV LAB_THEME=podman LAB_VERSION=1.0.1 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/chai0204/lab:podman-1.0.1 LAB_VM_AUTOSTART=1
ENV LAB_RESET_HINT="元に戻すには、練習機の外で vm reset --yes（練習機ごと最初の状態に戻ります）"
USER lab
