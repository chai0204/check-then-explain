#!/bin/bash
# LinuC 主題1.08 の全演習を、読者がやりがちな間違い → 模範解答の順に通す。目的は2つ。
#   1) 未達のとき判定が ✗ を出し、観測した事実を言うこと（鳴らない検査は無いより悪い）
#   2) 模範解答どおりにやれば ✔ になること
# 判定は外（lab@host）で走り、練習機の中は lab-guest で見る。練習機の中から打つ lab check も1回確かめる。
#
# 走らせ方（probe と同じ。新しいボリューム名で、練習機を最初の状態から始める）:
#   docker run -d --name linuc-admin-s1 --hostname host --stop-timeout 30 \
#     -v linuc-admin-s1-vm:/home/lab/vm -v linuc-admin-s1-state:/home/lab/.lab lab-linuc-admin:1.0.1
#   docker exec linuc-admin-s1 vm wait
#   docker cp probe/linuc-admin-solve-all.sh linuc-admin-s1:/tmp/solve.sh
#   docker exec -u lab -w /home/lab linuc-admin-s1 bash /tmp/solve.sh > logs/linuc-admin-solve-all.log 2>&1
#   docker exec linuc-admin-s1 vm reset --yes ; docker rm -f linuc-admin-s1
set -u
X() { printf '\n\n########## %s ##########\n' "$*"; }
H() { printf '\n$ %s\n' "$1"; eval "$1" 2>&1; }
G() { printf '\n$ %s\n' "$1"; ssh linuc "$1" 2>&1; }
GT() {
  local cmd=$1; shift
  printf '\n$ %s\n' "$cmd"
  { sleep 5; for l in "$@"; do printf '%s\n' "$l"; sleep 3; done; sleep 4; } \
    | ssh -tt -q linuc "$cmd" 2>&1 | tr -d '\r'
}
W_anacron() { until ! ssh linuc 'systemctl is-active -q anacron'; do sleep 10; done; sleep 5; }

X "A. 何もしていない状態で lab check（全部 ✗ になるはず。04 は cron を最大 75 秒待つ）"
H 'lab check; echo "exit=$?"'

X "B. 演習01 — ユーザを1人、使える状態で作る"
G 'useradd -D | grep -E "SHELL|SKEL"; ls -A /etc/skel'
G 'sudo useradd frank'
G 'getent passwd frank; ls -ld /home/frank'
H 'lab check 01; echo "exit=$?"'
G 'sudo userdel frank'
G "echo 'はじめに読んでください。' | sudo tee /etc/skel/README.txt"
G 'sudo useradd -m -s /bin/bash frank'
H 'lab check 01; echo "exit=$?"'
GT 'sudo passwd frank' 'Frank-pass-2026' 'Frank-pass-2026'
G 'getent passwd frank; sudo ls -A /home/frank; sudo passwd -S frank'
H 'lab check 01; echo "exit=$?"'

X "C. 演習02 — 所属を足す（今の所属は残す）"
G 'id bob'
G 'sudo groupadd -g 2000 devs'
G 'sudo usermod -G devs bob; id bob'
H 'lab check 02; echo "exit=$?"'
G 'sudo usermod -aG proj-a,proj-b bob; id bob'
G 'lab check 02; echo "exit=$?"'

X "D. 演習03 — dave を一時停止する"
H 'ssh -l dave linuc id'
G 'sudo passwd -l dave; sudo passwd -S dave'
H 'lab check 03; echo "exit=$?"'
G 'sudo usermod -e 1 dave; sudo chage -l dave | grep "Account expires"'
H 'ssh -l dave linuc id'
H 'lab check 03; echo "exit=$?"'

X "E. 演習04 — 2種類の表に、毎分のジョブを置く"
G "echo '* * * * * student date >> /home/student/tick.log' | crontab -"
G "echo '* * * * * id -un >> /var/log/lab-whoami.log' | sudo tee /etc/cron.d/lab-whoami"
H 'lab check 04; echo "exit=$?"'
G 'cat /home/student/tick.log; ls -l /home/student/tick.log'
G "journalctl -u cron -n 20 --no-pager | grep -E 'lab-whoami|ERROR'"
G "echo '* * * * * date >> /home/student/tick.log' | crontab -"
G "echo '* * * * * root id -un >> /var/log/lab-whoami.log' | sudo tee /etc/cron.d/lab-whoami"
H 'lab check 04; echo "exit=$?"'

X "F. 演習05 — 置いてあるのに走らないスクリプトを、毎日の実行に入れる"
W_anacron
G 'ls -l /etc/cron.daily/lab-backup.sh; run-parts --test /etc/cron.daily'
G 'sudo chmod 755 /etc/cron.daily/lab-backup.sh; run-parts --test /etc/cron.daily'
H 'lab check 05; echo "exit=$?"'
G 'sudo mv /etc/cron.daily/lab-backup.sh /etc/cron.daily/lab-backup; run-parts --test /etc/cron.daily'
H 'lab check 05; echo "exit=$?"'
G 'sudo anacron -f -n -s -d'
G 'cat /var/backups/lab-backup.log'
H 'lab check 05; echo "exit=$?"'

X "G. 演習06 — eve だけに at と crontab を使わせない"
G 'echo eve | sudo tee /etc/at.allow'
H 'lab check 06; echo "exit=$?"'
G 'sudo rm /etc/at.allow'
G 'echo eve | sudo tee -a /etc/at.deny; echo eve | sudo tee /etc/cron.deny'
H 'lab check 06; echo "exit=$?"'

X "H. 演習07 — どう呼ばれても同じ出力にする"
G 'cat /usr/local/bin/lab-report; lab-report'
H 'lab check 07; echo "exit=$?"'
G 'sudo locale-gen ja_JP.UTF-8'
G 'LANG=ja_JP.UTF-8 lab-report'
H 'lab check 07; echo "exit=$?"'
G "sudo sed -i '2i export LANG=C' /usr/local/bin/lab-report; head -3 /usr/local/bin/lab-report"
H 'lab check 07; echo "exit=$?"'
G "sudo sed -i 's/^export LANG=C\$/export LC_ALL=C/' /usr/local/bin/lab-report; head -3 /usr/local/bin/lab-report"
H 'lab check 07; echo "exit=$?"'

X "I. 演習08 — 文字コードのそろわない3つのファイルを UTF-8 にする"
G 'cd ~/lab08 && file *.txt'
G 'mkdir -p ~/lab08/utf8 && cd ~/lab08 && iconv -f ISO-8859-1 -t UTF-8 b.txt > utf8/b.txt; cat utf8/b.txt'
H 'lab check 08; echo "exit=$?"'
G 'cd ~/lab08 && iconv -f SHIFT_JIS -t UTF-8 a.txt > utf8/a.txt && iconv -f EUC-JP -t UTF-8 b.txt > utf8/b.txt && iconv -f ISO-2022-JP -t UTF-8 c.txt > utf8/c.txt && cat utf8/*.txt'
H 'lab check 08; echo "exit=$?"'

X "J. 全部まとめて（全問 ✔ と、完走の表示）"
H 'lab check; echo "exit=$?"'
H 'lab ls'
