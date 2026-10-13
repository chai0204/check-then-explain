#!/bin/bash
# LinuC 主題1.10（セキュリティ）理論編 第1〜9章の端末表示の出どころ（1.0.1）。
#
# 1.0.1 で取り方を変えた（事実確認の指摘による）:
#   1.0.0 は `$` の行ごとに別の ssh セッションでコマンドを流していた。シェルの状態（ulimit・変数・readonly・
#   ssh-agent の環境変数）が行をまたいで持ち越されず、読者の画面では起きない記録（ulimit -n 512 の後に
#   ulimit -n 4096 が rc=0）ができた。いまは練習機の中の操作を、読者と同じ「対話のログインシェル」
#   （-bash・tty・TERM=xterm）1つに続けて打つ（GI。中身は probe/linuc-security-drv.py）。
#   GI の1回が、読者の1回のログイン（1つの端末）に当たる。状態が要る並びは必ず1回の GI にまとめる。
#
# 走らせ方（読者の起動オプションと同じ。名前とボリュームだけ probe 用）:
#   docker run -d --name linuc-security-p101 --hostname host --stop-timeout 30 \
#     -v linuc-security-p101-vm:/home/lab/vm -v linuc-security-p101-state:/home/lab/.lab lab-linuc-security:1.0.1
#   （vm status で「応答あり」を待つ）
#   docker cp probe/linuc-security-drv.py   linuc-security-p101:/tmp/drv.py
#   docker cp probe/linuc-security-probe.sh linuc-security-p101:/tmp/probe.sh
#   docker exec -u lab linuc-security-p101 bash -l /tmp/probe.sh > logs/linuc-security-probe.log 2>&1
#
# 記録の約束:
#   H   外（lab@host）で打つ。このスクリプト自身のシェルで続けて実行する（外側の状態は持ち越す）
#   GI  練習機の中の対話ログインシェル1つで、標準入力の行を続けて打つ（GI deploy は sudo -u deploy -i に当たる）
#   Gt  練習機の中で tty 付きのログインを1回して打つ（who / w / last。ログインの記録が要るもの）
#       ssh -tt の後始末の行（Connection to … closed.）は端末の記録ではないので落とす
#   S   章の区切り（"========== N. …"。N は章番号。本文の生成 probe/linuc-security-gen.py がこれで引く）
set -u

H() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
GI() {
  local user=${1:-student} f
  f=$(mktemp)
  cat > "$f"
  chmod 644 "$f"      # deploy の GI も読めるように（mktemp は 600 で作る）
  scp -q "$f" linuc:/tmp/gi-cmds.txt
  if [ "$user" = student ]; then
    ssh linuc "python3 /tmp/drv.py /tmp/gi-cmds.txt"
  else
    ssh linuc "sudo -u $user -H python3 /tmp/drv.py /tmp/gi-cmds.txt"
  fi
  rm -f "$f"
}
Gt() { printf '\n$ %s\n' "$*"; ssh -tt linuc "$*" 2>&1 | sed 's/\r$//' | grep -v '^Connection to 127.0.0.1 closed\.$'; }
S() { printf '\n\n========== %s ==========\n' "$*"; }

scp -q /tmp/drv.py linuc:/tmp/drv.py

S "0. 環境（検証環境ブロックの版の出どころ）"
H 'lab env'
GI <<'EOF'
hostname
grep PRETTY_NAME /etc/os-release
uname -r
sudo --version | head -1
ssh -V
gpg --version | head -1
sudo iptables --version
nmap --version | head -1
systemctl --version | head -1
dpkg-query -W -f='${Package} ${Version}\n' passwd xinetd firewalld openssh-server findutils procps
EOF

S "1. SUID（1.10.1）"
GI <<'EOF'
sudo find / -xdev -perm 4000 -type f 2>/dev/null | wc -l
sudo find / -xdev -perm -4000 -type f 2>/dev/null
sudo find / -xdev -perm -4000 -type f 2>/dev/null | wc -l
sudo find / -xdev -perm -u+s -type f 2>/dev/null | wc -l
sudo find / -xdev -perm /6000 -type f 2>/dev/null | wc -l
ls -l /usr/local/bin/catfile
id
/usr/local/bin/catfile /etc/shadow | head -2
ls -l /etc/shadow
printf '#!/bin/bash\nid\n' | sudo tee /usr/local/bin/wrap.sh >/dev/null
sudo chmod 4755 /usr/local/bin/wrap.sh; ls -l /usr/local/bin/wrap.sh
/usr/local/bin/wrap.sh
sudo chmod 4644 /usr/local/bin/wrap.sh; ls -l /usr/local/bin/wrap.sh
sudo chmod 2755 /usr/local/bin/wrap.sh; ls -l /usr/local/bin/wrap.sh
sudo rm /usr/local/bin/wrap.sh
ls -ld /tmp /var/mail
sudo find / -xdev -perm -2000 -type f 2>/dev/null
sudo chmod u-s /usr/local/bin/catfile; ls -l /usr/local/bin/catfile
/usr/local/bin/catfile /etc/shadow
sudo chmod 4755 /usr/local/bin/catfile
EOF

