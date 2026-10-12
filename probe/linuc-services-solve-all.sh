#!/bin/bash
# 全演習を模範解答どおりに通す。目的は2つ。
#   1) 未達のとき判定が ✗ を出すこと（鳴らない検査は無いより悪い）
#   2) 解答どおりにやれば ✔ になること
set -u
H() { printf '\n\n########## %s ##########\n' "$*"; }
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }

H "A. 何もしていない状態で lab check（全部 ✗ になるはず）"
R 'lab check; echo "exit=$?"'

H "B. 演習01 — 時刻の表示を3箇所で揃える"
R 'date +%Z; timedatectl show -p Timezone --value; cat /etc/timezone; env | grep "^TZ="'
R 'timedatectl set-timezone Asia/Tokyo'
R 'ls -l /etc/localtime; cat /etc/timezone'
R 'echo "Asia/Tokyo" > /etc/timezone; cat /etc/timezone'
R 'lab check 01; echo "exit=$?"'

H "C. 演習02 — chrony に基準を与えて同期させる"
R 'chronyc sources; chronyc tracking | head -2'
R "echo 'server 127.0.0.1 iburst' >> /etc/chrony/chrony.conf"
R 'systemctl restart chrony; sleep 9'
R 'chronyc sources -v | tail -3'
R 'chronyc tracking | head -3'
R 'lab check 02; echo "exit=$?"'

H "D. 演習03 — local3 のログを専用ファイルへ落とす"
R "echo 'local3.*  /var/log/lab-app.log' > /etc/rsyslog.d/60-lab.conf"
R 'systemctl restart rsyslog; sleep 2'
R 'logger -p local3.info "解答どおり"; sleep 2; cat /var/log/lab-app.log'
R 'lab check 03; echo "exit=$?"'

H "E. 演習04 — journal の上限を自分で決める"
R 'mkdir -p /etc/systemd/journald.conf.d'
R "printf '[Journal]\nSystemMaxUse=8M\n' > /etc/systemd/journald.conf.d/10-lab.conf; cat /etc/systemd/journald.conf.d/10-lab.conf"
R 'echo "--- まだ再起動していないので判定は通らないはず ---"; lab check 04; echo "exit=$?"'
R 'systemctl restart systemd-journald; sleep 2'
R 'journalctl -t systemd-journald --no-pager | tail -1'
R 'lab check 04; echo "exit=$?"'

H "F. 演習05 — ログを切って3世代だけ残す"
R 'umask'
R "printf '/var/log/lab-app.log {\n    size 1k\n    rotate 3\n    missingok\n    notifempty\n    compress\n    create 0640 syslog adm\n    postrotate\n        systemctl kill -s HUP rsyslog.service\n    endscript\n}\n' > /etc/logrotate.d/lab-app"
R 'ls -l /etc/logrotate.d/lab-app'
R 'echo "--- 権限を直す前はこうなる（これが罠） ---"; logrotate -v /etc/logrotate.d/lab-app; echo "exit=$?"'
R 'lab check 05; echo "exit=$?"'
R 'chmod 644 /etc/logrotate.d/lab-app; ls -l /etc/logrotate.d/lab-app'
R 'for i in $(seq 1 60); do logger -p local3.info "かさ増し $i"; done; sleep 2; ls -l /var/log/lab-app.log'
R 'echo "--- 権限を直しても、設定ファイルを直接渡すとまだ切れない（罠その2） ---"'
R 'logrotate -v /etc/logrotate.d/lab-app 2>&1 | tail -4'
R 'ls -ld /var/log'
R 'grep -vE "^\s*#|^\s*$" /etc/logrotate.conf'
R 'lab check 05; echo "exit=$?"'
R 'echo "--- 渡すファイルを /etc/logrotate.conf に変える ---"'
R 'logrotate -v /etc/logrotate.conf 2>&1 | grep -E "rotating log /var/log/lab-app|creating new /var/log/lab-app|compressing"'
R 'ls -l /var/log/lab-app.log*'
R 'lab check 05; echo "exit=$?"'
R 'cat /var/lib/logrotate/status'
R 'echo "--- 3世代を超えたら最古が捨てられる ---"'
R 'for r in 1 2 3 4; do for i in $(seq 1 60); do logger -p local3.info "回 $r 行 $i"; done; sleep 1; logrotate -f /etc/logrotate.conf >/dev/null 2>&1; done; ls -l /var/log/lab-app.log*'

H "G. 演習06 — メールを2回曲げて、ログで追う"
R 'id alice; id bob'
R "echo 'alice: bob' >> /etc/aliases; cat /etc/aliases"
R 'newaliases'
R "echo 'root' > /home/bob/.forward; chown bob:bob /home/bob/.forward; ls -l /home/bob/.forward"
R 'echo "--- chmod を忘れた状態（0666）でどうなるか ---"'
R 'echo "権限を直す前" | mail -s "before-chmod" alice; sleep 4'
R 'grep -c "権限を直す前" /var/mail/bob 2>/dev/null; grep -c "権限を直す前" /var/mail/root 2>/dev/null; echo "(bob / root の順)"'
R 'journalctl -t postfix/local --no-pager | grep -i forward | tail -2'
R 'lab check 06; echo "exit=$?"'
R 'chmod 644 /home/bob/.forward; ls -l /home/bob/.forward'
R 'echo "2回曲がる" | mail -s "forward 経由" alice; sleep 4'
R 'grep -c "2回曲がる" /var/mail/root'
R 'journalctl -t postfix/local --no-pager -n 3'
R 'lab check 06; echo "exit=$?"'

H "H. 全問通した状態で lab check（完走メッセージが出るはず）"
R 'lab check; echo "exit=$?"'
R 'lab ls'

H "I. 届かない宛先はキューではなく root に戻る"
R 'echo x | mail -s "届かない宛先" nosuchuser@invalid.example; sleep 4'
R 'mailq'
R 'ls -l /var/mail/'
R 'grep -c "届かない宛先" /var/mail/root 2>/dev/null; echo "(root に戻った数)"'
R 'journalctl -t postfix/local --no-pager -n 3'

H "J. 最終環境"
R 'lab env'
