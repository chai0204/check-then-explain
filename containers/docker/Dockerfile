# syntax=docker/dockerfile:1.9
# Docker の記事の檻（仮想マシン型）。
#   外側のコンテナ（lab@host）の中で、練習機（student@linuc。Ubuntu 24.04）が起動する。練習機の中には
#   docker.io 29.1.3 と、小さなイメージ2つ（alpine:3.24.2・busybox:1.38.0）が入っている（土台 lab-ctr-machine）。
#   コンテナの中で dockerd を動かすには特権が要るが、仮想マシンの中なら要らない。読者に渡してもらう権限は無い。
#   名前空間・cgroup・overlay・iptables を、本物のカーネルで、全員に同じ画面で確かめる。
#
#   build: docker build -t lab-docker:1.0.0 containers/docker
FROM lab-ctr-machine:1.0.0
USER root
COPY --chown=root:root --chmod=0555 lab/ /lab/
# 練習機の定義: 土台との違いは、外（lab@host）の 127.0.0.1:8080 を練習機の 8080 番へ転送することだけ（第5章）
COPY --chown=root:root --chmod=0644 vm/domain.xml.in /etc/lab-vm/domain.xml.in
LABEL org.opencontainers.image.source=https://github.com/chai0204/check-then-explain
LABEL org.opencontainers.image.description="Docker を仮想マシン（練習機）の中で確かめる学習用コンテナ"
LABEL org.opencontainers.image.licenses=MIT
# LAB_VM_AUTOSTART=1: コンテナを起動すると練習機も起動する（この記事は練習機の中の docker が題材で、起動そのものは扱わない）
ENV LAB_THEME=docker LAB_VERSION=1.0.0 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/chai0204/lab:docker-1.0.0 LAB_VM_AUTOSTART=1
USER lab
