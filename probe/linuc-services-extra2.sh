#!/bin/bash
# 事実確認（2026-10-13）で直した地の文の裏取り。章の流れ（probe/linuc-services-probe.sh）に混ぜると
# 状態が変わってしまうもの・本文の端末表示には出さないものを、別の新しい檻でまとめて確かめる。
#
#   第2章: Asia/Tokyo の9件の切り替えの内訳 / /etc/localtime がコピーのときの読まれ方
#   第3章: chronyd が時計を動かさないのは -x のため（Ubuntu の既定とコンテナでの扱い）/
#          ntpsec の設定ファイルの場所 / クライアントの chronyd は 123 番で待ち受けない /
#          systemd-timesyncd も time-daemon で排他
#   第4章: rsyslog は既定で書くたびの同期をしない / リモート転送の @ と @@
#   第5章: 99- で始まる名前では ForwardToSyslog=no が効かない / systemd-cat が付けられるラベル /
#          /var/log/journal が無い環境での永続化（journalctl --flush と journald の再起動）
#   第6章: su root adm を logrotate.conf に書いているのは Ubuntu の変更
#   第7章: newaliases は sendmail 互換の別名 / .forward は group だけ書ける 664 なら読まれ、666 なら読まれない
#
# 走らせ方は probe/linuc-services-probe.sh と同じ（名前とボリューム名だけ extra2 用）:
#   docker run -d -t --name linuc-services-extra2 --hostname linuc --cap-add SYS_ADMIN \
#     -v <新しい名前のボリューム>:/root/.lab \
#     lab-linuc-services:1.0.2   # 公開名 ghcr.io/chai0204/lab-linuc-services:1.0.2。記録は push 前のローカルの同じイメージで取った
#   docker exec linuc-services-extra2 systemctl is-system-running --wait   # running が返るまで繰り返す
#   docker cp probe/linuc-services-extra2.sh linuc-services-extra2:/tmp/extra2.sh
#   docker exec linuc-services-extra2 bash -l /tmp/extra2.sh > logs/linuc-services-extra2.log 2>&1
#   docker rm -f linuc-services-extra2
# R / W / S の約束は probe/linuc-services-probe.sh と同じ。
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
W() { sleep "$1"; }
S() { printf '\n\n========== %s ==========\n' "$*"; }

S "0. 環境"
R 'lab env'

S "第2章: Asia/Tokyo の9件の切り替え（8件がサマータイム、1件が LMT から JST へ）"
R 'zdump -v /usr/share/zoneinfo/Asia/Tokyo | grep -v NULL'

S "第2章: /etc/localtime がコピーのとき（C ライブラリは読むが timedatectl はゾーン名を出せない）"
R 'cp --remove-destination /usr/share/zoneinfo/Asia/Tokyo /etc/localtime'
R 'ls -l /etc/localtime'
R 'timedatectl | grep "Time zone"'
R 'env -u TZ date'
R 'timedatectl set-timezone Etc/UTC'
R 'ls -l /etc/localtime'

S "第3章: chronyd が時計を動かさないのは -x のため"
R 'cat /etc/default/chrony'
R 'systemctl cat chrony.service | grep ExecStart'
R "grep -n -B1 -A2 'by default we enable -x' /usr/share/doc/chrony/README.container"
R "man 8 chronyd 2>/dev/null | grep -A3 -E '^ +-x$'"
R 'journalctl --no-pager -u chrony | grep "control of system clock"'

S "第3章: パッケージの既定（一覧を取ってから .deb の中を見る）"
R 'apt-get update > /dev/null 2>&1; echo "apt-get update: exit=$?"'
R 'cd /tmp && apt-get download chrony ntpsec > /dev/null 2>&1; ls /tmp/*.deb; cd /root'
R 'dpkg-deb --fsys-tarfile /tmp/chrony_*.deb | tar -xO ./etc/default/chrony'
R "dpkg-deb -c /tmp/ntpsec_*.deb | grep 'ntp.conf'"
R "apt-cache show systemd-timesyncd | grep -E '^(Package|Provides|Conflicts):'"

