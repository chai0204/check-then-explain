#!/bin/bash
# 試験対策で足した地の文（2026-10-13）の裏取り。LinuC 公式の例題（linuc.org/study/samples）で
# 正解を選べなかった・迷った語について本文を足したので、その中身を別の新しい檻で確かめる。
# 本文の端末表示に出すもの（date の書式・logger -p の数字・dateext など）は章の流れの
# probe/linuc-services-probe.sh で打っている。ここにあるのは、章の流れに混ぜると状態が変わるもの
# （メールボックス・/etc/aliases・~/.forward）と、この檻に無いもののマニュアル（ntpq）。
#
#   第1章: hwclock --adjust の意味
#   第2章: tzselect は質問に答えるとゾーン名を出すだけで、設定は変えない
#   第3章: ntpq は ntpd に状態を聞く。引数なしは対話モード（ntpq>）、-p は peers と同じ
#   第4章: logger -p の priority は数字でもよく、facility を省くと user になる
#   第6章: dateext と compress を両方書くと、切ったファイルは -年月日.gz になる
#   第7章: postfix・exim・sendmail はどれも mail-transport-agent で排他。exim4 も sendmail 互換のコマンドを持つ
#   第7章: mail の -s・-c・-b・-r（宛先は最後、本文は標準入力）、-S は無い /
#          /etc/aliases の右側はカンマで複数 / ~/.forward は1行に1宛先、手元にも残すなら \自分の名前
#
# 走らせ方は probe/linuc-services-probe.sh と同じ（名前とボリューム名だけ exam 用）:
#   docker run -d -t --name linuc-services-exam --hostname linuc --cap-add SYS_ADMIN \
#     -v <新しい名前のボリューム>:/root/.lab \
#     lab-linuc-services:1.0.2   # 公開名 ghcr.io/chai0204/lab-linuc-services:1.0.2（push 済みのものと同じイメージ）
#   docker exec linuc-services-exam systemctl is-system-running --wait   # running が返るまで繰り返す
#   docker cp probe/linuc-services-exam.sh linuc-services-exam:/tmp/exam.sh
#   docker exec linuc-services-exam bash -l /tmp/exam.sh > logs/linuc-services-exam.log 2>&1
#   docker rm -f linuc-services-exam
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

S "第1章: hwclock の短い形と --adjust"
R "hwclock --help | grep -E -- '--(show|hctosys|systohc|adjust) '"
R "man 8 hwclock 2>/dev/null | grep -A3 -E '^ +-a, --adjust'"

S "第1章: date の書式は年が最後（年を先頭に置くと、先頭の2桁を月として読もうとする）"
R 'date 202202140900; echo "exit=$?"'

S "第1章: timedatectl の status は省略時の既定 / set-time の書式 / set-ntp false は時刻合わせのサービスを止める"
R "man 1 timedatectl 2>/dev/null | grep -A5 -E '^ +status\$'"
R "man 1 timedatectl 2>/dev/null | grep -A3 -E '^ +set-time \\[TIME\\]'"
R "man 1 timedatectl 2>/dev/null | grep -A6 -E '^ +set-ntp \\[BOOL\\]'"

S "第2章: tzselect は質問に答えるとゾーン名を出すだけ（質問の画面も残す）"
R "printf '7\n7\n1\n' | tzselect"
R 'readlink /etc/localtime'
R 'date +%Z'

S "第3章: ntpq（ntpsec 本体に入っていて、この檻には無い。パッケージの中のマニュアルを読む）"
R 'command -v ntpq; echo "exit=$?"'
R 'apt-get update > /dev/null 2>&1; echo "apt-get update: exit=$?"'
R 'cd /tmp && apt-get download ntpsec > /dev/null 2>&1; ls /tmp/*.deb; cd /root'
R 'dpkg-deb -c /tmp/ntpsec_*.deb | grep ntpq'
R 'dpkg-deb --fsys-tarfile /tmp/ntpsec_*.deb | tar -xO ./usr/share/man/man1/ntpq.1.gz > /tmp/ntpq.1.gz'
R "man -l /tmp/ntpq.1.gz 2>/dev/null | sed -n '/^SYNOPSIS/,/^DESCRIPTION/p'"
R "man -l /tmp/ntpq.1.gz 2>/dev/null | grep -A8 'If one or more request options'"
R "man -l /tmp/ntpq.1.gz 2>/dev/null | grep -A4 -E '^ +-p, --peers'"
R "dpkg-deb --fsys-tarfile /tmp/ntpsec_*.deb | tar -xO ./usr/bin/ntpq | grep -n 'ntpq> '"

