#!/bin/bash
# LinuC 主題1.09（重要なシステムサービス）理論編 第1〜7章の端末表示の出どころ。
#
# 章本文の `$ ` 行を、本文と同じ順序で、本文と同じ文字のまま1行ずつ打つ。
# 読者は第1章から順に同じ檻の中で打っていくので、状態（設定ファイル・ログ・メールボックス）は
# 章をまたいで持ち越される。ここでもそれをそのまま再現する。ここに出ない出力は本文に書かない。
#
# 2026-10-13 に全面改訂: 旧版は本文と順序が違い、本文の一部は別の場で打った結果だった
# （照合ツール tools/logcheck.mjs で、ログに無いコマンド27行・出力30行が見つかった）。
#
# 走らせ方（読者の起動コマンドと同じオプション。名前とボリューム名だけ probe 用）:
#   docker run -d -t --name linuc-services-probe --hostname linuc --cap-add SYS_ADMIN \
#     -v <新しい名前のボリューム>:/root/.lab \
#     lab-linuc-services:1.0.2   # 公開名 ghcr.io/chai0204/lab-linuc-services:1.0.2。記録は push 前のローカルの同じイメージで取った
#   docker exec linuc-services-probe systemctl is-system-running --wait   # running が返るまで繰り返す（起動直後は D-Bus が無い）
#   docker cp probe/linuc-services-probe.sh linuc-services-probe:/tmp/probe.sh
#   docker exec linuc-services-probe bash -l /tmp/probe.sh > logs/linuc-services-probe.log 2>&1
#   docker rm -f linuc-services-probe
# 読者と同じ root の login シェル（bash -l）で打つ。tty は付けない（付けると色や列揃えが混ざる）。
#
# 記録の約束:
#   R  … コマンド行を `$ ` 付きで書いてから実行する。複数行のコマンドは2行目以降を `> ` 付きで書く。
#        直前のコマンドの終了コードを引き継ぐので、本文の `echo $?` はそのまま意味を持つ。
#   W  … 読者が次の行を打つまでの間（秒）。記録には出さない。
#        logger・mail の結果はデーモンが非同期に書くので、間を置かずに次の行を打つと間に合わない。
#        人の手で打てば必ず数秒空くので、その間だけを置いている。コマンドは足していない。
#   S  … 章の区切り。記録の見出しで、本文には出ない。
#
# 同じ檻の記録はほかにもある（logs/ の同名ファイルに出る）:
#   probe/linuc-services-solve-all.sh … 演習6本を ✗ → ✔ の両方向で通す
#   probe/linuc-services-extra.sh     … 地の文の裏取りのうち、この流れに混ぜると状態が変わるもの
#   probe/linuc-services-extra2.sh    … 事実確認（2026-10-13）で直した地の文の裏取り
#   probe/linuc-services-podman.sh    … podman（rootless）の読者で出力が変わる箇所（umask が 0022）
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

S "0. 環境（検証環境ブロックの版の出どころ）"
R 'lab env'
R 'systemctl is-system-running'
R 'systemctl list-units --state=failed --no-legend --no-pager | wc -l'
R "dpkg-query -W -f '\${Package} \${Version}\n' systemd rsyslog chrony postfix logrotate"
S "0b. ログインしたときに出る表示（実践編の入口に載せる）"
R 'bash -lic exit 2>/dev/null'

S "第1章 時計は2つある（1.09.1）"
R 'date'
R 'date -u'
R 'timedatectl'
R 'hwclock'
R 'hwclock --show'
R 'cat /proc/driver/rtc'
R 'ls -l /dev/rtc*'
R 'timedatectl show'

S "第2章 タイムゾーンは表示の都合だけ（1.09.1）"
R 'date +%Z'
R 'timedatectl show -p Timezone --value'
R 'cat /etc/timezone'
R 'timedatectl set-timezone Asia/Tokyo'
R 'ls -l /etc/localtime'
R 'cat /etc/timezone'
R 'date'
R 'date -u'
R "env | grep '^TZ='"
R 'date +%s; TZ=UTC date; TZ=Asia/Tokyo date; TZ=America/New_York date; date +%s'
R 'date -d @0'
R 'TZ=UTC date -d @0'
R "date '+%Y-%m-%d %H:%M:%S %Z %z'"
R 'ls -l /etc/localtime'
R 'ls /usr/share/zoneinfo | head -20'
R 'file /usr/share/zoneinfo/Asia/Tokyo'
R 'timedatectl list-timezones | grep -c .'
R 'timedatectl list-timezones | grep Tokyo'

