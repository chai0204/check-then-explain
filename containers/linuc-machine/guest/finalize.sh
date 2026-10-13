#!/usr/bin/env bash
# customize.sh の後に練習機の中で root として走る。片付けて停止する。
set -euxo pipefail
# ---- 9) 片付け（ディスクを小さくする） ---------------------------------------
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin /tmp/pkgs
journalctl --rotate && journalctl --vacuum-time=1s || true
find /var/log -type f -name '*.gz' -delete
find /var/log -type f -exec truncate -s0 {} + || true
cloud-init clean --logs || true
rm -rf /tmp/lab-build /var/tmp/*
rm -f /home/student/.bash_history /root/.bash_history
fstrim -av || true
sync
systemctl poweroff
