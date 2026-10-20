# syntax=docker/dockerfile:1.9
# LinuC 主題1.10（セキュリティ）を仮想マシンで確かめる学習用コンテナ。
#   外側のコンテナの中で QEMU が練習機（Ubuntu 24.04）を1台動かす。
#   この主題は「練習機を壊して自分を締め出す」操作（/etc/nologin・ファイアウォール）を扱う。
#   壊しても、判定は qemu-guest-agent 経由の lab-guest で動き、vm reset --yes で工場出荷時に戻せる。
#
#   build: docker build --build-context labcmd=containers/base --build-context labvm=containers/linuc-machine/host -t lab-linuc-security:1.0.2 containers/linuc-security
FROM lab-linuc-machine:1.0.0
USER root

# 演習（/lab）。root 所有・読み取りのみ（読者が答えを書き換えられない）。
COPY --chown=root:root --chmod=0555 lab/ /lab/

# 初回の vm start で1回だけ練習機の中で root として走る準備。
#   - 監査の的になる SUID バイナリを1つ仕込む（演習01）
#   - 止めるべき余計な待ち受けを1つ立てる（演習03）
#   - 無効化する古いアカウントと、sudo を絞る相手を作る（演習02・04）
COPY --chown=root:root --chmod=0644 vm/provision.sh /etc/lab-vm/provision.sh

LABEL org.opencontainers.image.source=https://github.com/chai0204/check-then-explain
LABEL org.opencontainers.image.description="LinuC 主題1.10（セキュリティ）を仮想マシンで確かめる学習用コンテナ"
LABEL org.opencontainers.image.licenses=MIT
# ---- lab コマンドを最新にする（1.0.2、2026-10-20）--------------------
#   lab の正本は containers/base/bin/lab。土台（lab-base）から作り直すと上の層が全部作り直しになり、
#   本文の記録とずれうるので、最新の lab をここで重ねる。これより前の層は 1.0.1 とキャッシュで同一。
#   build: docker build --build-context labcmd=containers/base --build-context labvm=containers/linuc-machine/host -t lab-linuc-security:<版> containers/linuc-security
COPY --from=labcmd --chown=root:root --chmod=0755 bin/lab /usr/local/bin/lab
#   練習機の中の lab が外の lab に頼む中継（lab-remote）も最新にする（lab show を通すため）。
#   build には --build-context labvm=containers/linuc-machine/host も付ける。
COPY --from=labvm --chown=root:root --chmod=0755 libexec/lab-remote /usr/local/libexec/lab-remote
ENV LAB_THEME=linuc-security LAB_VERSION=1.0.2 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/chai0204/lab-linuc:security-1.0.2 LAB_VM_AUTOSTART=1
ENV LAB_RESET_HINT="元に戻すには、練習機の外で vm reset --yes（練習機ごと最初の状態に戻ります）"
USER lab
