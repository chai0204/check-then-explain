#!/bin/bash
# RPM 系の檻の演習 04〜06 を、模範解答どおりに通す。目的は2つ。
#   1) 未達のとき判定が ✗ を出し、観測した事実を出すこと
#   2) 解答どおりにやれば ✔ になること
# lab コマンド（containers/base/bin/lab）は Ubuntu 前提で書かれているので、
# AlmaLinux の上で全機能（ls の find -printf・jq・date -Iseconds・完走表示・hint・solve・reset）が
# 動くことも、ここで確かめる。
# 実行: probe/linuc-packages-run.sh solve（起動直後の檻で、lab ユーザとして走る）
set -u
H() { printf '\n\n########## %s ##########\n' "$*"; }
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }

H "0. ログインしたときの表示（bash -l）"
R 'bash -lic true'

H "A. 何もしていない状態で lab check（全部 ✗ になるはず）"
R 'lab check; echo "exit=$?"'
R 'lab ls'

H "B. 演習04 — labcalc を、署名の確認を切らずに入れる"
R 'lab start 04'
R "printf '%s\n' '[lab-tools]' 'name=lab tools' 'baseurl=file:///srv/lab-tools-rpm' 'gpgcheck=1' | sudo tee /etc/yum.repos.d/lab-tools.repo"
R 'yum repolist'
R "yum provides '*/labcalc'"
R 'echo "--- gpgkey を書かずに入れようとする ---"; sudo yum install -y lab-mathtools; echo "exit=$?"'
R 'lab check 04; echo "exit=$?"'
R "printf '%s\n' '[lab-tools]' 'name=lab tools' 'baseurl=file:///srv/lab-tools-rpm' 'gpgcheck=1' 'gpgkey=file:///srv/lab-tools-rpm/RPM-GPG-KEY-lab-tools' | sudo tee /etc/yum.repos.d/lab-tools.repo"
R 'sudo yum install -y lab-mathtools'
R 'labcalc 2 3'
R 'yum list installed lab-mathtools'
R 'lab check 04; echo "exit=$?"'

H "C. 演習05 — 書き換えられた labmotd を、入れた直後の状態に戻す"
R 'lab start 05'
R 'labmotd; echo "exit=$?"'
R 'rpm -qf /usr/bin/labmotd'
R 'rpm -V labmotd; echo "exit=$?"'
R 'sudo rpm --setperms labmotd'
R 'echo "--- 権限だけ戻した（中身は違うまま） ---"; lab check 05; echo "exit=$?"'
R 'sudo yum reinstall -y labmotd'
R 'rpm -V labmotd; echo "exit=$?"'
R 'labmotd'
R 'lab check 05; echo "exit=$?"'

H "D. 演習06 — labtool を yumdownloader で取ってきて、rpm で入れる"
R 'lab start 06'
R 'cd ~/work/06 && yumdownloader labtool && ls -l'
R 'cd ~/work/06 && sudo rpm -ivh labtool-1.0-1.noarch.rpm; echo "exit=$?"'
R 'echo "--- labtool だけ取って rpm -ivh した（依存で止まった） ---"; lab check 06; echo "exit=$?"'
R 'cd ~/work/06 && yumdownloader --resolve labtool && ls -l'
R 'cd ~/work/06 && sudo rpm -ivh labtool-1.0-1.noarch.rpm labtool-data-1.0-1.noarch.rpm'
R 'labtool'
R 'yum list installed labtool labtool-data'
R 'lab check 06; echo "exit=$?"'

H "E. 全問通した状態で lab check と lab ls"
R 'lab check; echo "exit=$?"'
R 'lab ls'

H "F. lab の残りの機能（hint / solve / reset）"
R 'cd'
R 'lab hint 05'
R 'lab hint 05'
R 'lab solve 04 | head -6'
R 'lab reset 06'
R 'lab ls'
R 'lab check 06; echo "exit=$?"'

H "G. 最終環境"
R 'lab env'
