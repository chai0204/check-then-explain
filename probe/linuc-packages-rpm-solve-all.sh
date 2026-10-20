#!/bin/bash
# RPM 系の檻の演習 09〜12 を、模範解答どおりに通す。目的は2つ。
#   1) 未達のとき判定が ✗ を出し、観測した事実を出すこと
#   2) 解答どおりにやれば ✔ になること
# lab コマンド（containers/base/bin/lab）は Ubuntu 前提で書かれているので、
# AlmaLinux の上で全機能（ls の find -printf・jq・date -Iseconds・完走表示・show・hint・solve・reset）が
# 動くことも、ここで確かめる。
# 演習は番号の順に、1つの檻の中で続けて解く（読者が実践編で檻を1回起動してから順に解くのと同じ）。
# 実行: bash probe/linuc-packages-run.sh solve（起動直後の檻で、lab ユーザとして走る）
set -u
# docker exec のシェルは umask 0000 で始まる。読者のログインシェルは 022（dpkg-deb は 0777 のディレクトリを断る）
umask 022
H() { printf '\n\n########## %s ##########\n' "$*"; }
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }

H "0. ログインしたときの表示（bash -l）"
R 'bash -lic true'

H "A. 何もしていない状態で lab check（全部 ✗ になるはず）"
R 'lab check; echo "exit=$?"'
R 'lab ls'

H "B. 演習09 — labapp を yum で入れ、挨拶を「こんにちは」に変える"
R 'lab start 09'
R 'sudo yum install -y labapp'
R 'labapp'
R 'echo "--- 入れただけ（挨拶は hello のまま） ---"; lab check 09; echo "exit=$?"'
R 'rpm -qc labapp'
R "echo '--- プログラムのほうを書き換えた ---'; sudo sed -i 's/\${greeting:-hello}/こんにちは/' /usr/bin/labapp; labapp"
R 'lab check 09; echo "exit=$?"'
R 'sudo yum reinstall -y labapp'
R "sudo sed -i 's/^greeting=\"hello\"\$/greeting=\"こんにちは\"/' /etc/labapp.conf"
R 'labapp'
R 'rpm -V labapp; echo "exit=$?"'
R 'lab check 09; echo "exit=$?"'

H "C. 演習10 — labcalc を、署名の確認を切らずに入れる"
R 'lab start 10'
R "printf '%s\n' '[lab-tools]' 'name=lab tools' 'baseurl=file:///srv/lab-tools-rpm' 'gpgcheck=1' | sudo tee /etc/yum.repos.d/lab-tools.repo"
R 'yum repolist'
R "yum provides '*/labcalc'"
R 'echo "--- gpgkey を書かずに入れようとする ---"; sudo yum install -y lab-mathtools; echo "exit=$?"'
R 'lab check 10; echo "exit=$?"'
R "sudo tee /etc/yum.repos.d/lab-tools.repo <<'END'
[lab-tools]
name=lab tools
baseurl=file:///srv/lab-tools-rpm
gpgcheck=1
gpgkey=file:///srv/lab-tools-rpm/RPM-GPG-KEY-lab-tools
END"
R 'sudo yum install -y lab-mathtools'
R 'labcalc 2 3'
R 'yum list installed lab-mathtools'
R 'lab check 10; echo "exit=$?"'

H "D. 演習11 — 書き換えられた labmotd を、入れた直後の状態に戻す"
R 'lab start 11'
R 'labmotd; echo "exit=$?"'
R 'rpm -qf /usr/bin/labmotd'
R 'rpm -V labmotd; echo "exit=$?"'
R 'sudo rpm --setperms labmotd'
R 'echo "--- 権限だけ戻した（中身は違うまま） ---"; lab check 11; echo "exit=$?"'
R 'sudo yum reinstall -y labmotd'
R 'rpm -V labmotd; echo "exit=$?"'
R 'labmotd'
R 'lab check 11; echo "exit=$?"'

H "E. 演習12 — labtool を yumdownloader で取ってきて、rpm で入れる"
R 'lab start 12'
R 'cd ~/work/12 && ls && yumdownloader labtool && ls -l'
R 'cd ~/work/12 && sudo rpm -ivh labtool-1.0-1.noarch.rpm; echo "exit=$?"'
R 'echo "--- labtool だけ取って rpm -ivh した（依存で止まった） ---"; lab check 12; echo "exit=$?"'
R 'cd ~/work/12 && yumdownloader --resolve labtool && ls -l'
R 'cd ~/work/12 && sudo rpm -ivh labtool-1.0-1.noarch.rpm labtool-data-1.0-1.noarch.rpm'
R 'labtool'
R 'yum list installed labtool labtool-data'
R 'lab check 12; echo "exit=$?"'

H "F. 全問通した状態で lab check と lab ls"
R 'lab check; echo "exit=$?"'
R 'lab ls'

H "G. lab の残りの機能（show / hint / solve / reset）"
R 'cd'
R 'lab show | head -8'
R 'lab hint 11'
R 'lab hint 11'
R 'lab solve 10 | head -6'
R 'lab reset 12'
R 'lab ls'
R 'lab check 12; echo "exit=$?"'

H "H. 最終環境"
R 'lab env'
