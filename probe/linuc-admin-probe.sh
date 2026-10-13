#!/bin/bash
# LinuC 主題1.08（システム管理）理論編 第1〜9章の端末表示の出どころ。
#
# 章本文の `$ ` 行を、本文と同じ順序で、本文と同じ文字のまま1行ずつ打つ。
# 読者は第1章から順に同じ練習機の中で打っていくので、状態（ユーザ・グループ・crontab・ロケール）は
# 章をまたいで持ち越される。ここでもそれをそのまま再現する。ここに出ない出力は本文に書かない。
#
# 走らせ方（読者の起動コマンドと同じオプション。名前とボリューム名だけ probe 用。KVM は使わない）:
#   docker run -d --name linuc-admin-p1 --hostname host --stop-timeout 30 \
#     -v linuc-admin-p1-vm:/home/lab/vm -v linuc-admin-p1-state:/home/lab/.lab lab-linuc-admin:1.0.0
#   docker exec linuc-admin-p1 vm wait
#   docker cp probe/linuc-admin-probe.sh linuc-admin-p1:/tmp/probe.sh
#   docker exec -u lab -w /home/lab linuc-admin-p1 bash /tmp/probe.sh > logs/linuc-admin-probe.log 2>&1
#   docker exec linuc-admin-p1 vm reset --yes ; docker rm -f linuc-admin-p1
#
# 記録の約束:
#   H  … 外（lab@host）で打つもの。コマンド行を `$ ` 付きで書いてから実行する。
#   G  … 練習機の中（student@linuc）で打つもの。読者は `ssh linuc` で入った端末で打つ。
#        記録の `$ ` 行は読者が打つ形（ssh linuc を付けない形）で書き、実行は ssh linuc '…' で流す。
#        1回ずつ新しいログインになるので、「同じ端末の中で続けて打つ」ことに意味がある箇所は
#        `a; b` のように1回で流す（本文では2行に分けて見せる）。
#   GT … 練習機の中で、端末（tty）が要るもの（passwd のパスワード入力、at の対話入力）。
#        ssh -tt で端末を割り当て、入力を1行ずつ間を置いて渡す。画面に出る文字だけが記録に残る
#        （passwd の入力は端末がエコーしないので残らない）。改行の \r だけ取り除く。^D は Ctrl+D。
#        読者は ssh linuc の対話のシェル（端末あり・~/.bashrc の alias が効く）で打つ。端末の有無で文字が変わるもの
#        （ls の段組み、systemctl の表の省略）は、本文のコマンドの側で ls -1 / --full を付けて、どちらでも同じ文字にしてある
#        （2026-10-13 に対話のシェルと非対話の ssh で出力を比べて確かめた。違ったのはこの2種類だけ）。
#   W_* … 読者が次の行を打つまでの間。記録には出さない。コマンドは足していない。
#        cron と at は「分の頭」でしか動かないので、次の分まで待つ。人が読みながら打てば必ず空く間である。
#   S  … 章の区切り。記録の見出しで、本文には出ない。
set -u
LAST=0
S() { printf '\n\n========== %s ==========\n' "$*"; }
H() { printf '\n$ %s\n' "$1"; (exit "$LAST"); eval "$1" 2>&1; LAST=$?; }
G() { printf '\n$ %s\n' "$1"; ssh linuc "$1" 2>&1; LAST=$?; }
GT() {
  local cmd=$1; shift
  printf '\n$ %s\n' "$cmd"
  { sleep 5
    for l in "$@"; do
      if [ "$l" = '^D' ]; then printf '\004'; else printf '%s\n' "$l"; fi
      sleep 3
    done
    sleep 4
  } | ssh -tt -q linuc "$cmd" 2>&1 | tr -d '\r'
}
# 外で、端末（tty）つきで打つもの。いまは ssh linuc（対話のログイン）だけ。入力は1行ずつ間を置いて渡す
HT() {
  local cmd=$1; shift
  printf '\n$ %s\n' "$cmd"
  { sleep 6; for l in "$@"; do printf '%s\n' "$l"; sleep 3; done; sleep 3; } \
    | ssh -tt -q linuc 2>&1 | tr -d '\r'
}
W_sec()     { sleep "$1"; }
# 次の分の 0 秒を過ぎて 8 秒たつまで待つ（cron が起きて、ジョブが書き終えるまで）
W_nextmin() { local s; s=$(ssh linuc 'date +%-S'); sleep $(( 68 - s )); }
# 分の 35 秒より前になるまで待つ（at now + 1 minute の直後に分が替わって、atq に出る前に動き出さないように）
W_early()   { local s; s=$(ssh linuc 'date +%-S'); [ "$s" -lt 35 ] || sleep $(( 62 - s )); }
# 起動時に走った anacron が待ち終えるまで待つ（cron.weekly は10分後、cron.monthly は15分後に動く。
# それまで anacron はジョブのロックを持ち続け、手で打った anacron は locked by another anacron と言って飛ばす）
W_anacron() { until ! ssh linuc 'systemctl is-active -q anacron'; do sleep 10; done; sleep 5; }

