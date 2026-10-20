#!/bin/bash
# Debian 系の檻の演習 01〜08 を、模範解答どおりに通す。目的は2つ。
#   1) 未達のとき判定が ✗ を出し、観測した事実を出すこと（鳴らない検査は無いより悪い）
#   2) 解答どおりにやれば ✔ になること
# 配られた状態で ✗ になることは「A. 何もしていない状態」でまとめて、途中の「わざと足りない状態」でも
# ✗ になることは各演習の中で確かめる（remove だけ・dpkg -i だけ・依存を書かずに作った、など）。
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

H "B. 演習01 — labhello を入れて、使えるようにする"
R 'lab start 01'
R 'sudo apt install -y labhello'
R 'labhello'
R 'lab check 01; echo "exit=$?"'

H "C. 演習02 — 仕事に要らない遊びのパッケージを、見つけて消す"
R 'lab start 02'
R "dpkg -s labfortune | grep Section"
R 'echo "--- まちがえて labbackup を消した（games ではない） ---"; sudo apt remove -y labbackup'
R 'lab check 02; echo "exit=$?"'
R 'sudo apt install -y labbackup'
R 'sudo rm /usr/bin/labbackup'
R 'echo "--- 演習04 の始まりの状態に戻した（ファイルを消したまま台帳は ii） ---"; dpkg -V labbackup'
R 'sudo apt remove -y labfortune'
R 'lab check 02; echo "exit=$?"'

H "D. 演習03 — labsvc の設定ファイルを探して、ポートを 9090 に変える"
R 'lab start 03'
R 'labsvc'
R 'dpkg -S "$(which labsvc)"'
R 'dpkg -L labsvc'
R 'echo "--- プログラムのほうを書き換えた（設定ファイルではない） ---"; sudo sed -i "s/\${port:-未設定}/9090/" /usr/bin/labsvc; labsvc'
R 'lab check 03; echo "exit=$?"'
R 'sudo apt reinstall -y labsvc'
R 'labsvc'
R "sudo sed -i 's/^port=8080\$/port=9090/' /etc/labsvc.conf"
R 'labsvc'
R 'lab check 03; echo "exit=$?"'

H "E. 演習04 — 見つからなくなった labbackup を、パッケージから戻す"
R 'lab start 04'
R 'dpkg -V labbackup'
R 'sudo apt reinstall -y labbackup'
R 'dpkg -V labbackup; echo "exit=$?"'
R 'labbackup'
R 'lab check 04; echo "exit=$?"'

H "F. 演習05 — labweb を、跡形なく消す"
R 'lab start 05'
R "apt list --installed 'labweb*'"
R 'sudo apt remove -y labweb'
R 'echo "--- remove だけ（rc と設定ファイルと依存が残る） ---"; lab check 05; echo "exit=$?"'
R 'sudo apt purge -y labweb'
R 'echo "--- purge まで（依存がまだ残る） ---"; lab check 05; echo "exit=$?"'
R 'sudo apt autoremove -y'
R "dpkg -l 'labweb*' | cat; echo \"exit=\$?\""
R 'lab check 05; echo "exit=$?"'

H "G. 演習06 — labcalc コマンドを使えるようにする"
R 'lab start 06'
R 'apt search labcalc'
R "echo 'deb [trusted=yes] file:/srv/lab-tools tools main' | sudo tee /etc/apt/sources.list.d/lab-tools.list"
R 'echo "--- ソースに書いただけ（apt update 前） ---"; lab check 06; echo "exit=$?"'
R 'sudo apt update'
R 'apt-file search labcalc'
R 'sudo apt install -y lab-mathtools'
R 'labcalc 2 3'
R 'lab check 06; echo "exit=$?"'

H "H. 演習07 — 配られた .deb を、動く状態まで入れる"
R 'lab start 07'
R 'cd ~/work/07 && ls'
R 'cd ~/work/07 && dpkg -I labnote_1.0_all.deb | grep Depends'
R 'cd ~/work/07 && sudo dpkg -i labnote_1.0_all.deb; echo "exit=$?"'
R 'echo "--- dpkg -i だけ（iU で止まっている） ---"; lab check 07; echo "exit=$?"'
R 'sudo apt --fix-broken install -y'
R 'labnote'
R 'lab check 07; echo "exit=$?"'

H "I. 演習08 — 配られたスクリプトを、自分でパッケージにして入れる"
R 'lab start 08'
R 'cd ~/work/08 && ls && sh labmine.sh; echo "exit=$?"'
R 'cd ~/work/08 && mkdir -p labmine/usr/bin labmine/DEBIAN && cp labmine.sh labmine/usr/bin/labmine && chmod 755 labmine/usr/bin/labmine'
R "cd ~/work/08 && printf '%s\n' 'Package: labmine' 'Version: 1.0' 'Architecture: all' 'Maintainer: lab <lab@example.invalid>' 'Description: my script packaged by hand' > labmine/DEBIAN/control"
R 'cd ~/work/08 && dpkg-deb --build labmine .'
R 'echo "--- 依存関係を書かず、--root-owner-group も付けずに作って入れた ---"; cd ~/work/08 && sudo apt install -y ./labmine_1.0_all.deb'
R 'ls -l /usr/bin/labmine; labmine; echo "exit=$?"'
R 'lab check 08; echo "exit=$?"'
R "cd ~/work/08 && printf '%s\n' 'Package: labmine' 'Version: 1.0' 'Architecture: all' 'Maintainer: lab <lab@example.invalid>' 'Depends: liblab' 'Description: my script packaged by hand' > labmine/DEBIAN/control"
R 'cd ~/work/08 && dpkg-deb --build --root-owner-group labmine .'
R 'cd ~/work/08 && dpkg -c labmine_1.0_all.deb && dpkg -I labmine_1.0_all.deb | grep Depends'
R 'cd ~/work/08 && sudo apt install -y --reinstall ./labmine_1.0_all.deb'
R 'ls -l /usr/bin/labmine; labmine'
R 'lab check 08; echo "exit=$?"'

H "J. 全問通した状態で lab check と lab ls"
R 'lab check; echo "exit=$?"'
R 'lab ls'

H "K. lab の残りの機能（show / hint / solve / reset）"
R 'cd'
R 'lab show 06 | head -12'
R 'lab hint 06'
R 'lab hint 06'
R 'lab solve 05 | head -6'
R 'lab reset 07'
R 'lab ls'
R 'lab check 07; echo "exit=$?"'

H "L. 最終環境"
R 'lab env'
