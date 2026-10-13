#!/bin/bash
# 全演習を模範解答どおりに通す。外側コンテナ（lab@host）の中で lab として走らせる。
# 目的は2つ:
#   1) 手を付けていない状態で lab check NN が ✗ になること（鳴らない判定は無いより悪い）
#   2) 模範解答どおりにやれば ✔ になること
# 練習機の中の操作は ssh linuc 経由。採点は外側の lab check（ゲストエージェント経由）。
set -u
H() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
G() { printf '\n$ ssh linuc %q\n' "$*"; ssh linuc "$*" 2>&1; }
GD(){ printf '\n$ (deploy) %s\n' "$*"; ssh linuc "sudo runuser -l deploy -c $(printf '%q' "$*")" 2>&1; }
S() { printf '\n\n########## %s ##########\n' "$*"; }

S "A. 何もしていない状態で全部 ✗ になるか"
H 'lab check; echo "exit=$?"'

S "B. 演習01 — SUID の棚卸し（catfile の SUID を外す）"
H 'lab check 01; echo "exit=$?"'
G 'sudo chmod u-s /usr/local/bin/catfile; ls -l /usr/local/bin/catfile'
H 'lab check 01; echo "exit=$?"'

S "C. 演習02 — 退職者アカウントを無効化（有効期限を過去に）"
H 'lab check 02; echo "exit=$?"'
G 'sudo passwd -l olduser >/dev/null; echo "--- ロックだけでは判定は通らない ---"'
H 'lab check 02; echo "exit=$?"'
G 'sudo usermod -e 1 olduser; sudo chage -l olduser | grep -i "Account expires"'
H 'lab check 02; echo "exit=$?"'

S "D. 演習03 — 使っていない待ち受け(2323)を止める"
H 'lab check 03; echo "exit=$?"'
G 'sudo systemctl disable --now lab-echo.service; systemctl is-active lab-echo; systemctl is-enabled lab-echo'
G 'ss -ltn | grep 2323 || echo "(2323 は閉じた)"'
H 'lab check 03; echo "exit=$?"'

S "E. 演習04 — sudo を journalctl だけに絞る"
H 'lab check 04; echo "exit=$?"'
G 'echo "deploy ALL=(root) NOPASSWD: /usr/bin/journalctl" | sudo tee /etc/sudoers.d/deploy >/dev/null; sudo chmod 440 /etc/sudoers.d/deploy; sudo visudo -c'
H 'lab check 04; echo "exit=$?"'

S "F. 演習05 — ファイアウォールで 2323 を落とし、22 は残す"
H 'lab check 05; echo "exit=$?"'
G 'sudo iptables -A INPUT -p tcp --dport 2323 -j DROP; sudo iptables -L INPUT -n --line-numbers'
H 'lab check 05; echo "exit=$?"'

S "G. 演習06 — deploy の SSH 鍵ログインを用意する"
H 'lab check 06; echo "exit=$?"'
G 'ssh-keygen -t ed25519 -f /tmp/deploy_key -N "" <<<y >/dev/null; sudo install -d -m700 -o deploy -g deploy /home/deploy/.ssh; sudo tee /home/deploy/.ssh/authorized_keys < /tmp/deploy_key.pub >/dev/null; sudo chown deploy:deploy /home/deploy/.ssh/authorized_keys; sudo chmod 600 /home/deploy/.ssh/authorized_keys; echo done'
G 'ssh -i /tmp/deploy_key -o StrictHostKeyChecking=no -o BatchMode=yes deploy@localhost id'
H 'lab check 06; echo "exit=$?"'

S "H. 演習07 — GnuPG でファイルを暗号化する（deploy）"
H 'lab check 07; echo "exit=$?"'
GD 'gpg --batch --pinentry-mode loopback --passphrase "" --quick-gen-key "Deploy <deploy@linuc.example>" >/dev/null 2>&1; echo keygen_done'
GD 'echo 社外秘のメモ > ~/secret.txt; gpg --batch --yes --encrypt -r deploy@linuc.example ~/secret.txt; ls -l ~/secret.txt.gpg'
H 'lab check 07; echo "exit=$?"'

S "I. 全問 ✔ になった状態で lab check（完走メッセージ）"
H 'lab check; echo "exit=$?"'
H 'lab ls'
