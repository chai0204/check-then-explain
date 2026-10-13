#!/bin/bash
# LinuC 主題1.10（セキュリティ）理論編 第1〜9章の端末表示の出どころ。
# 外側コンテナ（lab@host）の中で lab として走らせる。練習機（student@linuc）の中のコマンドは
# ssh linuc 経由で流し、記録には「読者が練習機の中で打つ形」（ssh linuc を外した形）で書く。
# 外（lab@host）で打つコマンドはそのまま書く。本文に載せる $ 行はこの記録と1行ずつ照合される。
#
# 走らせ方（読者の起動オプションと同じ。名前とボリュームだけ probe 用）:
#   docker run -d --name linuc-security-probe --hostname host \
#     -v linuc-security-probeX-vm:/home/lab/vm -v linuc-security-probeX-state:/home/lab/.lab \
#     lab-linuc-security:1.0.0
#   （autostart で練習機が立ち上がる。vm status で「応答あり」を待つ）
#   docker cp probe/linuc-security-probe.sh linuc-security-probe:/tmp/probe.sh
#   docker exec -u lab linuc-security-probe bash -l /tmp/probe.sh > logs/linuc-security-probe.log 2>&1
set -u
SO='-o BatchMode=yes -o StrictHostKeyChecking=no -o LogLevel=ERROR'

G() {  # 練習機の中で打つ（記録には ssh linuc を付けない形で出す）
  printf '\n$ %s\n' "$*"
  ssh linuc "$*" 2>&1
}
Gt() { # 練習機の中で打つ（対話シェル＝tty が要るもの。who など）
  printf '\n$ %s\n' "$*"
  ssh -tt linuc "$*" 2>&1 | sed 's/\r$//'
}
GD() { # 練習機の中で deploy として打つ（記録には sudo -u deploy -i の後に打つ素の形で出す）
  printf '\n$ %s\n' "$*"
  ssh linuc "sudo runuser -l deploy -c $(printf '%q' "$*")" 2>&1
}
H() {  # 外（lab@host）で打つ
  printf '\n$ %s\n' "$*"
  eval "$@" 2>&1
}
S() { printf '\n\n========== %s ==========\n' "$*"; }

S "0. 環境（検証環境ブロックの版の出どころ）"
H 'lab env'
G 'hostname'
G 'cat /etc/os-release | grep PRETTY_NAME'

S "0b. コンテナと練習機は別のカーネルで動いている（1.01 との地続き）"
H 'uname -r'
H 'systemd-detect-virt 2>/dev/null || true'
G 'uname -r'
G 'systemd-detect-virt'

S "第1章 SUID（1.10.1）"
G 'sudo find / -xdev -perm 4000 -type f 2>/dev/null | wc -l'
G 'sudo find / -xdev -perm -4000 -type f 2>/dev/null'
G 'sudo find / -xdev -perm -4000 -type f 2>/dev/null | wc -l'
G 'ls -l /usr/local/bin/catfile'
G 'id'
G '/usr/local/bin/catfile /etc/shadow | head -2'
# SUID はスクリプトには効かない（カーネルが無視する）
G 'printf "#!/bin/bash\nid\n" | sudo tee /usr/local/bin/wrap.sh >/dev/null; sudo chmod 4755 /usr/local/bin/wrap.sh; ls -l /usr/local/bin/wrap.sh'
G '/usr/local/bin/wrap.sh'
# s と S の違い（実行ビットの有無）
G 'sudo chmod 4644 /usr/local/bin/wrap.sh; ls -l /usr/local/bin/wrap.sh'
G 'sudo chmod 2755 /usr/local/bin/wrap.sh; ls -l /usr/local/bin/wrap.sh'
G 'sudo rm -f /usr/local/bin/wrap.sh'
# SGID / スティッキー
G 'ls -ld /tmp'
G 'ls -ld /var/mail'
G 'sudo find / -xdev -perm -2000 -type f 2>/dev/null | head -5'
# 外す
G 'sudo chmod u-s /usr/local/bin/catfile; ls -l /usr/local/bin/catfile'
G '/usr/local/bin/catfile /etc/shadow'
G 'sudo chmod 4755 /usr/local/bin/catfile'