S "第3章 時刻合わせは、基準を渡されるまで始まらない（1.09.1）"
R 'systemctl is-active chrony'
R 'chronyc sources'
R 'chronyc tracking'
R 'systemctl is-active chrony'
R 'chronyc activity'
R "grep -vE '^\s*#|^\s*\$' /etc/chrony/chrony.conf"
R "grep '^#pool' /etc/chrony/chrony.conf"
R 'systemctl is-active lab-ntp-server'
R "grep -vE '^\s*#|^\s*\$' /etc/chrony/lab-ntp-server.conf"
R "ss -lun | grep -E ':(123|323)'"
R "echo 'server 127.0.0.1 iburst' >> /etc/chrony/chrony.conf"
R 'systemctl restart chrony'
R 'sleep 8'
R 'chronyc sources -v'
R 'chronyc tracking'
R 'timedatectl | tail -3'
R 'ntpdate -q 127.0.0.1'
R 'chronyc makestep'
W 1
R 'date -s "2020-01-01 00:00:00"'
R 'cat /etc/default/chrony'
R 'tail -3 /var/log/syslog'
R 'journalctl --no-pager -u chrony | grep "control of system clock"'
R "apt-cache show chrony | grep -E '^(Provides|Conflicts):'"
R "apt-cache show ntpsec | grep -E '^(Provides|Conflicts):'"
R 'apt-get update'
R "apt-cache show ntpsec | grep -E '^(Provides|Conflicts):'"

S "第4章 ログの宛先は、受け手の表が決める（1.09.2）"
R 'logger "はじめての logger"'
W 1
R 'tail -3 /var/log/syslog'
R 'logger -p local3.info "local3 に投げる"'
W 1
R 'grep local3 /var/log/syslog'
R 'grep IncludeConfig /etc/rsyslog.conf'
R 'ls /etc/rsyslog.d/'
R "grep -vE '^\s*#|^\s*\$' /etc/rsyslog.d/50-default.conf"
R "echo 'local4.warning  /var/log/lab-warn.log' > /etc/rsyslog.d/61-lab.conf"
R 'systemctl restart rsyslog'
W 1
R 'logger -p local4.debug   "debug なので入らない"'
R 'logger -p local4.info    "info なので入らない"'
R 'logger -p local4.warning "warning だから入る"'
R 'logger -p local4.err     "err だから入る"'
W 1
R 'cat /var/log/lab-warn.log'
R "echo 'local5.=notice  /var/log/lab-notice.log' > /etc/rsyslog.d/62-lab.conf"
R 'systemctl restart rsyslog'
W 1
R 'logger -p local5.notice "notice"'
R 'logger -p local5.err    "err"'
W 1
R 'cat /var/log/lab-notice.log'
R "echo 'local3.*  /var/log/lab-app.log' > /etc/rsyslog.d/60-lab.conf"
R 'systemctl restart rsyslog'
W 1
R 'logger -p local3.info "受け皿ができた後"'
W 1
R 'cat /var/log/lab-app.log'
R 'grep "受け皿ができた後" /var/log/syslog'
R "grep -n -E 'imudp|imtcp' /etc/rsyslog.conf"
R "sed -i -e '17s/^#//' -e '18s/^#//' -e '21s/^#//' -e '22s/^#//' /etc/rsyslog.conf"
R "grep -n -E 'imudp|imtcp' /etc/rsyslog.conf"
R 'systemctl restart rsyslog'
W 1
R "ss -lnu | grep ':514'"
R "ss -lnt | grep ':514'"
R 'logger -n 127.0.0.1 -P 514 -d "UDP で届いた"'
R 'logger -n 127.0.0.1 -P 514 -T "TCP で届いた"'
W 1
R 'grep "で届いた" /var/log/syslog'
R 'journalctl | grep -c "で届いた"'
R 'logger -p local3.err -t myapp "タグも付けられる"'
W 1
R 'tail -1 /var/log/lab-app.log'

S "第5章 journald は隣にある別の箱（1.09.2）"
R 'logger -p local3.info "二重に入るか"'
W 1
R 'grep -c "二重に入るか" /var/log/lab-app.log'
R 'journalctl | grep -c "二重に入るか"'
R 'journalctl --disk-usage'
R 'journalctl --no-pager -t myapp -o verbose'
R 'ls -l /dev/log'
R 'cat /usr/lib/systemd/journald.conf.d/syslog.conf'
R 'mkdir -p /etc/systemd/journald.conf.d'
R "printf '[Journal]\nForwardToSyslog=no\n' > /etc/systemd/journald.conf.d/syslog.conf"
R 'systemctl restart systemd-journald'
W 1
R 'logger -p local3.info "転送を止めた後"'
W 1
R 'grep -c "転送を止めた後" /var/log/syslog'
R 'journalctl | grep -c "転送を止めた後"'
R 'rm /etc/systemd/journald.conf.d/syslog.conf'
R 'systemctl restart systemd-journald'
W 1
R 'logger -p local3.info "戻した後"'
W 1
R 'grep -c "戻した後" /var/log/syslog'
R "grep -vE '^\s*#|^\s*\$' /etc/systemd/journald.conf"
R 'ls -d /var/log/journal/*'
R 'ls -d /run/log/journal/* 2>&1'
R 'journalctl --disk-usage'
R 'cat /etc/machine-id'
R 'mkdir -p /etc/systemd/journald.conf.d'
R "printf '[Journal]\nSystemMaxUse=8M\n' > /etc/systemd/journald.conf.d/10-lab.conf"
R 'systemctl restart systemd-journald'
W 1
R 'journalctl -t systemd-journald --no-pager | tail -1'
R 'journalctl --vacuum-size=1M'
R 'journalctl --vacuum-time=2d'
R 'journalctl --no-pager -u rsyslog -n 3'
R 'journalctl --no-pager -p err -n 3'
R 'journalctl --list-boots'
R 'cat /proc/sys/kernel/random/boot_id'
R 'systemd-cat -t lab-cat echo "systemd-cat から1行"'
W 1
R 'journalctl --no-pager -t lab-cat'
R 'journalctl --no-pager -t lab-cat -o verbose'

