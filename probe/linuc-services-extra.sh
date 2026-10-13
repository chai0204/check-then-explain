#!/bin/bash
# 理論編の地の文と演習の模範解答の注記の裏取りのうち、章の流れ（probe/linuc-services-probe.sh）に
# 混ぜると状態が変わってしまうものを、別の新しい檻で確かめる。ここの出力は本文の端末表示には使わない。
#
#   第5章: BOOT ID はホストのカーネルの起動 ID で、コンテナを作り直しても変わらない
#   第6章: su をブロックの中に書けば親ディレクトリの拒否は通るが、logrotate.conf の既定
#          （create）は受け継がないので、切ったあとの新しい .log が作られない。
#          postrotate も無いので、rsyslog に HUP を送るまで新しい .log は現れない
#   演習05 の模範解答（solutions/05.md）: create と postrotate を自分で書いた設定なら、
#          su を足して単体で渡しても、新しい .log ができて rsyslog も開き直す
#
# 走らせ方は probe/linuc-services-probe.sh と同じ（名前とボリューム名だけ extra 用）:
#   docker run -d -t --name linuc-services-extra --hostname linuc --cap-add SYS_ADMIN \
#     -v <新しい名前のボリューム>:/root/.lab \
#     lab-linuc-services:1.0.1   # 公開名 ghcr.io/chai0204/lab-linuc-services:1.0.1。記録は push 前のローカルの同じイメージで取った
#   docker exec linuc-services-extra systemctl is-system-running --wait   # running が返るまで繰り返す
#   docker cp probe/linuc-services-extra.sh linuc-services-extra:/tmp/extra.sh
#   docker exec linuc-services-extra bash -l /tmp/extra.sh > logs/linuc-services-extra.log 2>&1
#   docker rm -f linuc-services-extra
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

S "第5章の裏取り: 別のコンテナでも BOOT ID は同じ"
R 'cat /proc/sys/kernel/random/boot_id'
R 'journalctl --list-boots'

S "第6章の裏取り: su をブロックの中に書いて、設定ファイルを直接渡す"
R "echo 'local3.*  /var/log/lab-app.log' > /etc/rsyslog.d/60-lab.conf"
R 'systemctl restart rsyslog'
W 1
R 'for i in $(seq 1 60); do logger -p local3.info "かさ増し $i"; done'
W 2
R "printf '/var/log/lab-app.log {\n    su root adm\n    size 1k\n    rotate 3\n    compress\n}\n' > /etc/logrotate.d/lab-app"
R 'chmod 644 /etc/logrotate.d/lab-app'
R 'logrotate -v /etc/logrotate.d/lab-app'
R 'echo $?'
R 'ls -l /var/log/lab-app.log*'
R 'logger -p local3.info "切ったあとの1行"'
W 1
R 'ls -l /var/log/lab-app.log*'
R 'systemctl kill -s HUP rsyslog.service'
W 1
R 'logger -p local3.info "HUP のあとの1行"'
W 1
R 'ls -l /var/log/lab-app.log*'
R 'cat /var/log/lab-app.log'

S "演習05 の模範解答の注記の裏取り: create と postrotate を書いた設定に su を足して、単体で渡す"
R 'for i in $(seq 1 60); do logger -p local3.info "かさ増し2 $i"; done'
W 2
R "printf '/var/log/lab-app.log {\n    su root adm\n    size 1k\n    rotate 3\n    missingok\n    notifempty\n    compress\n    create 0640 syslog adm\n    postrotate\n        systemctl kill -s HUP rsyslog.service\n    endscript\n}\n' > /etc/logrotate.d/lab-app"
R 'chmod 644 /etc/logrotate.d/lab-app'
R 'logrotate -v /etc/logrotate.d/lab-app'
R 'echo $?'
W 1
R 'logger -p local3.info "切ったあとの1行（create と postrotate あり）"'
W 1
R 'ls -l /var/log/lab-app.log*'
R 'cat /var/log/lab-app.log'