S "0. 環境（検証環境ブロックの版の出どころ）"
H 'lab env'
H 'vm status'
H 'bash -lic exit 2>/dev/null'
HT 'ssh linuc' 'exit'
G '. /etc/os-release; echo "$PRETTY_NAME"'
G 'uname -r'
G 'dpkg-query -W -f "\${Package} \${Version}\n" passwd adduser cron anacron at locales libc-bin openssh-server sudo'

S "第1章 台帳は3枚に分かれている（1.08.1）"
G 'id'
G 'id -u; id -g; id -G; id -nG'
G "grep '^student:' /etc/passwd"
G 'head -3 /etc/passwd'
G "awk -F: '\$3 >= 1000' /etc/passwd"
G 'ls -l /etc/passwd /etc/shadow /etc/group /etc/gshadow'
G "grep '^student:' /etc/shadow"
G "sudo grep '^student:' /etc/shadow"
G "date -d '1970-01-01 +20739 days' +%F"
G "grep -E '^(adm|sudo|student):' /etc/group"
G 'getent group student'
G 'id student'
G 'getent passwd student | cut -d: -f4'
G 'getent group 1000'
G 'getent group proj-a proj-b bob'
G 'id bob'
G "grep -E '^(passwd|group|shadow|gshadow):' /etc/nsswitch.conf"
G 'getent passwd bob'
G 'getent passwd 1002'
G 'getent passwd nosuchuser; echo $?'
G 'sudo getent shadow bob'

S "第2章 useradd は頼まれたことしかしない（1.08.1）"
G 'sudo useradd alice'
G 'getent passwd alice'
G 'ls -ld /home/alice'
G 'sudo -iu alice pwd'
G 'id alice'
G "sudo grep '^alice:' /etc/shadow"
G 'useradd -D'
G 'ls -l /etc/default/useradd'
G "grep -vE '^\s*#|^\s*\$' /etc/default/useradd"
G "grep -E '^(UID_MIN|UID_MAX|GID_MIN|USERGROUPS_ENAB|HOME_MODE)' /etc/login.defs"
G 'sudo userdel alice'
G 'sudo useradd -m -s /bin/bash alice'
G 'getent passwd alice'
G 'ls -ld /home/alice'
G 'sudo ls -la /home/alice'
G 'ls -la /etc/skel'
G "echo 'ようこそ。困ったことがあれば管理者へ。' | sudo tee /etc/skel/memo.txt"
G "sudo useradd -m -s /bin/bash -c 'Carol Lab' carol"
G 'sudo ls -1A /home/alice /home/carol'
G 'getent passwd carol'
G 'sudo useradd -D -s /bin/bash'
G 'sudo useradd -D | grep SHELL'
G 'ls -l /etc/default/useradd'
G 'sudo useradd -D -s /bin/sh'
G 'useradd -D | grep SHELL'
G 'sudo useradd -D | grep SHELL'
G 'sudo chmod 644 /etc/default/useradd'
G 'useradd -D | grep SHELL'
G "sudo adduser --disabled-password --comment '' kai"
G 'getent passwd kai'
G 'id kai'
G 'sudo userdel -r kai'

