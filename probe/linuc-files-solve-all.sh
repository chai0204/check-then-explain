#!/bin/bash
# LinuC 主題1.02 の全演習を、模範解答どおりに通す。目的は2つ。
#   1) 未達のとき判定が ✗ を出し、観測した事実を出すこと（鳴らない検査は無いより悪い）
#   2) 模範解答どおりにやれば ✔ になること
# 途中に「読者がやりそうな誤答」を挟み、そのときも ✗ になることを確かめる。
#
# 実行: 読者と同じ起動オプションで作ったコンテナの中で、PID 1 の bash として流す。
#   docker exec で流さない。exec のプロセスは umask が 0000 になり、読者（0022）とずれる。
set -u
H() { printf '\n\n########## %s ##########\n' "$*"; }
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
cd ~

H "A. 何もしていない状態で lab check（全部 ✗ か ⚠ になるはず）"
R 'lab check; echo "exit=$?"'

H "B. 演習01 — 一覧は見せずに、1つのファイルだけ読ませる"
R 'lab start 01 >/dev/null; echo "alice へ: 鍵は2番の棚" > ~/work/01/memo.txt; ls -l ~/work/01/memo.txt'
R 'sudo -u alice cat /home/lab/work/01/memo.txt; echo "exit=$?"'
R 'ls -ld /home/lab /home/lab/work /home/lab/work/01'
R 'lab check 01; echo "exit=$?"'
R 'echo "--- 誤答: ホームを 755 にする（読めるが、一覧も見えてしまう） ---"'
R 'chmod 755 ~; sudo -u alice cat /home/lab/work/01/memo.txt; sudo -u alice ls /home/lab'
R 'lab check 01; echo "exit=$?"'
R 'echo "--- 模範解答: その他に x だけ渡す ---"'
R 'chmod 750 ~; chmod o+x ~; chmod o-r ~/work/01; ls -ld /home/lab /home/lab/work/01'
R 'sudo -u alice cat /home/lab/work/01/memo.txt; sudo -u alice ls /home/lab; sudo -u alice ls /home/lab/work/01'
R 'lab check 01; echo "exit=$?"'

H "C. 演習02 — 次に開くシェルでも 640 と 750"
R 'lab start 02 >/dev/null; cd ~/work/02; umask; touch before.txt; mkdir before.d; ls -ld before.txt before.d'
R 'lab check 02; echo "exit=$?"'
R 'echo "--- 誤答: いまのシェルでだけ umask を変える ---"'
R 'umask 027; touch now.txt; mkdir now.d; ls -ld now.txt now.d'
R 'bash -lic "umask" 2>/dev/null | tail -1'
R 'lab check 02; echo "exit=$?"'
R 'umask 022; umask'
R 'echo "--- 模範解答: ~/.bashrc に書く ---"'
R "echo 'umask 027' >> ~/.bashrc; tail -1 ~/.bashrc"
R 'bash -lic "umask" 2>/dev/null | tail -1'
R 'lab check 02; echo "exit=$?"'
R 'cd ~'

H "D. 演習03 — devs の共有ディレクトリ"
R 'getent group devs; id alice; id bob; id carol'
R 'ls -ld /srv /srv/share'
R 'lab check 03; echo "exit=$?"'
R 'echo "--- 誤答: SGID だけ付けて 2775 にする ---"'
R 'sudo mkdir /srv/share; sudo chgrp devs /srv/share; sudo chmod 2775 /srv/share; ls -ld /srv/share'
R 'lab check 03; echo "exit=$?"'
R 'echo "--- 模範解答: SGID とスティッキービット、その他には何も渡さない ---"'
R 'sudo chmod 3770 /srv/share; ls -ld /srv/share'
R 'sudo -u alice touch /srv/share/a.txt; sudo ls -l /srv/share; sudo -u bob rm /srv/share/a.txt; sudo -u carol ls /srv/share'
R 'sudo rm -f /srv/share/a.txt'
R 'lab check 03; echo "exit=$?"'

H "E. 演習04 — 設定ファイルを、時刻ごと控えておく"
R 'lab start 04 >/dev/null; cd ~/work/04; ls -la'
R 'lab check 04; echo "exit=$?"'
R 'echo "--- 誤答: * で拾って、-p を付けずにコピーする ---"'
R 'echo *.conf'
R 'mkdir backup; cp *.conf backup/; ls -la backup'
R 'lab check 04; echo "exit=$?"'
R 'echo "--- 模範解答: 隠しファイルのパターンを足し、-p で時刻と権限を保つ ---"'
R 'echo .*.conf'
R 'cp -p *.conf .*.conf backup/; ls -la --time-style=full-iso app.conf backup/app.conf'
R 'lab check 04; echo "exit=$?"'
R 'cd ~'

