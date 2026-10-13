#!/bin/bash
# LinuC 公式例題（linuc.org/study/samples）の監査で足りなかった項目を、檻の中で実際に通す追加の記録。
#   2594 locate のオプション / 4326 mv のオプション / 1344 ls のオプション / 5675 whereis の検索先
# 本体の probe（linuc-files-probe.sh）と同じ条件で流す: 読者と同じ起動オプションのコンテナで、
# PID 1 の bash として（umask 0022）、TERM=xterm で。ここに出ない出力は本文に書かない。
set -u
export TERM=xterm
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
T() { local ans=$1; shift; printf '\n$ %s\n' "$*"
      if [ "$ans" = - ]; then script -qec "$*" /dev/null < /dev/null | tr -d '\r'
      else (sleep 1; printf '%s\n' "$ans") | script -qec "$*" /dev/null | tr -d '\r'; fi; }
TI() { printf '\n$ %s\n' "$*"
       script -qec "bash -ic $(printf '%q' "$*")" /dev/null < /dev/null | tr -d '\r' | sed -e 's/\x1b\[[0-9;]*[mK]//g'; }
S() { printf '\n\n========== %s ==========\n' "$*"; }
cd ~

S "0. 環境"
R lab env

S "4. ls のオプション（1344）"
R 'mkdir -p ~/work/ch4/lsdemo; cd ~/work/ch4/lsdemo'
R 'touch -d "2026-01-03 00:00" a.txt; touch -d "2026-01-01 00:00" b.txt; touch -d "2026-01-02 00:00" c.txt'
TI 'ls'
TI 'ls -r'
TI 'ls -t'
TI 'ls -tr'
TI 'ls -1'
R 'ls -lt --time-style=long-iso'
R 'cd ~/work/ch4'

S "4. mv のオプション（4326）"
R 'mkdir -p ~/work/ch4/mvdemo; cd ~/work/ch4/mvdemo'
R 'mkdir backup docs; echo 1 > test.txt; echo 2 > docs/a.txt'
R 'mv -r test.txt backup/'
R 'mv docs backup/'
TI 'ls -R backup'
R 'mv -t backup test.txt'
TI 'ls backup'
R 'echo 3 > test.txt'
T n 'mv -i test.txt backup/'
R 'mv -n test.txt backup/; echo "exit=$?"'
R 'cat backup/test.txt; ls test.txt'
R 'mv -f test.txt backup/'
R 'cat backup/test.txt; ls test.txt'
R 'cd ~/work/ch4'

S "8. locate のオプション（2594）"
R 'cd ~'
R 'locate -c bashrc'
R 'locate -l 2 bashrc'
R 'locate skel'
R 'locate -b skel'
R 'locate -i DOT.BASHRC'
R 'locate -q bashrc; echo "exit=$?"'
R 'mkdir -p ~/work/dbdemo; touch ~/work/dbdemo/only-here.txt'
R 'updatedb -l 0 -U ~/work/dbdemo -o ~/work/dbdemo.db; echo "exit=$?"'
R 'locate only-here; echo "exit=$?"'
R 'locate -d ~/work/dbdemo.db only-here'

S "8. whereis の検索先（5675）"
R 'whereis -l | grep "^bin:"'
R 'whereis -b passwd'
R 'whereis -m passwd'
R 'whereis -s ls'
R 'whereis bash'

S "9. 版"
R 'lab env'