S "第3章 所属は書いた通りに置き換わる（1.08.1）"
G 'sudo groupadd proj-x'
G 'sudo groupadd -g 1200 proj-y'
G 'getent group proj-x proj-y'
G 'sudo usermod -aG proj-x,proj-y alice'
G 'id alice'
G 'sudo groupadd ops'
G 'sudo usermod -G ops alice'
G 'id alice'
G 'getent group proj-x proj-y ops'
G 'sudo usermod -aG proj-x,proj-y alice'
G 'id alice'
G 'sudo usermod -aG proj-x student; id -nG; id -nG student'
G 'id -nG'
G 'sudo gpasswd -d student proj-x'
G 'sudo groupmod -n operators ops'
G 'getent group operators'
G 'id alice'
G 'sudo groupdel alice'
G 'sudo groupdel operators'
G 'id alice'
G 'sudo -u carol touch /tmp/carol-was-here'
G 'ls -l /tmp/carol-was-here'
G 'sudo userdel carol'
G 'ls -ld /home/carol'
G 'ls -l /tmp/carol-was-here'
G 'sudo find / -xdev -nouser'
G 'sudo useradd -m erin'
G 'id erin'
G 'ls -l /home'
G 'ls -l /tmp/carol-was-here'
G 'sudo userdel -r erin'
G 'sudo rm -r /home/carol /tmp/carol-was-here'
G 'ls -1 /home'

S "第4章 ロックは扉を1つ閉めるだけ（1.08.1）"
G 'sudo passwd -S alice'
G "sudo grep '^alice:' /etc/shadow"
GT 'sudo passwd alice' 'Alice-pass-2026' 'Alice-pass-2026'
G 'sudo passwd -S alice'
G "sudo grep '^alice:' /etc/shadow"
G 'sudo install -d -m 700 -o alice -g alice /home/alice/.ssh'
G 'sudo install -m 600 -o alice -g alice ~/.ssh/authorized_keys /home/alice/.ssh/'
H 'ssh -l alice linuc id'
G 'sudo passwd -l alice'
G 'sudo passwd -S alice'
G "sudo grep '^alice:' /etc/shadow"
H 'ssh -l alice linuc id'
G 'sudo usermod -e 1 alice'
G "sudo grep '^alice:' /etc/shadow"
H 'ssh -l alice linuc id'
G 'sudo su - alice -c id'
G 'sudo chage -l alice'
G "sudo usermod -e '' alice"
H 'ssh -l alice linuc id'
G 'sudo usermod -s /usr/sbin/nologin alice'
H 'ssh -l alice linuc id'
G 'sudo usermod -s /bin/bash alice'
G 'sudo passwd -u alice'
G 'sudo passwd -S alice'
G 'sudo passwd -e alice'
G 'sudo passwd -S alice'
H 'ssh -l alice linuc id'
G 'sudo passwd -d alice'
G 'sudo passwd -S alice'
G 'sudo passwd -l alice; sudo passwd -u alice'

S "第5章 crontab には「誰が」の列が無い（1.08.2）"
G 'crontab -l'
G 'ls -l /usr/bin/crontab'
G 'ls -ld /var/spool/cron/crontabs'
G "echo '* * * * * date >> /tmp/tick.txt' | crontab -"
G 'crontab -l'
G 'sudo ls -l /var/spool/cron/crontabs'
G 'sudo cat /var/spool/cron/crontabs/student'
W_nextmin
G 'cat /tmp/tick.txt'
G 'journalctl -u cron -n 3 --no-pager'
G "grep -vE '^\s*#|^\s*\$' /etc/crontab"
G "echo '* * * * * student date >> /tmp/tick2.txt 2>&1' | crontab -"
G 'crontab -l'
W_nextmin
G 'cat /tmp/tick2.txt'
G 'cat /tmp/tick.txt'
G 'ls -l /etc/cron.d'
G 'cat /etc/cron.d/e2scrub_all'
G "echo '* * * * * root id -un >> /tmp/cron-d.txt' | sudo tee /etc/cron.d/lab-demo"
G "echo '* * * * * root id -un >> /tmp/cron-dot.txt' | sudo tee /etc/cron.d/lab.demo"
G "echo '* * * * * id -un >> /tmp/cron-nouser.txt' | sudo tee /etc/cron.d/lab-nouser"
G "echo '* * * * * env > /tmp/cron-env.txt' | crontab -"
W_nextmin
G 'cat /tmp/cron-d.txt'
G 'ls -l /tmp/cron-dot.txt /tmp/cron-nouser.txt'
G "journalctl -u cron -n 30 --no-pager | grep -E 'lab|ERROR'"
G 'cat /tmp/cron-env.txt'
G 'echo $SHELL'
G 'crontab -r'
G 'crontab -l'
G 'sudo rm /etc/cron.d/lab-demo /etc/cron.d/lab.demo /etc/cron.d/lab-nouser'
G 'ls -l /etc/cron.allow /etc/cron.deny'
G 'echo student | sudo tee /etc/cron.deny'
G 'crontab -l'
G 'sudo rm /etc/cron.deny'
G 'crontab -l'

