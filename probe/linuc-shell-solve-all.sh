#!/bin/bash
# LinuC 主題1.06 の全演習を、模範解答どおりに通す。目的は2つ。
#   1) 解く前（とよくある間違い）で判定が ✗ を出し、観測した事実を出すこと
#   2) 模範解答どおりにやれば ✔ になること
# 記録の取り方（読者と同じ --hostname とボリューム2つで起動する。ボリューム名は linuc-shell- で始める）:
#   docker run -d --name linuc-shell-solve --hostname linuc \
#     -v linuc-shell-solve-work:/home/lab/work -v linuc-shell-solve-state:/home/lab/.lab \
#     lab-linuc-shell:1.0.2 sleep infinity
#   docker cp probe/linuc-shell-solve-all.sh linuc-shell-solve:/tmp/run.sh
#   docker exec -u lab -w /home/lab linuc-shell-solve bash /tmp/run.sh > logs/linuc-shell-solve-all.log 2>&1
#   docker rm -f linuc-shell-solve
# set -u は付けない（読者のシェルには付いていない。付けると未定義の変数でスクリプトが止まり、本文と違う動きになる）
# docker exec の umask は 0000、読者が入る docker run の端末は 0022（実測 2026-10-13）。読者に揃える。
umask 022
H() { printf '\n\n########## %s ##########\n' "$*"; }
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
# 対話シェルの記録。疑似端末（script）の上でログインシェル（/bin/bash -l）を起動し、1行ずつ打ち込む。
#   プロンプトを "$ " にして、R と同じ形（"$ コマンド" の行）で残す。
#   "#sleep N" の行は打たずに N 秒待つ。端末の制御文字（\r・色）は落とす。
SESSION() {
  { sleep 1
    printf '%s\n' 'PROMPT_COMMAND='"'"'PS1="\$ "'"'"'; : __REC__'
    while IFS= read -r l; do
      case $l in "#sleep "*) sleep "${l#\#sleep }"; continue ;; esac
      sleep "${DELAY:-0.7}"; printf '%s\n' "$l"
    done
    sleep 1.5
  } | script -q -c "stty cols 200 rows 50; exec /bin/bash -l" /dev/null \
    | tr -d '\r' | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g; s/\x1b\][^\x07]*\x07//g' | sed '1,/__REC__/d'
}

H "0. 環境"
R 'lab env'

H "A. 何もしていない状態で lab check（01〜03 は ✗、04〜08 は lab start 前なので前提不足）"
R 'lab check; echo "exit=$?"'

H "B. 演習01 — ログインしたときだけ挨拶を出す"
R 'lab start 01'
R 'sudo ls -la /home/bob'
R 'sudo cat /home/bob/.bash_profile'
R 'sudo head -3 /home/bob/.profile'
R 'echo "--- よくある間違い: ~/.profile に書く（~/.bash_profile があるので読まれない） ---"'
R 'echo '"'"'echo "ようこそ bob さん"'"'"' | sudo tee -a /home/bob/.profile'
R 'lab check 01; echo "exit=$?"'
R 'echo "--- よくある間違い: ~/.bashrc に書く（子のシェルで出て、ログインでは出ない） ---"'
R 'sudo sed -i '"'"'/ようこそ bob さん/d'"'"' /home/bob/.profile'
R 'echo '"'"'echo "ようこそ bob さん"'"'"' | sudo tee -a /home/bob/.bashrc'
R 'lab check 01; echo "exit=$?"'
R 'sudo sed -i '"'"'/ようこそ bob さん/d'"'"' /home/bob/.bashrc'
R 'echo "--- sudo echo ... >> は lab の権限で書こうとして失敗する（対話シェルで確かめる） ---"'
SESSION <<'IN'
sudo echo 'echo "ようこそ bob さん"' >> /home/bob/.bash_profile
exit
IN
R 'echo "--- 模範解答: ~/.bash_profile の末尾に足す ---"'
R 'echo '"'"'echo "ようこそ bob さん"'"'"' | sudo tee -a /home/bob/.bash_profile'
R 'sudo cat /home/bob/.bash_profile'
SESSION <<'IN'
sudo -iu bob
#sleep 1.5
type ll
bash
#sleep 1
exit
exit
#sleep 1
exit
IN
R 'lab check 01; echo "exit=$?"'

H "C. 演習02 — 自作のコマンドを、名前だけで呼べるようにする"
R 'lab start 02'
R 'cat ~/work/02/today'
R '~/work/02/today'
R 'today; echo "exit=$?"'
R 'echo $PATH'
R 'lab check 02; echo "exit=$?"'
R 'mkdir -p ~/bin; cp ~/work/02/today ~/bin/; ls -l ~/bin/today'
R 'today; echo "exit=$?"'
R 'grep -n -A2 '"'"'HOME/bin'"'"' ~/.profile'
R 'bash -l -c '"'"'type today'"'"''
R 'echo "--- ~/bin を作っただけ（このシェルの PATH はまだ古い） ---"; lab check 02; echo "exit=$?"'
R 'echo "--- bash ~/.profile は子のプロセスが読むだけ ---"; bash ~/.profile; echo $PATH'
R 'source ~/.profile'
R 'echo $PATH'
R 'today'
R 'lab check 02; echo "exit=$?"'