S "第4章: logger -p（man の言葉。数字でもよく、既定は user.notice）"
R "man 1 logger 2>/dev/null | grep -A5 -E '^ +-p, --priority'"
R 'logger -p 6 "数字だけ"'
W 1
R 'journalctl --no-pager -n 1 -o verbose | grep -E "PRIORITY=|SYSLOG_FACILITY=|MESSAGE="'

S "第6章: dateext と compress を両方書くと、日付の後ろに .gz が付く（確認問題の答え）"
R 'echo "1行" > /root/work/demo2.log'
R "printf '/root/work/demo2.log {\n    rotate 3\n    dateext\n    compress\n}\n' > /root/work/demo2.conf"
R 'chmod 644 /root/work/demo2.conf'
R 'logrotate -f /root/work/demo2.conf'
R 'ls /root/work/demo2*'

S "第7章: mail の書き方（-s 件名・-c・-b・-r。宛先は最後、本文は標準入力）"
R 'readlink -f /usr/bin/mail'
R "man 1 mail 2>/dev/null | sed -n '/^SYNOPSIS/,/^DESCRIPTION/p'"
R "man 1 mail 2>/dev/null | grep -A2 -E '^ +-(s|c|b|r) '"
R 'echo "本文は標準入力から" | mail -s "オプションの確認" -c alice -b bob -r noreply@lab.local lab'
W 3
R 'ls /var/mail/'
R "grep -E '^(Return-Path|From|To|Cc|Bcc|Subject):' /var/mail/lab"
R "grep -E '^(Return-Path|From|To|Cc|Bcc|Subject):' /var/mail/alice"
R "grep -E '^(Return-Path|From|To|Cc|Bcc|Subject):' /var/mail/bob"
R 'echo x | mail -s "差出人を変えて届かない宛先へ" -r lab@lab.local nosuchuser@invalid.example'
W 5
R "grep -E '^Subject:' /var/mail/lab"
R 'journalctl -t postfix/bounce -t postfix/local --no-pager | tail -2'
R 'echo x | mail -S smtp=smtp://127.0.0.1 -s test root; echo "exit=$?"'

S "第7章: MTA は1台に1つ（sendmail も同じ宣言）。exim4 も sendmail 互換のコマンドを持つ"
R "apt-cache show --no-all-versions sendmail-bin | grep -E '^(Provides|Conflicts):'"
R "apt-cache show --no-all-versions exim4 | grep -E '^Depends:'"
R 'cd /tmp && apt-get download exim4-base exim4-daemon-light > /dev/null 2>&1; ls /tmp/exim4*.deb; cd /root'
R "for d in /tmp/exim4*.deb; do dpkg-deb -c \$d | grep -E 'sbin/sendmail|bin/mailq|bin/newaliases'; done"

S "第7章: /etc/aliases の右側はカンマで複数（全員に1通ずつ届く）"
R "man 5 aliases 2>/dev/null | grep -B2 -A1 'name: value1, value2'"
R "echo 'support: alice, bob' >> /etc/aliases"
R 'newaliases'
R 'echo "全員に届くか" | mail -s "カンマで2人" support'
W 3
R 'grep -c "全員に届くか" /var/mail/alice /var/mail/bob'
R 'journalctl -t postfix/local --no-pager | tail -2'

S "第7章: ~/.forward は1行に1宛先。手元にも残すなら \\自分の名前"
R "printf '\\\\bob\nroot\n' > /home/bob/.forward"
R 'chown bob:bob /home/bob/.forward; chmod 644 /home/bob/.forward'
R 'cat /home/bob/.forward'
R 'echo "手元にも残す" | mail -s "backslash" bob'
W 3
R 'grep -c "手元にも残す" /var/mail/bob /var/mail/root'
R "printf 'bob\nroot\n' > /home/bob/.forward"
R 'echo "バックスラッシュなし" | mail -s "no-backslash" bob'
W 3
R 'grep -c "バックスラッシュなし" /var/mail/bob /var/mail/root'
R "printf 'root, lab\n' > /home/bob/.forward"
R 'echo "1行にカンマで2つ" | mail -s "comma-forward" bob'
W 3
R 'grep -c "1行にカンマで2つ" /var/mail/bob /var/mail/root /var/mail/lab'
R "man 8postfix local 2>/dev/null | grep -B3 -A4 'own ~/.forward'"

S "完了"
R 'lab env'