S "第2章 パスワードエージングとアカウントの無効化（1.10.1）"
G 'sudo passwd -S olduser'
G 'sudo chage -l olduser'
G 'sudo grep -E "^(root|olduser):" /etc/shadow | cut -c1-30'
# olduser に student の鍵を登録して「鍵で入れる退職者」を作る
G 'ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/id_demo <<<y >/dev/null; sudo install -d -m700 -o olduser -g olduser /home/olduser/.ssh; sudo cp ~/.ssh/id_demo.pub /home/olduser/.ssh/authorized_keys; sudo chown olduser:olduser /home/olduser/.ssh/authorized_keys; sudo chmod 600 /home/olduser/.ssh/authorized_keys; echo set'
G "ssh -i ~/.ssh/id_demo $SO olduser@localhost id"
# パスワードをロックしても鍵では入れる
G 'sudo passwd -l olduser'
G 'sudo passwd -S olduser'
G 'sudo grep "^olduser" /etc/shadow | cut -c1-20'
G "ssh -i ~/.ssh/id_demo $SO olduser@localhost id"
# 有効期限を切ると鍵でも入れない
G 'sudo usermod -e 1 olduser'
G 'sudo chage -l olduser | grep -iE "アカウント有効期限|Account expires"'
G "ssh -i ~/.ssh/id_demo $SO olduser@localhost id; echo rc=\$?"
# 片付け（探索の跡を戻す）
G 'sudo usermod -e "" olduser; sudo passwd -u olduser >/dev/null; sudo rm -rf /home/olduser/.ssh ~/.ssh/id_demo ~/.ssh/id_demo.pub; echo restored'

S "第3章 ログイン履歴・セッション・制限（1.10.1）"
Gt 'who'
Gt 'w'
Gt 'last -a | head -5'
G 'ulimit -n'
G 'ulimit -u'
G 'ulimit -n 512; ulimit -n'
G 'ulimit -n 4096; echo rc=$?'
G 'echo "deploy hard nproc 30" | sudo tee -a /etc/security/limits.conf >/dev/null; echo added'
G 'sudo runuser -l deploy -c "ulimit -u"'
G 'sudo sed -i "/deploy hard nproc 30/d" /etc/security/limits.conf; echo cleaned'
G 'grep -n TMOUT /etc/profile.d/*.sh 2>/dev/null; echo "（既定では未設定）"'

S "第4章 開いているポートを見つける（1.10.1）"
G 'ss -ltn'
G 'sudo ss -ltnp | grep 2323'
G 'sudo netstat -ltnp | grep -E ":22 |:2323 "'
G 'nmap 127.0.0.1'
G 'sudo lsof -iTCP:2323 -sTCP:LISTEN -P -n'
G 'sudo fuser 2323/tcp'

S "第5章 su と sudo（1.10.1）"
G 'sudo -l -U deploy 2>&1 | tail -2'
G 'echo "deploy ALL=(root) NOPASSWD: /usr/bin/journalctl" | sudo tee /etc/sudoers.d/deploy >/dev/null'
G 'sudo chmod 440 /etc/sudoers.d/deploy'
G 'sudo visudo -c'
G 'sudo -l -U deploy 2>&1 | tail -2'
# deploy になって、許したものと許していないものを打つ
GD 'sudo -n journalctl -n 1 >/dev/null 2>&1; echo allowed_rc=$?'
GD 'sudo -n id; echo denied_rc=$?'
# 権限が緩いと丸ごと無視される（group/other に書けるだけで読まれない）
G 'sudo chmod 646 /etc/sudoers.d/deploy; ls -l /etc/sudoers.d/deploy'
GD 'sudo -n journalctl -n 1; echo rc=$?'
G 'sudo chmod 440 /etc/sudoers.d/deploy'
# 構文エラーは visudo が止める
G 'echo "deploy ALL=(root) NOPASS: ALL" | sudo tee /etc/sudoers.d/deploy >/dev/null'
G 'sudo visudo -c'
G 'sudo rm -f /etc/sudoers.d/deploy; echo removed'

