# syntax=docker/dockerfile:1.9
# LinuC 主題1.07（ネットワークの基礎）の檻。仮想マシン型（lab-linuc-machine の上に載せる）。
#
#   - 練習機に練習用の NIC を2枚足す（vm/domain.xml.in）。enp0s17 は ifupdown、enp0s18 は NetworkManager の練習台
#   - 練習機の中に network namespace で「社内 LAN」を作る（vm/provision.sh）:
#       スイッチ・ルータ・撤去予定の旧ルータ・サーバ（DNS は dnsmasq、HTTP は ncat）
#   経路も DNS も相手のサーバも全部練習機の中にあるので、読者の家・会社のプロキシ・オフラインで画面が変わらない。
#   管理用の NIC（enp0s16）からは、デフォルトルートと DNS を受け取らないようにしてある（同じ理由）。
FROM lab-linuc-machine:1.0.0
USER root
COPY --chown=root:root --chmod=0555 lab/ /lab/
COPY --chown=root:root --chmod=0644 vm/domain.xml.in /etc/lab-vm/domain.xml.in
COPY --chown=root:root --chmod=0644 vm/provision.sh /etc/lab-vm/provision.sh
LABEL org.opencontainers.image.source=https://github.com/chai0204/check-then-explain
LABEL org.opencontainers.image.description="LinuC 主題1.07（ネットワークの基礎）を仮想マシンで確かめる学習用コンテナ"
LABEL org.opencontainers.image.licenses=MIT
# ---- lab コマンドを最新にする（1.0.2、2026-10-20）--------------------
#   lab の正本は containers/base/bin/lab。土台（lab-base）から作り直すと上の層が全部作り直しになり、
#   本文の記録とずれうるので、最新の lab をここで重ねる。これより前の層は 1.0.1 とキャッシュで同一。
#   build: docker build --build-context labcmd=containers/base -t lab-linuc-network:<版> containers/linuc-network
COPY --from=labcmd --chown=root:root --chmod=0755 bin/lab /usr/local/bin/lab
ENV LAB_THEME=linuc-network LAB_VERSION=1.0.2 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/chai0204/lab-linuc:network-1.0.2 LAB_VM_AUTOSTART=1
ENV LAB_RESET_HINT="元に戻すには、練習機の外で vm reset --yes（練習機ごと最初の状態に戻ります）"
USER lab