H "D. 演習03 — スクリプトを、全員が名前だけで使えるように置く"
R 'lab start 03'
R 'cd ~/work/03; ls -l'
R 'cat greet'
R 'bash greet; echo "exit=$?"'
R './greet; echo "exit=$?"'
R 'sh greet; echo "exit=$?"'
R 'head -1 greet; ls -l /bin/sh'
R 'lab check 03; echo "exit=$?"'
R 'echo "--- 先頭行だけ直して置く（所有者 lab・PATH 未対策） ---"'
R 'sed -i '"'"'1s|.*|#!/bin/bash|'"'"' greet; head -1 greet'
R './greet'
R 'sudo cp greet /usr/local/bin/greet; sudo chown lab /usr/local/bin/greet; ls -l /usr/local/bin/greet'
R 'sudo -iu alice greet'
R 'lab check 03; echo "exit=$?"'
R 'echo "--- 所有者と権限を直す。711 だと alice は読めない ---"'
R 'sudo chown root:root /usr/local/bin/greet; sudo chmod 711 /usr/local/bin/greet; ls -l /usr/local/bin/greet'
R 'sudo -u alice greet; echo "exit=$?"'
R 'sudo chmod 755 /usr/local/bin/greet; ls -l /usr/local/bin/greet'
R 'sudo -iu alice greet'
R 'echo "--- PATH の先頭に date の偽物がある人として実行する ---"'
R 'mkdir -p /tmp/fake; printf '"'"'#!/bin/sh\necho 偽物\n'"'"' > /tmp/fake/date; chmod 755 /tmp/fake/date'
R 'sudo -u alice env PATH=/tmp/fake:/usr/local/bin:/usr/bin:/bin greet'
R 'lab check 03; echo "exit=$?"'
R 'echo "--- 模範解答: 2行目で PATH を決める ---"'
R 'sed -i '"'"'1a PATH=/usr/bin:/bin'"'"' greet; head -3 greet'
R 'sudo cp greet /usr/local/bin/greet; sudo chown root:root /usr/local/bin/greet; sudo chmod 755 /usr/local/bin/greet; ls -l /usr/local/bin/greet'
R 'sudo -u alice env PATH=/tmp/fake:/usr/local/bin:/usr/bin:/bin greet'
R 'sudo -iu alice greet'
R 'lab check 03; echo "exit=$?"'
R 'cd ~'

H "E. 演習04 — 引数を数えて、使い方を出すスクリプト"
R 'lab start 04'
R 'cd ~/work/04; ls -l'
R 'lab check 04; echo "exit=$?"'
R 'echo "--- よくある間違い: \$* で回す ---"'
R 'printf '"'"'#!/bin/bash\nif [ $# -eq 0 ]; then\n    echo "使い方: mkbak.sh ファイル..." >&2\n    exit 1\nfi\nfor f in $*; do\n    cp "$f" "$f.bak"\ndone\necho "$# 個コピーした"\n'"'"' > mkbak.sh; cat mkbak.sh'
R 'bash mkbak.sh memo.txt "my notes.txt"; echo "exit=$?"'
R 'lab check 04; echo "exit=$?"'
R 'echo "--- 模範解答: \"\$@\" で回す ---"'
R 'sed -i '"'"'s/for f in \$\*; do/for f in "$@"; do/'"'"' mkbak.sh; cat mkbak.sh'
R 'bash mkbak.sh; echo "終了ステータス $?"'
R 'bash mkbak.sh memo.txt "my notes.txt"'
R 'ls -1'
R 'lab check 04; echo "exit=$?"'
R 'cd ~'

H "F. 演習05 — 成功と失敗を、終了ステータスで返すスクリプト"
R 'lab start 05'
R 'cd ~/work/05; cat isuser.sh'
R 'bash isuser.sh lab;        echo "終了ステータス $?"'
R 'bash isuser.sh nosuchuser; echo "終了ステータス $?"'
R 'grep "^lab:" /etc/passwd > /dev/null;        echo $?'
R 'grep "^nosuchuser:" /etc/passwd > /dev/null; echo $?'
R 'lab check 05; echo "exit=$?"'
R 'echo "--- 模範解答 ---"'
R 'printf '"'"'#!/bin/bash\n# 使い方: isuser.sh ユーザ名\nif [ $# -eq 0 ]; then\n    echo "使い方: isuser.sh ユーザ名" >&2\n    exit 2\nfi\nif grep -q "^$1:" /etc/passwd; then\n    exit 0\nelse\n    exit 1\nfi\n'"'"' > isuser.sh; cat isuser.sh'
R 'bash isuser.sh lab;        echo $?'
R 'bash isuser.sh nosuchuser; echo $?'
R 'bash isuser.sh la;         echo $?'
R 'bash isuser.sh;            echo $?'
R 'bash isuser.sh alice && echo "alice は居る"'
R 'lab check 05; echo "exit=$?"'
R 'cd ~'