S "第6章 シャドウと、使っていないサービス（1.10.2）"
G 'grep "^student" /etc/passwd'
G 'sudo grep "^student" /etc/shadow | cut -c1-30'
G 'ls -l /etc/passwd /etc/shadow'
# /etc/nologin
G 'echo "メンテナンス中（戻し方は本文）" | sudo tee /etc/nologin >/dev/null; ls -l /etc/nologin'
H "lab-guest 'cat /etc/nologin'"
H "lab-guest 'rm -f /etc/nologin && echo removed_by_root'"
# xinetd と inetd（同時に入らない）
G 'dpkg -s xinetd | grep -E "^(Package|Status|Provides|Conflicts):"'
G 'ls /etc/xinetd.d/'
G 'systemctl is-enabled xinetd; systemctl is-active xinetd'
G 'ls /etc/inetd.conf 2>&1'
G 'sudo apt-get update -qq; apt-get -s install openbsd-inetd 2>&1 | grep -A2 "REMOVED"'
# サービスの止め方いろいろ
G 'command -v chkconfig || echo "chkconfig: なし（RHEL 系の道具）"'
G 'command -v update-rc.d service'
G 'ls /etc/init.d/ | head -6'
G 'service --status-all 2>&1 | head -4'

S "第7章 ファイアウォール（1.10.2）"
G 'sudo iptables --version'
G 'sudo iptables -L INPUT -n'
G 'sudo iptables -A INPUT -p tcp --dport 2323 -j DROP'
G 'sudo iptables -L INPUT -n --line-numbers'
G 'timeout 3 bash -c "</dev/tcp/127.0.0.1/2323"; echo rc=$?'
H 'vm ssh echo ssh_is_alive'
G 'sudo iptables -D INPUT -p tcp --dport 2323 -j DROP; sudo iptables -L INPUT -n'
G 'sudo iptables-save | grep -c INPUT'
# firewalld（止めてある。起動して概念を見る）
G 'systemctl is-enabled firewalld; systemctl is-active firewalld'
G 'sudo systemctl start firewalld; sleep 2; sudo firewall-cmd --state'
G 'sudo firewall-cmd --get-default-zone'
G 'sudo firewall-cmd --list-all'
G 'sudo systemctl stop firewalld; echo stopped'

S "第8章 暗号化 — SSH と GPG（1.10.3）"
G 'rm -f /tmp/k_*; ssh-keygen -q -t rsa     -b 4096 -N "" -f /tmp/k_rsa   -C demo; echo rsa_done'
G 'ssh-keygen -q -t ecdsa   -b 521  -N "" -f /tmp/k_ecdsa -C demo; echo ecdsa_done'
G 'ssh-keygen -q -t ed25519         -N "" -f /tmp/k_ed    -C demo; echo ed_done'
G 'ssh-keygen -lf /tmp/k_rsa.pub; ssh-keygen -lf /tmp/k_ecdsa.pub; ssh-keygen -lf /tmp/k_ed.pub'
G 'rm -f /tmp/k_*'
# ssh-agent
G 'eval $(ssh-agent -s) >/dev/null; ssh-keygen -q -t ed25519 -N "" -f /tmp/ak -C agentdemo >/dev/null; ssh-add /tmp/ak 2>&1; ssh-add -l; eval $(ssh-agent -k) >/dev/null; rm -f /tmp/ak*'
# ポート転送（外から練習機の echo に届かせる）
G 'sudo systemctl start lab-echo; sleep 1; echo echo_up'
H 'timeout 2 bash -c "exec 3<>/dev/tcp/127.0.0.1/2323 && head -1 <&3" 2>&1; echo rc=$?'
H 'ssh -f -N -L 19999:127.0.0.1:2323 linuc; sleep 1; echo tunnel_up'
H 'timeout 3 bash -c "exec 3<>/dev/tcp/127.0.0.1/19999 && head -1 <&3"'
H 'pkill -f "19999:127.0.0.1:2323"; echo tunnel_down'
# GPG（deploy になって打つ。sudo -u deploy -i の後の素の形で記録する）
GD 'gpg --batch --pinentry-mode loopback --passphrase "" --quick-gen-key "Deploy <deploy@linuc.example>" >/dev/null 2>&1; gpg -k 2>/dev/null'
GD 'echo 社外秘のメモ > ~/secret.txt; gpg --batch --yes --encrypt -r deploy@linuc.example ~/secret.txt; ls -l ~/secret.txt.gpg'
GD 'gpg --decrypt ~/secret.txt.gpg 2>/dev/null'
GD 'ls ~/.gnupg'

S "第9章 クラウドセキュリティ（1.10.4・理論のみ）"
# 外から練習機に届くのは転送した 22 だけ（第8章のポート転送で実証済み）。理論章なので端末記録は無し。

S "末尾 最終環境"
H 'lab env'
