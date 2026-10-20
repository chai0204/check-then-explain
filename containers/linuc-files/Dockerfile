# syntax=docker/dockerfile:1.9
# LinuC 主題1.02（ファイル・ディレクトリの操作と管理）の檻。
# パーミッションは「誰として触るか」で結果が変わる。読者は一般ユーザ lab で作業し、
# 他人の立場（alice / bob / carol）と root の立場は sudo で借りる。人を複数置くのがこの檻の芯。
FROM lab-linuc-base:1.0.0
USER root
ARG APT_SNAPSHOT=20260929T000000Z

# ---- 1) 主題1.02 が名指しするコマンドのうち、ベースに無いもの ----------------
#   bzip2 / xz-utils : tar の j / J と、単体の bzip2 / xz（ベースには gzip しか無い。実測 2026-10-13）
#   plocate          : locate / updatedb と /etc/updatedb.conf
RUN apt-get update \
 && apt-get install -y --no-install-recommends bzip2 xz-utils plocate \
 && mandb -q \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin /var/cache/apt/archives/*.deb

# ---- 2) パーミッションの相手役 ----------------------------------------------
#   alice と bob はグループ devs の仲間、carol は部外者。読者 lab はどこにも入れない
#   （一般ユーザが chgrp できるのは自分の属するグループだけ、を見せるため）。
#   アカウント管理そのものは主題1.08 の範囲なので、ここで先に作っておく。
RUN groupadd devs \
 && useradd -m -s /bin/bash -G devs alice \
 && useradd -m -s /bin/bash -G devs bob \
 && useradd -m -s /bin/bash carol

COPY --chown=root:root --chmod=0555 lab/ /lab/
# 配布ファイル（seed）だけは、ファイル 0644・ディレクトリ 0755 にしておく（root 所有のまま）。
#   - 0555 のままだと、lab start（cp して u+w を足す）で設定ファイルやログまで -rwxr-xr-x で配られる。
#     権限そのものを教える主題で、意味の無い x を見せたくない。
#   - lab reset は cp するだけで u+w を足さない。seed が 0444/0555 だと、やり直した ~/work/NN が
#     読み取り専用になり、演習04〜07 が書き込めずに止まる（他コースで実測され共有された 2026-10-13）。
#     0644/0755 なら cp の結果がそのまま 0644/0755（umask 022）になり、start でも reset でも同じになる。
RUN find /lab/seed -type f -exec chmod 0644 {} + \
 && find /lab/seed -mindepth 1 -type d -exec chmod 0755 {} +

# ---- 3) locate の索引を作っておく ------------------------------------------
#   実機では plocate-updatedb.timer（または cron.daily）が毎日作り直す。
#   コンテナではタイマーが動かないので、ビルドした時点の索引が残り続ける。
#   「索引は作った時点の写真」であることが第8章と演習08 の材料になる。
RUN updatedb

LABEL org.opencontainers.image.source=https://github.com/chai0204/check-then-explain
LABEL org.opencontainers.image.description="LinuC 主題1.02（ファイル・ディレクトリの操作と管理）を手で確かめる学習用コンテナ"
LABEL org.opencontainers.image.licenses=MIT
# ---- lab コマンドを最新にする（1.0.2、2026-10-20）--------------------
#   lab の正本は containers/base/bin/lab。土台（lab-base）から作り直すと上の層が全部作り直しになり、
#   本文の記録とずれうるので、最新の lab をここで重ねる。これより前の層は 1.0.1 とキャッシュで同一。
#   build: docker build --build-context labcmd=containers/base -t lab-linuc-files:<版> containers/linuc-files
COPY --from=labcmd --chown=root:root --chmod=0755 bin/lab /usr/local/bin/lab
ENV LAB_THEME=linuc-files LAB_VERSION=1.0.2 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/chai0204/lab-linuc:files-1.0.2
USER lab
WORKDIR /home/lab
CMD ["/bin/bash", "-l"]
