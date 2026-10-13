#!/bin/bash
# Debian 系の檻の演習 01〜03 を、模範解答どおりに通す。目的は2つ。
#   1) 未達のとき判定が ✗ を出し、観測した事実を出すこと（鳴らない検査は無いより悪い）
#   2) 解答どおりにやれば ✔ になること
# 途中の「わざと足りない状態」でも ✗ になることを確かめる（remove だけ・dpkg -i だけ、など）。
# 実行: probe/linuc-packages-run.sh solve（起動直後の檻で、lab ユーザとして走る）
set -u
H() { printf '\n\n########## %s ##########\n' "$*"; }
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }

H "0. ログインしたときの表示（bash -l）"
R 'bash -lic true'

H "A. 何もしていない状態で lab check（全部 ✗ になるはず）"
R 'lab check; echo "exit=$?"'
R 'lab ls'

H "B. 演習01 — labsvc を、跡形なく消す"
R 'lab start 01'
R "dpkg -l 'labsvc*'"
R 'labsvc'
R 'sudo apt remove -y labsvc'
R 'echo "--- remove だけ（rc と設定ファイルと依存が残る） ---"; lab check 01; echo "exit=$?"'
R 'sudo apt purge -y labsvc'
R 'echo "--- purge まで（依存がまだ残る） ---"; lab check 01; echo "exit=$?"'
R 'sudo apt autoremove -y'
R "dpkg -l 'labsvc*'; echo \"exit=\$?\""
R 'lab check 01; echo "exit=$?"'

H "C. 演習02 — labcalc コマンドを使えるようにする"
R 'lab start 02'
R 'apt search labcalc'
R "echo 'deb [trusted=yes] file:/srv/lab-tools tools main' | sudo tee /etc/apt/sources.list.d/lab-tools.list"
R 'echo "--- ソースに書いただけ（apt update 前） ---"; lab check 02; echo "exit=$?"'
R 'sudo apt update'
R 'apt-file search labcalc'
R 'sudo apt install -y lab-mathtools'
R 'labcalc 2 3'
R 'lab check 02; echo "exit=$?"'

H "D. 演習03 — 配られた .deb を、動く状態まで入れる"
R 'lab start 03'
R 'cd ~/work/03 && ls -l'
R 'cd ~/work/03 && dpkg -I labnote_1.0_all.deb | grep Depends'
R 'cd ~/work/03 && sudo dpkg -i labnote_1.0_all.deb; echo "exit=$?"'
R 'echo "--- dpkg -i だけ（iU で止まっている） ---"; lab check 03; echo "exit=$?"'
R 'sudo apt --fix-broken install -y'
R 'labnote'
R 'lab check 03; echo "exit=$?"'

H "E. 全問通した状態で lab check と lab ls"
R 'lab check; echo "exit=$?"'
R 'lab ls'

H "F. lab の残りの機能（hint / solve / reset）"
R 'cd'
R 'lab hint 02'
R 'lab hint 02'
R 'lab solve 01 | head -6'
R 'lab reset 03'
R 'lab ls'
R 'lab check 03; echo "exit=$?"'

H "G. 最終環境"
R 'lab env'