H "G. 演習06 — 決まったコマンドだけを選ばせるメニュー"
R 'lab start 06'
R 'cd ~/work/06; cat menu.sh'
R 'lab check 06; echo "exit=$?"'
R 'echo "--- よくある間違い: while true で回す（入力が終わっても止まらない） ---"'
R 'printf '"'"'#!/bin/bash\necho "1) ユーザ名  2) ホスト名  q) 終了"\nwhile true; do\n    read -r ans\n    case "$ans" in\n        1) id -un ;;\n        2) hostname ;;\n        q) echo "終了します"; exit 0 ;;\n        *) echo "1・2・q のどれかを入力してください" ;;\n    esac\ndone\n'"'"' > menu.sh'
R 'printf '"'"'1\n2\nx\nq\n'"'"' | bash menu.sh; echo "終了ステータス $?"'
R 'lab check 06; echo "exit=$?"'
R 'echo "--- 模範解答: while read で回す ---"'
R 'printf '"'"'#!/bin/bash\necho "1) ユーザ名  2) ホスト名  q) 終了"\nwhile read -r ans; do\n    case "$ans" in\n        1) id -un ;;\n        2) hostname ;;\n        q) echo "終了します"; exit 0 ;;\n        *) echo "1・2・q のどれかを入力してください" ;;\n    esac\ndone\n'"'"' > menu.sh; cat menu.sh'
R 'printf '"'"'1\n2\nx\nq\n'"'"' | bash menu.sh; echo "終了ステータス $?"'
SESSION <<'IN'
cd ~/work/06
bash menu.sh
1
x
q
exit
IN
R 'lab check 06; echo "exit=$?"'
R 'cd ~'

H "H. 演習07 — ファイルごとに数えて、合計を出す"
R 'lab start 07'
R 'cd ~/work/07; cat count.sh'
R 'bash count.sh'
R 'wc -l logs/*.log'
R 'cat logs/a.log | while read -r line; do n=$((n + 1)); echo "中: n=$n"; done; echo "外: n=$n"'
R 'lab check 07; echo "exit=$?"'
R 'echo "--- 模範解答: done < \"\$f\" でつなぐ ---"'
R 'printf '"'"'#!/bin/bash\n# logs/ にある .log ファイルごとに行数を数え、最後に合計を出す。\ntotal=0\nfor f in logs/*.log; do\n    n=0\n    while read -r line; do\n        n=$((n + 1))\n    done < "$f"\n    echo "$f: $n 行"\n    total=$((total + n))\ndone\necho "合計: $total 行"\n'"'"' > count.sh; cat count.sh'
R 'bash count.sh'
R 'lab check 07; echo "exit=$?"'
R 'cd ~'

H "I. 演習08 — bash -x で原因を見つけて直す"
R 'lab start 08'
R 'cd ~/work/08; cat number.sh'
R 'bash number.sh alice bob carol'
R 'bash -x number.sh alice bob 2>&1 | grep -E '"'"'^\+ (i=|echo)'"'"''
R 'lab check 08; echo "exit=$?"'
R 'echo "--- 模範解答: 関数の中の i を local にする ---"'
R 'sed -i '"'"'/^line() {/a\    local i'"'"' number.sh; sed -n '"'"'3,7p'"'"' number.sh'
R 'bash number.sh alice bob carol'
R 'bash -x number.sh alice bob 2>&1 | grep -E '"'"'^\+ (i=|echo|local)'"'"''
R 'lab check 08; echo "exit=$?"'
R 'cd ~'

H "J. 全問通した状態で lab check（完走メッセージが出るはず）"
R 'lab check; echo "exit=$?"'
R 'lab ls'

H "L. lab reset の後も、配布ファイルを直して保存できる（1.0.2 で直した。1.0.1 では読み取り専用になった）"
R 'lab reset 06'
R 'ls -ld ~/work/06; ls -l ~/work/06'
R "echo '# x' >> ~/work/06/menu.sh; echo \"追記の終了ステータス \$?\"; tail -1 ~/work/06/menu.sh"
R 'lab reset 07'
R 'ls -ld ~/work/07 ~/work/07/logs; ls -l ~/work/07/count.sh'
R 'echo "--- 写しの元（/lab/seed）は root のもので、読者は書き換えられない ---"'
R 'ls -ld /lab/seed/06 /lab/seed/06/menu.sh'
R "echo '# x' >> /lab/seed/06/menu.sh; echo \"追記の終了ステータス \$?\""

H "K. 最終環境"
R 'lab env'
