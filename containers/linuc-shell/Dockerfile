# syntax=docker/dockerfile:1.9
# LinuC 主題1.06（シェルおよびスクリプト）用の檻。
# 読者 lab のほかに alice と bob を置く。どの起動ファイルがいつ読まれるかを、
# 自分以外のユーザで実測するため（自分の ~/.bashrc を壊すと、その端末ごと使えなくなる）。
#   build: docker build -t lab-linuc-shell:1.0.2 containers/linuc-shell
#   1.0.1（2026-10-13）: 演習のヒントと模範解答の誤り（~/.bashrc を読むシェル・コマンドを探す順・
#   dash の function の読み方ほか）を直した。lab/ の層だけが 1.0.0 と違う（useradd の層はキャッシュで同一）。
#   1.0.2（2026-10-13）: 配布ファイル（seed）を 0755 にする層を足した。lab reset の後に演習のスクリプトを
#   直して保存できなかった不具合の修正。それより下の層は 1.0.1 とキャッシュで同一。
FROM lab-linuc-base:1.0.0
USER root

# ---- 1) 実験相手のユーザ ----------------------------------------------------
#   追加のパッケージは要らない。bash・dash・su・sudo・script（疑似端末）は
#   lab-linuc-base にすべて入っている（実測 2026-10-13）。
#
#   -s /bin/bash を明示する。Ubuntu の useradd の既定は /etc/default/useradd の
#   SHELL=/bin/sh（dash）で、そのままだとログインしても ~/.profile しか読まれず、
#   ~/.bashrc も ~/.bash_profile も読まれない（実測 2026-10-13: carol で確認）。
#
#   alice: 第1章で起動ファイルに印を仕込む相手。su - alice を見せるために
#          パスワードを固定する（学習用の檻なので固定でよい。パスワードは alice）。
#   bob  : 演習01 の相手。前任者が ~/.bash_profile を置いた状態から始める。
#          このファイルがあると ~/.profile が読まれなくなる、というのが演習の芯。
RUN useradd -m -s /bin/bash alice \
 && echo 'alice:alice' | chpasswd \
 && useradd -m -s /bin/bash bob \
 && printf '%s\n' \
      '# ~/.bash_profile — 前任者が置いた設定' \
      'export EDITOR=vim' \
    > /home/bob/.bash_profile \
 && chown bob:bob /home/bob/.bash_profile \
 && chmod 0644 /home/bob/.bash_profile

# ---- 2) 教材資産。root 所有・読み取りのみ ----------------------------------
COPY --chown=root:root --chmod=0555 lab/ /lab/
#   配布ファイル（seed）だけは 0755 にする。root 所有なので、読者が元を書き換えられないのは同じ。
#   0555 のままだと、lab reset が cp -r で写した ~/work/NN のファイルと下のディレクトリが読み取り専用になる
#   （lab start は写した後に chmod u+w するが、lab reset はしない）。1.0.1 で実測: lab reset 06 の後の
#   menu.sh が -r-xr-xr-x になり、追記が Permission denied。~/work/07/logs も dr-xr-xr-x（2026-10-13）。
#   主題1.03（linuc-text）と同じ直し方。
COPY --chown=root:root --chmod=0755 lab/seed/ /lab/seed/

LABEL org.opencontainers.image.source=https://github.com/chai0204/check-then-explain
LABEL org.opencontainers.image.description="LinuC 主題1.06（シェルおよびスクリプト）を手で確かめる学習用コンテナ"
LABEL org.opencontainers.image.licenses=MIT

ENV LAB_THEME=linuc-shell LAB_VERSION=1.0.2 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/chai0204/lab-linuc:shell-1.0.2
USER lab
WORKDIR /home/lab
# ログインシェルで起動する。入口の案内（/etc/profile.d/99-lab.sh）が出るのはこのため。
# 第1章は、この1行が何を引き起こしているかを読み解くところから始まる。
CMD ["/bin/bash", "-l"]