H "F. 演習05 — 大きな .tmp だけを、深いところまで消す"
R 'lab start 05 >/dev/null; cd ~/work/05; find . -type f -printf "%s %p\n" | sort -k2'
R 'lab check 05; echo "exit=$?"'
R 'echo "--- 引用符を忘れると、シェルが先に広げる ---"'
R 'find . -name *.tmp'
R 'find . -name "*.tmp" | sort'
R 'echo "--- 誤答: 1000 バイトで切り、種類で絞らない ---"'
R 'find . -name "*.tmp" -size +1000c -delete; echo "exit=$?"'
R 'lab check 05; echo "exit=$?"'
R 'echo "--- lab reset だけで配り直し、書き込めることを確かめる（seed を 0644/0755 にした理由） ---"'
R 'cd ~; lab reset 05; cd ~/work/05'
R 'ls -ld . cache cache/deep; ls -l f.tmp cache/a.tmp'
R 'echo "--- 模範解答: 一覧で確かめてから消す ---"'
R 'find . -type f -name "*.tmp" -size +1k | sort'
R 'find . -type f -name "*.tmp" -size +1k -delete; find . -type f | sort'
R 'lab check 05; echo "exit=$?"'
R 'cd ~'

H "G. 演習06 — project を tar.xz にまとめる"
R 'lab start 06 >/dev/null; cd ~/work/06; ls -lR project'
R 'lab check 06; echo "exit=$?"'
R 'echo "--- 誤答1: 名前だけ .xz（中身は gzip） ---"'
R 'tar -czf project.tar.xz project; file project.tar.xz'
R 'lab check 06; echo "exit=$?"'
R 'echo "--- 誤答2: 絶対パスで渡す ---"'
R 'tar -cJf project.tar.xz ~/work/06/project; tar -tJf project.tar.xz | head -3'
R 'lab check 06; echo "exit=$?"'
R 'echo "--- 模範解答: 相対パスで渡して J で xz ---"'
R 'tar -cJvf project.tar.xz project; file project.tar.xz; tar -tJf project.tar.xz'
R 'lab check 06; echo "exit=$?"'
R 'cd ~'

H "H. 演習07 — current を v2 に切り替える"
R 'lab start 07 >/dev/null; cd ~/work/07; ls -l; ls -l releases; cat current/VERSION'
R 'lab check 07; echo "exit=$?"'
R 'echo "--- 誤答: ln -sf で上書きしたつもり ---"'
R 'ln -sf releases/v2 current; echo "exit=$?"; ls -l current; ls -l releases/v1'
R 'lab check 07; echo "exit=$?"'
R 'echo "--- 模範解答: できてしまったリンクを消し、-n を足す ---"'
R 'rm releases/v1/v2; ln -sfn releases/v2 current; ls -l current; cat current/VERSION'
R 'lab check 07; echo "exit=$?"'
R 'cd ~'

H "I. 演習08 — locate で見つからない2つ"
R 'lab start 08 >/dev/null; touch ~/work/08/needle.txt /tmp/needle.txt; ls -l ~/work/08/needle.txt /tmp/needle.txt'
R 'locate needle.txt; echo "exit=$?"'
R 'lab check 08; echo "exit=$?"'
R 'echo "--- 索引を作り直す（一般ユーザでは書けない） ---"'
R 'updatedb; echo "exit=$?"'
R 'sudo updatedb; locate needle.txt'
R 'lab check 08; echo "exit=$?"'
R 'echo "--- /tmp は PRUNEPATHS で外されている ---"'
R 'grep PRUNEPATHS /etc/updatedb.conf'
R "sudo sed -i 's#^PRUNEPATHS=\"/tmp #PRUNEPATHS=\"#' /etc/updatedb.conf; grep PRUNEPATHS /etc/updatedb.conf"
R 'sudo updatedb; locate needle.txt'
R 'lab check 08; echo "exit=$?"'

H "J. 全問通した状態で lab check（完走メッセージが出るはず）"
R 'lab check; echo "exit=$?"'
R 'lab ls'

H "K. ヒントと解答の表示"
R 'lab hint 05'
R 'lab solve 07 | head -12'

H "L. 最終環境"
R 'lab env'