S "第6章 毎日の仕事は、名前で選ばれる（1.08.2）"
W_anacron
G 'ls -l /etc/cron.daily'
G 'grep run-parts /etc/crontab'
G "grep -vE '^\s*#|^\s*\$' /etc/anacrontab"
G 'journalctl -u anacron -b --no-pager'
G 'systemctl list-timers anacron.timer --no-pager --full'
G 'sudo ls -l /var/spool/anacron'
G 'sudo cat /var/spool/anacron/cron.daily'
G "printf '#!/bin/sh\ndate >> /tmp/daily.txt\n' | sudo tee /etc/cron.daily/hello.sh"
G 'sudo chmod 755 /etc/cron.daily/hello.sh'
G 'run-parts --test /etc/cron.daily'
G 'run-parts --list /etc/cron.daily'
G 'sudo mv /etc/cron.daily/hello.sh /etc/cron.daily/hello'
G 'run-parts --test /etc/cron.daily'
G 'sudo chmod 644 /etc/cron.daily/hello'
G 'run-parts --test /etc/cron.daily'
G 'run-parts --list /etc/cron.daily'
G 'sudo chmod 755 /etc/cron.daily/hello'
G 'sudo anacron -n -d'
G 'sudo anacron -f -n -s -d'
G 'cat /tmp/daily.txt'
G 'sudo cat /var/spool/anacron/cron.daily'
G 'tail -1 /etc/cron.daily/0anacron'
G 'sudo anacron -T; echo $?'
G 'sudo rm /etc/cron.daily/hello'

S "第7章 at は、いまの環境ごと持っていく（1.08.2）"
W_early
G 'systemctl is-active atd'
GT 'at now + 1 minute' 'date > /tmp/at.txt' '^D'
G 'atq'
G "export LAB_NOTE=hello; echo 'echo late > /tmp/at-late.txt' | at 23:59"
G 'atq'
G 'at -c 2 | head -4'
G 'at -c 2 | grep LAB_NOTE'
G 'at -c 2 | tail -6'
G 'sudo ls -l /var/spool/cron/atjobs'
G 'atrm 2'
G 'atq'
W_nextmin
G 'cat /tmp/at.txt'
G 'atq'
G "echo 'uptime > /tmp/batch.txt' | batch"
W_sec 20
G 'cat /tmp/batch.txt'
G 'ls -l /etc/at.allow /etc/at.deny'
G 'sudo head -5 /etc/at.deny'
G 'sudo mv /etc/at.deny /etc/at.deny.orig'
G 'atq'
G "echo 'date' | at now + 5 minutes"
G 'sudo atq'
G 'crontab -l'
G 'sudo touch /etc/at.deny'
G 'atq; echo $?'
G 'echo root | sudo tee /etc/at.allow'
G 'atq'
G 'sudo rm /etc/at.allow /etc/at.deny'
G 'sudo mv /etc/at.deny.orig /etc/at.deny'
G 'atq; echo $?'

