#!/bin/bash
# LinuC 主題1.08 の本文に書いた「RHEL 系との違い」の出どころ（1.0.1 で追加。2026-10-13）。
# 練習機（Ubuntu 24.04）と結果が違うものだけを、AlmaLinux 9.7 のコンテナで打って比べる。
# 事実確認で「Ubuntu の挙動を一般化している」と指摘された箇所（useradd の CREATE_HOME、passwd -S / -l の表示、
# /etc/shadow の権限、cron と at の置き場所と許可ファイル、cron.hourly と anacron の起こし方、run-parts の名前の規則）。
#
# 走らせ方（読者が打つものではない。比較の記録）:
#   docker run --rm -u root -v "$PWD/probe/linuc-admin-rhel-compare.sh:/compare.sh:ro" \
#     almalinux:9.7@sha256:2d57aea965da8fbda97736ec5125c1b683ce271438038ea1906b2391e89b77d2 \
#     bash /compare.sh > logs/linuc-admin-rhel-compare.log 2>&1
# passwd・cronie・crontabs・at はコンテナに入っていないので、最初に dnf で入れる（版は記録の先頭に出す）。
# 入れる先は vault.almalinux.org の 9.7 に固定する（linuc-packages の rpm の檻と同じ）。既定のミラーは
# 9.8 が出た後は 9.8 の版を配るので、取り直すたびに版が変わり、「9.7 の土台に 9.8 のパッケージ」が混ざる。
set -u
R() { printf '\n$ %s\n' "$1"; eval "$1" 2>&1; }
S() { printf '\n\n========== %s ==========\n' "$*"; }
sed -i -E \
  -e 's|^mirrorlist=|#mirrorlist=|' \
  -e 's|^# ?baseurl=https://repo\.almalinux\.org/almalinux/\$releasever/|baseurl=https://vault.almalinux.org/9.7/|' \
  -e 's|^# ?baseurl=https://vault\.almalinux\.org/\$releasever/|baseurl=https://vault.almalinux.org/9.7/|' \
  /etc/yum.repos.d/almalinux-*.repo
dnf -y -q install passwd cronie crontabs at >/dev/null 2>&1

S "0. 版"
R 'cat /etc/almalinux-release'
R 'rpm -q shadow-utils passwd cronie crontabs at'

S "第1章 /etc/shadow の権限"
R 'ls -l /etc/shadow /etc/gshadow'

S "第2章 useradd（CREATE_HOME）"
R "grep -E '^(CREATE_HOME|DEFAULT_HOME|USERGROUPS_ENAB)' /etc/login.defs"
R 'useradd alice'
R 'ls -ld /home/alice'
R "grep '^alice:' /etc/shadow"

S "第4章 passwd -S / passwd -l / usermod -L"
R 'passwd -S alice'
R "echo 'alice:Alice-pass-2026' | chpasswd"
R 'passwd -S alice'
R 'passwd -l alice'
R "grep '^alice:' /etc/shadow | cut -c1-12"
R 'passwd -S alice'
R 'passwd -u alice'
R 'usermod -L alice'
R "grep '^alice:' /etc/shadow | cut -c1-12"

S "第5章・第7章 cron と at の置き場所と許可ファイル（cronie）"
R 'ls -l /etc/cron.allow /etc/cron.deny /etc/at.allow /etc/at.deny'
R 'ls -ld /var/spool/cron /var/spool/at'
R "su -s /bin/bash alice -c 'crontab -l'"
R 'rm /etc/cron.deny'
R "su -s /bin/bash alice -c 'crontab -l'"

S "第6章 cron.hourly と anacron の起こし方、run-parts の名前の規則"
R 'cat /etc/cron.d/0hourly'
R "grep -vE '^#|^\$' /etc/cron.hourly/0anacron | tail -3"
R "grep -vE '^#|^\$' /etc/anacrontab"
R "mkdir -p /tmp/rp && printf '#!/bin/sh\necho hello.sh ran\n' > /tmp/rp/hello.sh && chmod 755 /tmp/rp/hello.sh"
R 'run-parts /tmp/rp'
