#!/bin/bash
# LinuC 主題1.01 の本文に書いた「Ubuntu だけの振る舞い」の出どころ（1.0.1 で追加。2026-10-13）。
# 事実確認で、練習機（Ubuntu 24.04）の結果を一般化していると指摘された2つを、AlmaLinux 9.7 のコンテナで打って比べる。
#   - 第2章: authorized_keys が group に書けるとき。Ubuntu（Debian）の sshd は「グループのメンバーが本人だけなら許す」改造を持つ。
#   - 第6章: root がロックされているときの sulogin。Ubuntu の util-linux は「聞かずに通す」改造を持つ。
#
# 走らせ方（読者が打つものではない。比較の記録）:
#   docker run --rm -u root -v "$PWD/probe/linuc-boot-rhel-compare.sh:/compare.sh:ro" \
#     almalinux:9.7@sha256:2d57aea965da8fbda97736ec5125c1b683ce271438038ea1906b2391e89b77d2 \
#     bash /compare.sh > logs/linuc-boot-rhel-compare.log 2>&1
# openssh-server と openssh-clients は vault.almalinux.org の 9.7 から入れる（linuc-admin の比較と同じ固定）。
set -u
R() { printf '\n$ %s\n' "$1"; eval "$1" 2>&1; }
S() { printf '\n\n========== %s ==========\n' "$*"; }
sed -i -E \
  -e 's|^mirrorlist=|#mirrorlist=|' \
  -e 's|^# ?baseurl=https://repo\.almalinux\.org/almalinux/\$releasever/|baseurl=https://vault.almalinux.org/9.7/|' \
  -e 's|^# ?baseurl=https://vault\.almalinux\.org/\$releasever/|baseurl=https://vault.almalinux.org/9.7/|' \
  /etc/yum.repos.d/almalinux-*.repo
dnf -y -q install openssh-server openssh-clients >/dev/null 2>&1
ssh-keygen -A >/dev/null 2>&1

S "0. 版"
R 'cat /etc/almalinux-release'
R 'rpm -q openssh-server openssh-clients util-linux'

S "第2章 authorized_keys が group に書けるとき（本家に近い OpenSSH）"
R 'useradd -m alice'
R "su - alice -c 'ssh-keygen -q -t ed25519 -N \"\" -f ~/.ssh/id_ed25519 && cp ~/.ssh/id_ed25519.pub ~/.ssh/authorized_keys'"
R 'chmod 664 /home/alice/.ssh/authorized_keys; ls -l /home/alice/.ssh/authorized_keys; getent group alice'
/usr/sbin/sshd -E /tmp/sshd.log; sleep 1
R "su - alice -c 'ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes localhost true'; echo \"終了コード \$?\""
R "grep 'Authentication refused' /tmp/sshd.log"
R 'chmod 600 /home/alice/.ssh/authorized_keys'
R "su - alice -c 'ssh -o BatchMode=yes localhost echo 鍵で入れた'"

S "第6章 root がロックされているときの sulogin（本家の util-linux）"
R "grep '^root:' /etc/shadow | cut -d: -f1,2"
R 'script -qec sulogin /dev/null < /dev/null'
