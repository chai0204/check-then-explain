# syntax=docker/dockerfile:1.9
# LinuC 主題1.09（重要なシステムサービス）用の檻。
#
# 他テーマと違い PID 1 が systemd である。journalctl / timedatectl / systemctl は
# systemd が動いていないと1つも試せず、この主題はまるごと成立しない（実測 2026-10-12）。
FROM lab-base:1.0.0
USER root
ARG APT_SNAPSHOT=20260929T000000Z

# ---- 1) systemd 本体 -------------------------------------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends systemd systemd-sysv dbus \
 && rm -rf /var/lib/apt/lists/*

# ---- 2) 主題1.09 の対象（時刻・ログ・メール） -------------------------------
#   chrony と ntpsec は両方が Provides: time-daemon かつ Conflicts: time-daemon で、
#   同時には入らない（実測 2026-10-12）。試験範囲に ntpd と chronyd が並ぶのに
#   実機には片方しか無いのはこれが理由。現行 Ubuntu の既定である chrony を採る。
#   ntpdate は別パッケージなので共存できる。hwclock は util-linux-extra 側にある。
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      rsyslog chrony ntpsec-ntpdate logrotate util-linux-extra \
 && rm -rf /var/lib/apt/lists/*

# ---- 2b) postfix は「設定なし」で入れ、設定をこちらで書く -------------------
#   既定の postinst は newaliases を呼び、ホスト名の FQDN を
#   **ビルドマシンの DNS サーチドメイン**から組む。手元では ISP 由来の名前に
#   不正な文字が入り valid_hostname が落ちて exit 75 になった（実測 2026-10-12）。
#   つまり既定の経路はビルド環境ごとに結果が変わる。再現性のため自分で書く。
RUN echo 'postfix postfix/main_mailer_type select No configuration' | debconf-set-selections \
 && apt-get update \
 && apt-get install -y --no-install-recommends postfix bsd-mailx \
 && cp /usr/share/postfix/main.cf.debian /etc/postfix/main.cf \
 && cp /usr/share/postfix/master.cf.dist /etc/postfix/master.cf \
 && postconf -e 'myhostname = lab.local' 'mydomain = lab.local' 'myorigin = $myhostname' \
      'inet_interfaces = loopback-only' 'inet_protocols = ipv4' \
      'mydestination = $myhostname, localhost.$mydomain, localhost' \
      'alias_maps = hash:/etc/aliases' 'alias_database = hash:/etc/aliases' \
      'compatibility_level = 3.8' \
 && printf 'postmaster: root\n' > /etc/aliases \
 && newaliases \
 && postfix set-permissions \
 && postfix check \
 && rm -rf /var/lib/apt/lists/*

# ---- 2c) man を復元する（LinuC は man が読めないと成立しない） ---------------
#   base は dpkg の path-exclude を外してから入れたパッケージの man だけを持つ。
#   util-linux / bsdutils はベースイメージに最初から入っていたため man が無く、
#   `man 1 logger` が「No manual entry」になった（実測 2026-10-12）。入れ直す。
RUN apt-get update \
 && apt-get install -y --reinstall --no-install-recommends util-linux bsdutils \
 && mandb -q \
 && rm -rf /var/lib/apt/lists/* /var/cache/man/*

# ---- 3) コンテナで意味を持たないユニットを外す -----------------------------
#   残すと起動時に赤い failed が並び、読者が「自分が壊した」と誤解する。
#   外した理由は本文の第1章で説明する（檻の限界そのものが教材になる）。
RUN systemctl mask \
      systemd-udevd.service systemd-udev-trigger.service systemd-modules-load.service \
      sys-kernel-debug.mount sys-kernel-tracing.mount systemd-hwdb-update.service \
 && systemctl enable rsyslog.service chrony.service postfix.service

# ---- 4) 演習用のローカル NTP サーバ ----------------------------------------
# ---- 4a) chrony の既定のソースを外す（再現性のため） ----------------------
#   Ubuntu の既定は `pool ntp.ubuntu.com`。インターネットに出られる読者と出られない
#   読者で chronyc の出力が完全に変わり、「同じ画面が出る」が壊れる。
#   実測（2026-10-12）では手元は 208.88.66.8 に stratum 3 で同期してしまった。
#   ソースを0本にしておくと、どの環境でも Not synchronised から始まる。
#   読者はここに檻の中の基準サーバを自分で足す（演習02）。
RUN sed -i 's/^pool /#pool /' /etc/chrony/chrony.conf \
 && printf '\n# この教材では既定の pool を外してある（理由は第3章）。\n' >> /etc/chrony/chrony.conf

COPY --chown=root:root --chmod=0644 etc/lab-ntp-server.conf /etc/chrony/lab-ntp-server.conf
COPY --chown=root:root --chmod=0644 etc/lab-ntp-server.service /etc/systemd/system/lab-ntp-server.service
RUN systemctl enable lab-ntp-server.service \
 && printf 'DAEMON_OPTS="-F -1 -x"\n' > /etc/default/chrony

# ---- 4b) 演習06 用のユーザ。アカウント管理は主題1.08 の範囲なので先に作る ----
RUN useradd -m alice && useradd -m bob \
 && install -d -o root -g mail -m 2775 /var/mail

# ---- 5) 教材資産。root 所有・読み取りのみ ----------------------------------
COPY --chown=root:root --chmod=0555 lab/ /lab/

# ---- 6) 進捗と作業の置き場（root の HOME 配下） ----------------------------
RUN install -d -o root -g root -m 0755 /root/.lab /root/work

COPY --chown=root:root --chmod=0755 bin/lab-init /usr/local/sbin/lab-init

# リポジトリとの紐付け。GHCR の可視性は継承しないので、公開は手動で切り替える。
LABEL org.opencontainers.image.source=https://github.com/chai0204/check-then-explain
LABEL org.opencontainers.image.description="LinuC 主題1.09（時刻・ログ・メール）を実機で確かめる学習用コンテナ"
LABEL org.opencontainers.image.licenses=MIT

# 1.0.1（2026-10-13）: 全問クリア時の案内のパスを実在するもの（/linuc-services/…）に直し、
#   演習05・06 のヒントと模範解答を docker exec（umask 0000）と podman exec（umask 0022）の
#   どちらで入った読者にも正しい書き方にした。設定とパッケージは 1.0.0 と同じ。
# 1.0.2（2026-10-13）: 事実確認に合わせて演習の文面（lab/）だけを直した。
#   chronyd が時計を動かさないのは -x のため / rsyslog は journald から回された分を受け取る /
#   .forward が拒否されるのは world writable のときだけ / journald の上限の行の実物、など。
ENV LAB_THEME=linuc-services LAB_VERSION=1.0.2 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/chai0204/lab-linuc-services:1.0.2
WORKDIR /root
# systemd の停止は SIGRTMIN+3。SIGTERM だと 10 秒待たされて強制 kill になる。
STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/usr/local/sbin/lab-init"]