S "第6章 捨てる判断も、受け手側にある（1.09.2）"
R "grep -vE '^\s*#|^\s*\$' /etc/logrotate.conf"
R 'ls /etc/logrotate.d/'
R 'cat /etc/logrotate.d/rsyslog'
R "printf '/var/log/lab-app.log {\n    size 1k\n    rotate 3\n    compress\n}\n' > /etc/logrotate.d/lab-app"
R 'logrotate -v /etc/logrotate.d/lab-app'
R 'echo $?'
R 'chmod 644 /etc/logrotate.d/lab-app'
R 'for i in $(seq 1 60); do logger -p local3.info "かさ増し $i"; done'
W 2
R 'ls -l /var/log/lab-app.log'
R 'logrotate -v /etc/logrotate.d/lab-app'
R 'echo $?'
R 'ls -ld /var/log'
R 'grep -n su /etc/logrotate.conf'
R 'logrotate -v /etc/logrotate.conf'
R 'ls -l /var/log/lab-app.log*'
R 'cat /var/lib/logrotate/status'
R 'logrotate -f /etc/logrotate.conf'
W 1
R $'for r in 1 2 3 4; do\n  for i in $(seq 1 60); do logger -p local3.info "回 $r 行 $i"; done\n  logrotate -f /etc/logrotate.conf\ndone'
W 2
R 'ls -l /var/log/lab-app.log*'
R 'systemctl list-timers logrotate.timer --no-pager'
R 'systemctl cat logrotate.timer | head -12'

S "第7章 宛先に書いた名前は、希望にすぎない（1.09.3）"
R 'echo "本文です" | mail -s "最初の1通" alice'
W 3
R 'ls -l /var/mail/'
R 'cat /var/mail/alice'
R 'postconf -n | grep alias'
R 'cat /etc/aliases'
R "echo 'alice: bob' >> /etc/aliases"
R 'cat /etc/aliases'
R 'echo "曲がったか" | mail -s "aliases 経由" alice'
W 3
R 'ls -l /var/mail/'
R 'ls -l /etc/aliases /etc/aliases.db'
R 'newaliases'
R 'ls -l /etc/aliases.db'
R 'echo "曲がったか" | mail -s "aliases 経由" alice'
W 3
R 'ls -l /var/mail/'
R "printf 'root\n' > /home/bob/.forward"
R 'chown bob:bob /home/bob/.forward'
R 'ls -l /home/bob/.forward'
R 'echo "2回曲がる" | mail -s "forward 経由" alice'
W 3
R 'grep -c "2回曲がる" /var/mail/root'
R 'grep -c "2回曲がる" /var/mail/bob'
R 'journalctl -t postfix/local --no-pager | tail -3'
R 'grep "world writable" /var/log/mail.log'
R 'chmod 644 /home/bob/.forward'
R 'echo "2回曲がる" | mail -s "forward 経由" alice'
W 3
R 'grep -c "2回曲がる" /var/mail/root'
R 'journalctl -t postfix/local --no-pager -n 2'
R "grep -E '^(X-Original-To|Delivered-To):' /var/mail/root"
R 'echo x | mail -s "届かない宛先" nosuchuser@invalid.example'
W 5
R 'mailq'
R 'postqueue -p'
R 'journalctl -t postfix/smtp -t postfix/bounce -t postfix/local --no-pager -n 3'
R 'ls -l /var/mail/root'
R 'head -1 /etc/aliases'

S "裏取り（本文の地の文が言っていること。章の状態を乱さないよう最後にまとめて打つ）"
R 'command -v hwclock ntpdate chronyd; command -v ntpq; echo "ntpq: exit=$?"'
R 'dpkg -S /usr/sbin/ntpdate'
R 'chronyd -Q "server 127.0.0.1 iburst"'
R "man 8 chronyd 2>/dev/null | grep -A3 -E '^ +-[qQ]\$'"
R "man 1 logger 2>/dev/null | sed -n '/FACILITIES AND LEVELS/,/^EXAMPLES/p'"
R 'umask'
R 'id alice; id bob'
R 'getent group adm; getent passwd syslog'
R 'ls /var/log/journal/*/'
R 'journalctl -t myapp -o json | head -1'
R "grep -E '^(From|To|Subject):' /var/mail/root"
R 'ls -l /var/spool/postfix/etc/localtime /etc/localtime'

S "完了"
R 'lab env'
