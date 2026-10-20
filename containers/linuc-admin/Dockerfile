# syntax=docker/dockerfile:1.9
# LinuC 主題1.08（システム管理）の檻。練習機（仮想マシン）の中で、ユーザとグループを作って消し、
# cron・at・anacron にジョブを渡し、ロケールを生成する。どれも /etc とスプールを書き換える管理作業である。
# コンテナではなく仮想マシンにしたのは、cron・atd・anacron が systemd の下で本物の時刻どおりに動き、
# 「ロックしたユーザが ssh で本当に入れないか」を sshd と PAM を通して確かめられるため。
#   build: docker build -t lab-linuc-admin:1.0.0 containers/linuc-admin
FROM lab-linuc-machine:1.0.0
USER root
COPY --chown=root:root --chmod=0555 lab/ /lab/
# 初回の vm start で1回だけ、練習機の中で root として走る（演習の相手のユーザと、演習用のファイルを置く）
COPY --chown=root:root --chmod=0644 vm/provision.sh /etc/lab-vm/provision.sh
LABEL org.opencontainers.image.source=https://github.com/chai0204/check-then-explain
LABEL org.opencontainers.image.description="LinuC 主題1.08（アカウント管理・ジョブスケジューリング・ローカライゼーション）を仮想マシンで確かめる学習用コンテナ"
LABEL org.opencontainers.image.licenses=MIT
# ---- lab コマンドを最新にする（1.0.2、2026-10-20）--------------------
#   lab の正本は containers/base/bin/lab。土台（lab-base）から作り直すと上の層が全部作り直しになり、
#   本文の記録とずれうるので、最新の lab をここで重ねる。これより前の層は 1.0.1 とキャッシュで同一。
#   build: docker build --build-context labcmd=containers/base -t lab-linuc-admin:<版> containers/linuc-admin
COPY --from=labcmd --chown=root:root --chmod=0755 bin/lab /usr/local/bin/lab
ENV LAB_THEME=linuc-admin LAB_VERSION=1.0.2 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/chai0204/lab-linuc:admin-1.0.2 LAB_VM_AUTOSTART=1
ENV LAB_RESET_HINT="元に戻すには、練習機の外で vm reset --yes（練習機ごと最初の状態に戻ります）"
USER lab