S "2. パスワードエージングとアカウントの無効化（1.10.1）"
GI <<'EOF'
sudo passwd -S olduser
sudo chage -l olduser
sudo passwd -S root
sudo grep -E '^(root|olduser):' /etc/shadow | cut -c1-30
man 1 passwd | grep -A3 'does not disable'
ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_demo
sudo install -d -m 700 -o olduser -g olduser /home/olduser/.ssh
sudo install -m 600 -o olduser -g olduser ~/.ssh/id_demo.pub /home/olduser/.ssh/authorized_keys
ssh -i ~/.ssh/id_demo -o BatchMode=yes -o StrictHostKeyChecking=accept-new olduser@localhost id
sudo passwd -l olduser
sudo passwd -S olduser
sudo grep '^olduser:' /etc/shadow | cut -c1-20
ssh -i ~/.ssh/id_demo -o BatchMode=yes olduser@localhost id
sudo usermod -e 1 olduser
sudo chage -l olduser | grep 'Account expires'
sudo grep '^olduser:' /etc/shadow | cut -d: -f8
ssh -i ~/.ssh/id_demo -o BatchMode=yes olduser@localhost id; echo rc=$?
sudo journalctl --no-pager -n 30 | grep -o 'pam_unix(sshd:account).*' | tail -1
sudo usermod -e '' olduser
sudo usermod -s /usr/sbin/nologin olduser
ssh -i ~/.ssh/id_demo -o BatchMode=yes olduser@localhost id; echo rc=$?
ssh -i ~/.ssh/id_demo -o BatchMode=yes -f -N -L 18080:127.0.0.1:2323 olduser@localhost; sleep 1
timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/18080 && head -1 <&3'
pkill -f 18080:127.0.0.1:2323
sudo usermod -s /bin/bash olduser; sudo passwd -u olduser
sudo rm -r /home/olduser/.ssh; rm ~/.ssh/id_demo ~/.ssh/id_demo.pub
EOF

S "3. ログイン履歴・セッション・制限（1.10.1）"
GI <<'EOF'
ulimit -Sn; ulimit -Hn
ulimit -Sn 512; ulimit -Sn
ulimit -Sn 4096; echo rc=$?
ulimit -n 512
ulimit -Sn; ulimit -Hn
ulimit -n 4096
echo rc=$?
ulimit -u
EOF
GI <<'EOF'
ulimit -Hn
echo 'student hard nofile 2000' | sudo tee -a /etc/security/limits.conf
ulimit -Hn
EOF
H "ssh linuc 'ulimit -Hn'"
GI <<'EOF'
sudo sed -i '/^student hard nofile 2000$/d' /etc/security/limits.conf; grep -c 'nofile 2000' /etc/security/limits.conf
EOF
GI <<'EOF'
echo "TMOUT=[$TMOUT]"
TMOUT=600; readonly TMOUT; export TMOUT
unset TMOUT
TMOUT=0
echo "TMOUT=[$TMOUT]"
EOF
GI <<'EOF'
TMOUT=3
#!wait 6
EOF
GI <<'EOF'
printf 'TMOUT=600\nreadonly TMOUT\nexport TMOUT\n' | sudo tee /etc/profile.d/tmout.sh
EOF
GI <<'EOF'
echo "TMOUT=[$TMOUT]"
unset TMOUT
sudo rm /etc/profile.d/tmout.sh
EOF
H "ssh linuc who"
H "ssh linuc w -h"
Gt 'who'
Gt 'w'
Gt 'last -a | head -5'
GI <<'EOF'
ls -l /var/log/wtmp /var/log/btmp
last -a | head -3
lastb
sudo lastb | head -3
EOF

S "4. 開いているポートを見つける（1.10.1）"
GI <<'EOF'
ss -ltn
sudo ss -ltnp
sudo netstat -ltnp | grep -E ':22 |:2323 '
systemctl is-active ssh.socket ssh.service
nmap 127.0.0.1
grep -w 2323 /etc/services; echo rc=$?
grep -w 2323/tcp /usr/share/nmap/nmap-services
sudo lsof -iTCP:2323 -sTCP:LISTEN -P -n
sudo fuser 2323/tcp
EOF

