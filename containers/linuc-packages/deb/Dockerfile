# syntax=docker/dockerfile:1.9
# LinuC 主題1.04（リポジトリとパッケージ管理）の Debian 系の檻。
# apt / apt-get / apt-cache / apt-file / dpkg / dpkg-deb / dpkg-reconfigure を、本物のパッケージ管理の上で確かめる。
# 演習の対象は自作の小さな .deb（依存関係つき）で、檻の中の file: リポジトリから入れる。ネットが無くても結果は同じ。
#   build: docker build --build-context labcmd=containers/base -t lab-linuc-packages-deb:1.1.0 containers/linuc-packages/deb

# ---- build ステージ: 自作パッケージとリポジトリを作る -----------------------
#   索引（Packages / Contents / Release）は apt-ftparchive（apt-utils）で作る。作業用のツリーは檻に入れない。
FROM lab-linuc-base:1.0.0 AS build
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends apt-utils \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin /var/cache/apt/archives/*.deb
COPY pkgs/ /build/pkgs/
COPY build-repos.sh /build/build-repos.sh
RUN bash /build/build-repos.sh

# ---- 読者の檻 ---------------------------------------------------------------
FROM lab-linuc-base:1.0.0
USER root
ARG APT_SNAPSHOT=20260929T000000Z
COPY --from=build /srv/ /srv/
COPY --chown=root:root --chmod=0644 etc/60lab-apt-file /etc/apt/apt.conf.d/60lab-apt-file

# 1) 檻の中のリポジトリ（スイート lab だけ）を apt のソースに足す。sources.list の1行形式で書くのは、
#    試験が問うのがこの形式だから（Ubuntu の分は sources.list.d/ubuntu.sources の deb822 形式のまま）。
#    スイート lab-updates（labhello 1.1）は足さない。第6章で読者が足す。
# 2) apt-file を入れて、もう一度 apt-get update する（apt-file の索引 Contents は2回目で取れる）。
#    apt-utils も入れる。無いと apt で入れるたびに「debconf: delaying package configuration,
#    since apt-utils is not installed」が出る（実測）。実機の Ubuntu には最初から入っている。
#    whiptail も同じ理由（debconf が質問の画面を出すのに使う。無いと dpkg-reconfigure が
#    「unable to initialize frontend: Dialog」と言って文字だけの画面に落ちる）。
# 3) Ubuntu のパッケージを snapshot の時刻の版まで上げる（apt-get upgrade）。
#    上げないと、土台を作った時点より snapshot のほうが新しいもの（libaudit1 など）が
#    apt list --upgradable に並び、第6章の apt upgrade がネットから取りに行こうとする（1.0.1 で実測）。
# 4) 演習と本文の初期状態を作る（labhello は入れない。第1章と演習01 で読者が入れる）:
#      labfortune … 分類（Section）が games のパッケージ。演習02 で読者が見つけて消す
#      labsvc     … 依存の labsvc-common が「自動で入った」印つきで入る。演習03 で読者が設定ファイルを探して書き換える
#      labbackup  … 入れたあとで /usr/bin/labbackup を消しておく。台帳は「入っている」のまま（演習04）
#      labweb     … 依存の labweb-data が「自動で入った」印つきで入る。演習05 で読者が跡形なく消す
#                   （演習03 と別のパッケージにするのは、演習05 で消したあとに lab check を全部打っても、
#                     演習02・03 の判定が前提を失わないようにするため）
#
#    目録（/var/lib/apt/lists）は消さずに残す。ネットにつながっていない読者でも
#    apt-cache show / policy / depends が本物のパッケージに対して同じ結果を返すようにするため
#    （snapshot は動かないので、残した目録は古くならない）。増分は約 44MB（実測）。
#    /var/cache/apt/*.bin は消す（apt が毎回作り直せるキャッシュで、残すと約 97MB）。
RUN printf '%s\n' \
      '' \
      '# 檻の中の練習用リポジトリ（確かめて説明する LinuC 主題1.04）。' \
      '# 署名していないので [trusted=yes] で署名の確認を外している。本物のリポジトリでは外さない。' \
      'deb [trusted=yes] file:/srv/lab-repo lab main' \
    >> /etc/apt/sources.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends apt-file apt-utils whiptail \
 && apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends labfortune labsvc labbackup labweb \
 && rm /usr/bin/labbackup \
 && mandb -q \
 && rm -rf /var/cache/apt/*.bin /var/cache/apt/archives/*.deb /var/cache/debconf/*-old

COPY --chown=root:root --chmod=0555 lab/ /lab/
# 演習07 の配布物（リポジトリに無い単体の .deb）。lab/ の後に置く。
# 先に置くと、--chmod=0444 が途中に作られる /lab 自体にも付き、lab ユーザが /lab を読めなくなる（実測）。
COPY --from=build --chown=root:root --chmod=0444 /out/labnote_1.0_all.deb /lab/seed/07/labnote_1.0_all.deb
LABEL org.opencontainers.image.source=https://github.com/chai0204/check-then-explain
LABEL org.opencontainers.image.description="LinuC 主題1.04（apt・dpkg・apt-file）を Debian 系で手で確かめる学習用コンテナ"
LABEL org.opencontainers.image.licenses=MIT
# ---- lab コマンドを最新にする（次の版、2026-10-20）--------------------
#   LAB_ELSEWHERE は、この檻に無い演習の番号（09〜12）を打たれたときに lab が出す、もう一方の檻の案内。
#   lab の正本は containers/base/bin/lab。土台（lab-base）から作り直すと上の層が全部作り直しになり、
#   本文の記録とずれうるので、最新の lab をここで重ねる。
#   build: docker build --build-context labcmd=containers/base -t lab-linuc-packages-deb:<版> containers/linuc-packages/deb
COPY --from=labcmd --chown=root:root --chmod=0755 bin/lab /usr/local/bin/lab
ENV LAB_THEME=linuc-packages-deb LAB_VERSION=1.1.0 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/chai0204/lab-linuc:packages-deb-1.1.0 \
    LAB_ELSEWHERE="09〜12 は RPM 系の檻で打ちます（実践編「はじめる」の2つ目の起動コマンド）"
USER lab
WORKDIR /home/lab
CMD ["/bin/bash", "-l"]