S "第3章: クライアントの chronyd は 123 番で待ち受けない（123 番にいるのは基準サーバ）"
R "ss -lnu | grep -E ':(123|323) '"
R 'systemctl stop lab-ntp-server'
R "ss -lnu | grep -E ':(123|323) '"
R 'systemctl is-active chrony'
R 'systemctl start lab-ntp-server'

S "第4章: rsyslog は既定で書くたびの同期をしない / リモート転送の @ と @@"
R "man 5 rsyslog.conf 2>/dev/null | grep -A5 'files are not synced'"
R "grep -rn -i 'sync' /etc/rsyslog.conf /etc/rsyslog.d/; echo \"exit=\$?\""
R "man 5 rsyslog.conf 2>/dev/null | grep -A3 'To  *forward messages to another host via UDP'"
R "man 5 rsyslog.conf 2>/dev/null | grep -B2 -A1 'destination port defaults to 514'"
R "man 1 logger 2>/dev/null | grep -A2 -E '^ +-T, --tcp'"

S "第5章: 99- で始まる名前では ForwardToSyslog=no が効かない（名前順で後の syslog.conf が勝つ）"
R 'mkdir -p /etc/systemd/journald.conf.d'
R "printf '[Journal]\nForwardToSyslog=no\n' > /etc/systemd/journald.conf.d/99-noforward.conf"
R 'systemctl restart systemd-journald'
W 1
R 'logger -p user.info "99番で止めたつもり"'
W 1
R 'grep -c "99番で止めたつもり" /var/log/syslog'
R "systemd-analyze cat-config systemd/journald.conf | grep -E '^# /|^ForwardToSyslog'"
R 'rm /etc/systemd/journald.conf.d/99-noforward.conf'
R 'systemctl restart systemd-journald'
W 1

S "第5章: systemd-cat が付けられるラベル（priority だけ。facility は無い）"
R 'systemd-cat --help'

S "第6章: logrotate.conf の su root adm は Ubuntu の変更"
R "grep -n 'su root adm' /etc/logrotate.conf"
R "zcat /usr/share/doc/logrotate/changelog.Debian.gz | grep -n -B3 'group adm on Ubuntu'"

S "第7章: newaliases は sendmail 互換の別名（postfix では postalias を走らせる）"
R 'ls -l /usr/bin/newaliases /usr/bin/mailq'
R "man 1 sendmail 2>/dev/null | grep -A1 -E '^ +-bi '"
R "man 1 sendmail 2>/dev/null | sed -n '/^DESCRIPTION/,\$p' | grep -A7 -E '^ +newaliases$'"

S "第7章: .forward は group だけ書ける 664 なら読まれ、other も書ける 666 なら読まれない"
R "echo 'alice: bob' >> /etc/aliases"
R 'newaliases'
R "printf 'root\n' > /home/bob/.forward"
R 'chown bob:bob /home/bob/.forward'
R 'chmod 664 /home/bob/.forward'
R 'ls -l /home/bob/.forward'
R 'echo "664 で送る" | mail -s "group-writable" alice'
W 3
R 'grep -c "664 で送る" /var/mail/root'
R 'chmod 666 /home/bob/.forward'
R 'ls -l /home/bob/.forward'
R 'echo "666 で送る" | mail -s "world-writable" alice'
W 3
R 'grep -c "666 で送る" /var/mail/root /var/mail/bob'
R 'grep -h "world writable" /var/log/mail.log /var/log/syslog'

S "第5章: /var/log/journal が無い環境での永続化（最後に打つ。journal を消すため）"
R 'rm -rf /var/log/journal'
R 'systemctl restart systemd-journald'
W 1
R 'ls -d /var/log/journal/* /run/log/journal/* 2>&1'
R 'mkdir -p /var/log/journal'
R 'systemd-tmpfiles --create --prefix /var/log/journal'
R 'journalctl --flush'
W 1
R 'ls -d /var/log/journal/* /run/log/journal/* 2>&1'
R 'systemctl restart systemd-journald'
W 1
R 'ls -d /var/log/journal/* /run/log/journal/* 2>&1'
R 'journalctl -t systemd-journald --no-pager | grep -E "(System|Runtime) Journal" | tail -2'
