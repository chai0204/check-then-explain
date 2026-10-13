#!/bin/bash
# podman（rootless）で入った読者に、第6章・第7章の「罠」が同じように起きるかを確かめる。
#
# docker exec と podman exec では、シェルの umask が違う（実測 2026-10-13）。
#   docker 29.8.0 : 0000 → printf > で作ったファイルが 0666 になる（第6章・第7章の前提）
#   podman 5.8.6  : 0022 → 同じ printf で 0644 になる
# ここでは、podman の読者が本文どおりに打つと何が出るかだけを記録する。
#
# 走らせ方（入口ページの podman の起動コマンドと同じオプション。名前とボリューム名だけ probe 用）:
#   podman run -d -t --name linuc-services-podman --hostname linuc --systemd=always \
#     -v <新しい名前のボリューム>:/root/.lab \
#     lab-linuc-services:1.0.1   # 公開名 ghcr.io/chai0204/lab-linuc-services:1.0.1。記録は push 前のローカルの同じイメージで取った
#   podman exec linuc-services-podman systemctl is-system-running --wait   # running が返るまで繰り返す
#   podman cp probe/linuc-services-podman.sh linuc-services-podman:/tmp/podman.sh
#   podman exec linuc-services-podman bash -l /tmp/podman.sh > logs/linuc-services-podman.log 2>&1
#   podman rm -f linuc-services-podman
# R / W の約束は probe/linuc-services-probe.sh と同じ。
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
R 'umask'

S "第6章の前提（第4章の受け皿を作ってから、同じ printf で設定を置く）"
R "echo 'local3.*  /var/log/lab-app.log' > /etc/rsyslog.d/60-lab.conf"
R 'systemctl restart rsyslog'
W 1
R 'logger -p local3.info "受け皿ができた後"'
W 1
R "printf '/var/log/lab-app.log {\n    size 1k\n    rotate 3\n    compress\n}\n' > /etc/logrotate.d/lab-app"
R 'ls -l /etc/logrotate.d/lab-app'
R 'logrotate -v /etc/logrotate.d/lab-app'
R 'echo $?'

S "第7章の前提（alias を効かせてから、同じ printf で .forward を置く）"
R "echo 'alice: bob' >> /etc/aliases"
R 'newaliases'
R "printf 'root\n' > /home/bob/.forward"
R 'chown bob:bob /home/bob/.forward'
R 'ls -l /home/bob/.forward'
R 'echo "2回曲がる" | mail -s "forward 経由" alice'
W 3
R 'grep -c "2回曲がる" /var/mail/root'
R 'journalctl -t postfix/local --no-pager | tail -3'