S "5. su と sudo（1.10.1）"
GI <<'EOF'
sudo grep -E '^(%|root)' /etc/sudoers
sudo cat /etc/sudoers.d/90-cloud-init-users
sudo -u olduser id
sudo -l -U deploy
echo 'deploy ALL=(root) NOPASSWD: /usr/bin/journalctl' | sudo tee /etc/sudoers.d/deploy
sudo ls -l /etc/sudoers.d/deploy
sudo chmod 440 /etc/sudoers.d/deploy
sudo visudo -c
sudo -l -U deploy
EOF
GI deploy <<'EOF'
sudo -n journalctl -n 1 --no-pager >/dev/null; echo rc=$?
sudo -n id; echo rc=$?
EOF
GI <<'EOF'
sudo chmod 664 /etc/sudoers.d/deploy; sudo ls -l /etc/sudoers.d/deploy
EOF
GI deploy <<'EOF'
sudo -n journalctl -n 1 --no-pager >/dev/null; echo rc=$?
EOF
GI <<'EOF'
sudo chmod 666 /etc/sudoers.d/deploy; sudo ls -l /etc/sudoers.d/deploy
EOF
GI deploy <<'EOF'
sudo -n journalctl -n 1 --no-pager >/dev/null; echo rc=$?
EOF
GI <<'EOF'
sudo visudo -c; echo rc=$?
sudo chmod 660 /etc/sudoers.d/deploy; sudo chgrp deploy /etc/sudoers.d/deploy; sudo ls -l /etc/sudoers.d/deploy
EOF
GI deploy <<'EOF'
sudo -n journalctl -n 1 --no-pager >/dev/null; echo rc=$?
EOF
GI <<'EOF'
sudo visudo -c; echo rc=$?
sudo chgrp root /etc/sudoers.d/deploy; sudo chmod 440 /etc/sudoers.d/deploy; sudo visudo -c
echo 'deploy ALL=(root) NOPASS: ALL' | sudo tee /etc/sudoers.d/broken
sudo visudo -c; echo rc=$?
sudo -n true; echo rc=$?
man 5 sudoers | grep -A9 '^ *error_recovery'
sudo rm /etc/sudoers.d/broken
EOF

S "6. シャドウと、使っていないサービス（1.10.2）"
GI <<'EOF'
grep '^student:' /etc/passwd
sudo grep '^student:' /etc/shadow | cut -c1-30
ls -l /etc/passwd /etc/shadow
echo 'メンテナンス中です' | sudo tee /etc/nologin
EOF
H 'vm ssh echo hello'
H "lab-guest 'rm -f /etc/nologin && echo removed_by_root'"
H 'vm ssh echo hello'
GI <<'EOF'
dpkg -s xinetd | grep -E '^(Package|Status|Provides|Conflicts):'
ls -1 /etc/xinetd.d/
cat /etc/xinetd.conf
cat /etc/xinetd.d/echo
systemctl is-enabled xinetd; systemctl is-active xinetd
sudo sed -i 's/^\(\s*disable\s*=\s*\)yes/\1no/' /etc/xinetd.d/echo
grep disable /etc/xinetd.d/echo
sudo systemctl start xinetd; sleep 2
sudo ss -ltnp | grep ':7 '
printf 'hello\n' | nc -N -w 2 127.0.0.1 7
sudo sed -i 's/^\(\s*disable\s*=\s*\)no/\1yes/' /etc/xinetd.d/echo
sudo systemctl restart xinetd; sleep 2
sudo ss -ltn | grep ':7 ' || echo '（7 番は閉じた）'
sudo systemctl stop xinetd; systemctl is-active xinetd
ls /etc/inetd.conf
sudo apt-get update -qq
apt-get -s install openbsd-inetd | grep -A2 REMOVED
command -v chkconfig || echo 'chkconfig: なし'
command -v update-rc.d service
ls /etc/init.d/ | head -6
service --status-all 2>&1 | head -4
EOF

S "7. ファイアウォール（1.10.2）"
GI <<'EOF'
sudo grep '^FirewallBackend' /etc/firewalld/firewalld.conf
sudo systemctl start firewalld; sleep 2; sudo firewall-cmd --state
sudo iptables -L INPUT -n
sudo iptables -S
sudo firewall-cmd --get-default-zone
sudo firewall-cmd --list-all
sudo firewall-cmd --add-service=http
sudo firewall-cmd --list-services
sudo firewall-cmd --reload
sudo firewall-cmd --list-services
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --list-services
sudo firewall-cmd --reload
sudo firewall-cmd --list-services
sudo firewall-cmd --permanent --remove-service=http
sudo firewall-cmd --reload
sudo firewall-cmd --list-services
sudo systemctl stop firewalld
sudo iptables --version
sudo iptables -L INPUT -n
sudo iptables -A INPUT -p tcp --dport 2323 -j DROP
sudo iptables -L INPUT -n --line-numbers
timeout 3 bash -c '</dev/tcp/127.0.0.1/2323'; echo rc=$?
EOF
H 'vm ssh echo ssh_is_alive'
GI <<'EOF'
sudo iptables -D INPUT -p tcp --dport 2323 -j DROP
sudo iptables -L INPUT -n
EOF

