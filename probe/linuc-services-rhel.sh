#!/bin/bash
# 本文で「Red Hat 系では」と書いたところの裏取り（2026-10-13、試験対策の追加）。
# この教材の檻は Ubuntu なので、Red Hat 系の既定は別の場所で確かめる。
# AlmaLinux は RHEL と同じソースから作られた互換のディストリビューションで、パッケージの既定の設定も同じ。
#
#   第3章: chrony の設定ファイルは /etc/chrony.conf、サービス名は chronyd
#   第4章: 一般のログは /var/log/messages（*.info;mail.none;authpriv.none;cron.none）、起動時は /var/log/boot.log（local7）
#   第7章: Red Hat 系の mailx は -S 変数=値 で設定を渡す（-S smtp=… で送り先の SMTP サーバー）
#
# 走らせ方（lab の podman、rootless。スクリプトは標準入力で渡す。イメージはダイジェストで固定）:
#   ssh lab 'podman run --rm -i -e IMG=<イメージ> <イメージ> bash -s' < probe/linuc-services-rhel.sh >> logs/linuc-services-rhel.log
#   <イメージ>:
#     docker.io/library/almalinux@sha256:e6d31b01fca10ed4f914e84e1139c3a40d6acf3d8346224a32f3e5649b1a3f7d   # 8.10
#     docker.io/library/almalinux@sha256:dc973f4dffd28a1e6ae4d1662086d83bac34cd26f3b701e7ba51f4dcb300c80d   # 9.8
# パッケージは dnf がその日のリポジトリから入れる（版は rpm -q の行に出る）。mailx は 8 では Heirloom mailx（パッケージ名 mailx）、
# 9 では s-nail（パッケージ名 s-nail）なので、mailx が無ければ s-nail を入れる。
# R / S の約束は probe/linuc-services-probe.sh と同じ。
set -u
LAST=0
R() {
  local cmd="$1" first=1 line
  while IFS= read -r line; do
    if [ "$first" = 1 ]; then printf '\n$ %s\n' "$line"; first=0
    else printf '> %s\n' "$line"; fi
  done <<< "$cmd"
  (exit "$LAST"); eval "$cmd" 2>&1
  LAST=$?
}
S() { printf '\n\n========== %s ==========\n' "$*"; }

S "環境: ${IMG:-（不明）}"
R 'cat /etc/almalinux-release'
R 'dnf -y -q --setopt=install_weak_deps=False --setopt=tsflags= install rsyslog chrony man-db > /dev/null 2>&1; echo "dnf: exit=$?"'
R 'dnf -y -q --setopt=install_weak_deps=False --setopt=tsflags= install mailx > /dev/null 2>&1 || dnf -y -q --setopt=install_weak_deps=False --setopt=tsflags= install s-nail > /dev/null 2>&1; echo "dnf: exit=$?"'
R 'rpm -q rsyslog chrony; rpm -qf /usr/bin/mailx'

S "第4章: 一般のログは /var/log/messages。起動時のメッセージは /var/log/boot.log"
R "grep -E '/var/log/(messages|secure|maillog|cron|boot\.log)' /etc/rsyslog.conf"

S "第3章: chrony の設定ファイルとサービス名"
R 'ls -l /etc/chrony.conf'
R "grep -E '^(pool|server) ' /etc/chrony.conf"
R "ls /usr/lib/systemd/system/ | grep -E '^chrony'"

S "第7章: mailx の -S（変数=値）で送り先の SMTP サーバーを渡す"
R "man mailx 2>/dev/null | grep -A4 -E '^ +-S '"
R "man mailx 2>/dev/null | grep -A4 -E '^ +(smtp|mta)( |\$)'"
R 'echo x | mailx -S smtp=smtp://127.0.0.1:25 -s test root@localhost; echo "exit=$?"'
