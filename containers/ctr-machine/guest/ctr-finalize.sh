#!/usr/bin/env bash
# ctr-customize.sh と student のイメージ取り込みの後に、練習機の中で root として走る。塞いで、片付けて、止める。
set -euxo pipefail

# ---- 1) レジストリに届かないようにする ---------------------------------------
#   使うイメージは練習機のディスクに入っている。読者が取りに行く操作（docker pull・docker run で手元に無い名前）は、
#   読者のネットワークに関係なく全員に同じ失敗（connection refused）を出す。オフラインでも同じ画面になる。
#   /etc/hosts は追記せず丸ごと書く（追記した直後に電源が落ちると NUL が入る。土台の customize.sh と同じ理由）。
cat > /etc/hosts <<'EOF2'
127.0.0.1 localhost
127.0.1.1 linuc

# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts

# docker / podman の記事: この練習機からコンテナのレジストリ（Docker Hub）へは届かないようにしてある。
# 使うイメージ（alpine:3.24.2・busybox:1.38.0）はディスクに入れてあり、取りに行く操作は全員に同じ失敗を出す。
0.0.0.0 registry-1.docker.io auth.docker.io index.docker.io production.cloudflare.docker.com
EOF2

# ---- 2) 片付け（ディスクを小さくする） ---------------------------------------
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin
journalctl --rotate && journalctl --vacuum-time=1s || true
find /var/log -type f -name '*.gz' -delete
find /var/log -type f -exec truncate -s0 {} + || true
rm -rf /tmp/ctr-build /var/tmp/*
rm -f /home/student/.bash_history /root/.bash_history
fstrim -av || true
sync
systemctl poweroff