S "8. 暗号化 — SSH と GPG（1.10.3）"
GI <<'EOF'
ssh -V
ssh-keygen -q -t rsa -b 4096 -N '' -f /tmp/k_rsa -C demo
ssh-keygen -q -t ecdsa -b 521 -N '' -f /tmp/k_ecdsa -C demo
ssh-keygen -q -t ed25519 -N '' -f /tmp/k_ed -C demo
for k in rsa ecdsa ed; do ssh-keygen -lf /tmp/k_$k.pub | awk '{print $1, $NF}'; done
wc -c /tmp/k_rsa.pub /tmp/k_ecdsa.pub /tmp/k_ed.pub
ssh-keygen -q -N '' -f /tmp/k_default -C demo
ssh-keygen -lf /tmp/k_default.pub | awk '{print $1, $NF}'
rm /tmp/k_rsa* /tmp/k_ecdsa* /tmp/k_ed* /tmp/k_default*
EOF
GI <<'EOF'
ssh-add -l
ssh-agent -s
ssh-add -l
eval $(ssh-agent -s)
ssh-add -l
ssh-keygen -q -t ed25519 -N '' -f /tmp/ak -C agentdemo
ssh-add /tmp/ak
ssh-add -l | awk '{print $1, $NF}'
EOF
GI <<'EOF'
ps -o pid,ppid,cmd -C ssh-agent
pkill -u student ssh-agent; ps -o pid,ppid,cmd -C ssh-agent
rm /tmp/ak /tmp/ak.pub
eval $(ssh-agent -s)
eval $(ssh-agent -k)
EOF
GI <<'EOF'
ssh-keygen -q -t ed25519 -N '' -f /tmp/sm_key -C smdemo
sudo install -d -m 700 -o olduser -g olduser /home/olduser/.ssh
sudo install -m 600 -o olduser -g olduser /tmp/sm_key.pub /home/olduser/.ssh/authorized_keys
ssh -i /tmp/sm_key -o BatchMode=yes olduser@localhost id
sudo chmod 777 /home/olduser/.ssh
ssh -i /tmp/sm_key -o BatchMode=yes olduser@localhost id; echo rc=$?
sudo journalctl --no-pager -n 50 | grep -o 'Authentication refused: .*' | tail -1
sudo chmod 700 /home/olduser/.ssh
ssh -i /tmp/sm_key -o BatchMode=yes olduser@localhost id
sudo rm -r /home/olduser/.ssh; rm /tmp/sm_key /tmp/sm_key.pub
EOF
H "timeout 2 bash -c 'exec 3<>/dev/tcp/127.0.0.1/2323 && head -1 <&3'; echo rc=\$?"
H 'ssh -f -N -L 19999:127.0.0.1:2323 linuc; sleep 1; echo tunnel_up'
H "timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/19999 && head -1 <&3'"
H 'pkill -f 19999:127.0.0.1:2323; echo tunnel_down'
GI deploy <<'EOF'
gpg --batch --pinentry-mode loopback --passphrase '' --quick-gen-key 'Deploy <deploy@linuc.example>'
gpg -k
ls -1 ~/.gnupg
gpgconf --list-dirs agent-socket
echo '社外秘のメモ' > ~/secret.txt
gpg --encrypt --recipient deploy@linuc.example ~/secret.txt
ls -l ~/secret.txt.gpg
gpg --decrypt ~/secret.txt.gpg
gpg --batch --pinentry-mode loopback --passphrase kyoutsuu -o ~/secret.sym.gpg -c ~/secret.txt
ls -l ~/secret.txt.gpg ~/secret.sym.gpg
gpg --list-packets ~/secret.txt.gpg 2>/dev/null | grep -o '^:[a-z]* enc packet'
gpg --batch --pinentry-mode loopback --passphrase kyoutsuu --list-packets ~/secret.sym.gpg 2>/dev/null | grep -o '^:[a-z]* enc packet'
gpg --batch --pinentry-mode loopback --passphrase kyoutsuu -d ~/secret.sym.gpg
EOF

S "9. クラウドセキュリティ（1.10.4・理論のみ。端末記録なし）"

S "10. 最終環境"
H 'lab env'