S "第8章 ロケールは、名前で指しているだけ（1.08.3）"
G 'locale'
G 'cat /etc/default/locale'
G 'locale -a'
G 'LANG=ja_JP.UTF-8 date; echo $?'
G 'LANG=ja_JP.UTF-8 locale'
G 'grep ja_JP /etc/locale.gen'
G 'sudo locale-gen ja_JP.UTF-8'
G 'grep ja_JP /etc/locale.gen'
G 'locale -a'
G 'LANG=ja_JP.UTF-8 date'
G 'LANG=ja_JP.UTF-8 ls -l /etc/hostname'
G "LANG=ja_JP.UTF-8 printf \"%'d\\n\" 1234567"
G "LANG=C printf \"%'d\\n\" 1234567"
G 'LANG=ja_JP.UTF-8 ls /nonexistent'
G 'LANG=ja_JP.UTF-8 dpkg -s nonexistent-pkg'
G 'ls -1 /usr/share/locale/ja/LC_MESSAGES/'
G 'LANG=ja_JP.UTF-8 LC_TIME=C date'
G 'LANG=C LC_ALL=ja_JP.UTF-8 date'
G 'LANG=ja_JP.UTF-8 LC_TIME=C locale'
G "LANG=ja_JP.UTF-8 date | awk '{print \$2}'"
G "LANG=C date | awk '{print \$2}'"
G 'sudo localedef -i en_US -f UTF-8 en_US.UTF-8'
G 'locale -a'
G "printf '%s\n' b A a B | LANG=C sort | paste -sd ' '"
G "printf '%s\n' b A a B | LANG=en_US.UTF-8 sort | paste -sd ' '"
G "printf '%s\n' b A a B | LANG=ja_JP.UTF-8 sort | paste -sd ' '"
G 'localectl'
G 'sudo localectl set-locale LANG=ja_JP.UTF-8'
G 'cat /etc/default/locale'
G 'echo $LANG; date'
G 'sudo localectl set-locale LANG=C.UTF-8'
G 'echo $LANG; date'

S "第9章 文字コードは、読む側が決める（1.08.3）"
G "printf 'A' | od -An -tx1"
G "printf 'あ' | od -An -tx1"
G "printf 'é' | od -An -tx1"
G "printf '\\u3042\\n'"
G "printf 'あ' | iconv -f UTF-8 -t UTF-16BE | od -An -tx1"
G "printf 'あ' | iconv -f UTF-8 -t SHIFT_JIS | od -An -tx1"
G "printf 'あ' | iconv -f UTF-8 -t EUC-JP | od -An -tx1"
G "printf 'あ' | iconv -f UTF-8 -t ISO-2022-JP | od -An -tx1"
G 'echo こんにちは | iconv -f SHIFT_JIS -t UTF-8'
G 'echo こんにちは | iconv -f SHIFT_JIS -t UTF-8 | iconv -f UTF-8 -t SHIFT_JIS'
G 'echo こんにちは | od -An -tx1'
G 'echo こんにちは | iconv -f SHIFT_JIS -t UTF-8 | iconv -f UTF-8 -t SHIFT_JIS | od -An -tx1'
G 'mkdir -p ~/enc'
G "printf '日本語のメモ\\n' > ~/enc/utf8.txt"
G 'iconv -f UTF-8 -t SHIFT_JIS ~/enc/utf8.txt > ~/enc/sjis.txt'
G 'iconv -f UTF-8 -t EUC-JP ~/enc/utf8.txt > ~/enc/euc.txt'
G 'iconv -f UTF-8 -t ISO-2022-JP ~/enc/utf8.txt > ~/enc/jis.txt'
G 'cd ~/enc && file *.txt'
G 'cd ~/enc && wc -c *.txt'
G 'cat -v ~/enc/sjis.txt'
G 'od -c ~/enc/jis.txt'
G 'iconv -f SHIFT_JIS -t UTF-8 ~/enc/sjis.txt'
G 'iconv -f EUC-JP -t UTF-8 ~/enc/sjis.txt > /dev/null; echo $?'
G "printf 'こんにちは\\n' | iconv -f UTF-8 -t ISO-8859-1 > /dev/null; echo \$?"
G "printf 'café\\n' | iconv -f UTF-8 -t ISO-8859-1 | od -An -tx1"
G "printf 'こんにちは\\n' | iconv -f UTF-8 -t ASCII//TRANSLIT; echo \$?"
G "printf 'café\\n' | iconv -f UTF-8 -t ASCII//TRANSLIT"
G "iconv -l | grep -E '^(SHIFT_JIS|EUC-JP|ISO-2022-JP|ISO-8859-1|UTF-8|ASCII)//'"
