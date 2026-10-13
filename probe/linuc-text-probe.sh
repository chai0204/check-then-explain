#!/bin/bash
# LinuC 主題1.03（GNU と Unix のコマンド）の本文に載せる全コマンドを、檻の中で実際に通す。
# ここに出ない出力は本文に書かない（憲章 §3）。
#
# 走らせ方: bash probe/linuc-text-run.sh probe （章ごとの起動から、章ページの作り直しまでやる）
# 中でやっていること（章ごとに新しいコンテナで走らせる。前の章の残り物が次の章の出力を変えないように）:
#   docker run -d --name linuc-text-probe-N --hostname linuc \
#     -v /home/lab/work -v /home/lab/.lab lab-linuc-text:1.0.1 sleep infinity
#   docker cp probe/linuc-text-probe.sh linuc-text-probe-N:/tmp/probe.sh
#   docker exec -u lab -w /home/lab linuc-text-probe-N bash -l -i /tmp/probe.sh N >> logs/linuc-text-probe.log
#   docker rm -f -v linuc-text-probe-N
#
# `bash -l -i` で走らせる理由: 読者が打つのは対話的なログインシェルである。
# ~/.bashrc が読まれて初めて alias（ls --color=auto など）と HISTCONTROL=ignoreboth が入る。
# 非対話で走らせると `type ls` も `echo $HISTSIZE` も読者の画面と違うものが記録される（実測 2026-10-13）。
#
# 端末が無いことで読者と違ってしまうもの（本文では避けている）:
#   - ls の段組（端末なら横に並ぶ。記録では1行1個）→ 本文では ls -l か ls -1 を使う
#   - man の折り返し幅（読者の端末の幅に従う）→ 本文では幅に依存しない行だけを見せる
#   - | less（端末なら画面が開く）→ 本文では less の出力をさらにパイプへ流した形だけ記録する
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
# 引用符が入り組むコマンドは here-doc で渡す（R の引数に書くと引用符の外し方が本文と変わる）
C() { local c; c=$(cat); printf '\n$ %s\n' "$c"; eval "$c" 2>&1; }
S() { printf '\n\n========== %s ==========\n' "$*"; }

# 対話シェルを本物の端末（pty）の上で動かし、打鍵を1行ずつ流し込む。履歴の記録に使う。
#   TERM=dumb にするのは、readline の制御文字（bracketed paste など）を記録に混ぜないため。
#   プロンプトは本文の約束に合わせて "$ " にする。先頭に空白を置いた行は履歴に残らない（HISTCONTROL=ignoreboth）。
feed() { sleep 1.5; while IFS= read -r l; do printf '%s\n' "$l"; sleep 0.7; done; sleep 1.5; }
session() { feed | TERM=dumb script -qec "bash -i" /dev/null | tr -d '\r'; }

# エディタ（vim / nano）を本物の端末（pty）の上で動かし、打鍵を流し込む。第10章で使う。
#   vim -es（Ex モード）で記録すると vimrc が読まれず Vi 互換モードになり、:w! の振る舞いが
#   読者の vim と違った（実測 2026-10-13）。だから読者と同じ設定の vim に、キーをそのまま渡す。
#   画面の描画（制御文字）は捨て、画面に出たエラーメッセージ（E37 など）だけを抜き出して記録する。
#   KEYS "表示用の打鍵" コマンド 打鍵1 打鍵2 ...   （打鍵は printf %b で送る。\r=Enter \033=ESC）
KEYS() {
  local show=$1 cmd=$2; shift 2
  printf '\n$ %s\n（打鍵: %s）\n' "$cmd" "$show"
  { sleep 1.2; for k in "$@"; do printf '%b' "$k"; sleep 0.5; done; sleep 1.2; } \
    | TERM=xterm script -qec "$cmd" /dev/null > /tmp/screen.raw 2>&1
  grep -ao 'E[0-9]\{2,3\}: [^[:cntrl:]]*' /tmp/screen.raw | sort -u
}

# docker exec のプロセスは umask 0000 で始まる（docker run で起動した読者のシェルは 0022。実測 2026-10-13）。
# 読者と同じにするため、記録を始める前にそろえる（この行は記録に出ない）。
umask 022

ch=${1:-all}
want() { [ "$ch" = all ] || [ "$ch" = "$1" ]; }

if want 0; then
S "0. 環境"
R lab env
R 'id; pwd'
R 'ls -l ~/text'
R 'ls -l ~/text/files ~/text/files/sub'
fi

if want 1; then
S "1. 引用符と変数（1.03.1）"
R 'cd ~/text'
R 'echo $HOME'
C <<'X'
echo '$HOME'
X
R 'echo "$HOME"'
R 'echo \$HOME'
R 'echo "私は $(whoami) です"'
C <<'X'
echo '私は $(whoami) です'
X
R 'echo "私は `whoami` です"'
R 'echo a     b'
R 'echo "a     b"'
R 'msg="a     b"'
R 'echo $msg'
R 'echo "$msg"'
R 'echo *.csv'
R 'echo "*.csv"'
C <<'X'
echo -e 'a\tb'
X
C <<'X'
echo 'a\tb'
X
R 'echo -n "改行なし"; echo "←ここまでが1行"'
R 'cat child.sh'
R 'GREETING=hello'
R 'echo "$GREETING"'
R 'bash child.sh'
R 'export GREETING'
R 'bash child.sh'
R 'env | grep GREETING'
R 'set | grep "^GREETING="'
R 'LOCAL_ONLY=here'
R 'set | grep "^LOCAL_ONLY="'
R 'env | grep "^LOCAL_ONLY="; echo "exit=$?"'
R 'export -p | grep GREETING'
R 'GREETING=bye bash child.sh'
R 'echo "$GREETING"'
R 'env GREETING=env-bye bash child.sh'
R 'env -i bash child.sh'
R 'unset GREETING'
R 'echo "[$GREETING]"'
R 'bash child.sh'
R 'X=1 echo "[$X]"'
R 'X=1; echo "[$X]"'
R 'unset X'
R 'set -o | grep -E "^(noclobber|xtrace|history) "'
R 'bash -x child.sh'
R 'env | grep -E "^(HOME|LANG)="'
R 'env | grep -c "^PATH="'
R 'set | grep -c "^PATH="'
R 'set | grep -c "^HISTSIZE="'
R 'env | grep -c "^HISTSIZE="'
R 'echo $SHLVL; bash -c "echo \$SHLVL"'
fi

if want 2; then
S "2. コマンドの在り処と履歴（1.03.1）"
R 'cd ~/text'
R 'pwd'
R 'ls -l hello.sh cdtest.sh'
R 'cat hello.sh'
R 'hello.sh; echo "exit=$?"'
R './hello.sh; echo "exit=$?"'
R 'bash hello.sh'
R 'chmod +x hello.sh'
R './hello.sh'
R '~/text/hello.sh'
R '/home/lab/text/hello.sh'
R 'cd /tmp'
R '../home/lab/text/hello.sh'
R 'cd ~/text'
R 'echo "$PATH"'
R 'type ls'
R 'type cd'
R 'type pwd'
R 'type -a pwd'
R 'type hello.sh'
R 'type ./hello.sh'
R 'which ls'
R 'ls -ld . ..'
R 'cd ..; pwd'
R 'cd text; pwd'
R 'cd /usr/share; pwd'
R 'cd -'
R 'cat cdtest.sh'
R 'bash cdtest.sh'
R 'pwd'
R '. cdtest.sh'
R 'pwd'
R 'cd ~/text'
R 'PATH="$PATH:$HOME/text"'
R 'hello.sh'
R 'type hello.sh'
R 'cd /; hello.sh; cd ~/text'
R 'grep -n HIST ~/.bashrc'
R 'echo "HISTFILE=$HISTFILE HISTSIZE=$HISTSIZE HISTFILESIZE=$HISTFILESIZE HISTCONTROL=$HISTCONTROL"'
R 'ls -l ~/.bash_history; echo "exit=$?"'
echo
echo '--- ここから下は、端末（pty）の上で対話シェルを動かし、1行ずつ打鍵した記録 ---'
session <<'KEYS'
 export PROMPT_COMMAND='PS1="\$ "'
bash
history -c
echo 一行目
echo 二行目
history
!1
!ec
!!
 echo 先頭に空白を置いた
echo 二行目
echo 二行目
history
history 2
tail -3 ~/.bash_history
exit
tail -5 ~/.bash_history
exit
KEYS
echo '--- 対話の記録ここまで ---'
fi

if want 3; then
S "3. man の読み方（1.03.1）"
R 'cd ~/text'
R 'man -f passwd'
R 'whatis passwd'
R 'man -w passwd'
R 'man -w 5 passwd'
R 'man passwd | grep -A1 "^NAME"'
R 'man 5 passwd | grep -A1 "^NAME"'
R 'man -k "^regex"'
R 'apropos "^regex"'
R 'man -f regex'
R 'man 7 regex | grep -A1 "^NAME"'
R 'man -k "regular expression" | sort'
R 'ls -d /usr/share/man/man[0-9]'
R 'man ls | grep -E "^ +-l +"'
R 'man ls | grep -A1 -E "^ +-a, --all"'
R 'man -f echo'
R 'man echo | grep -A1 "^NAME"'
R 'man echo | grep -E "^ +--version"'
R 'echo --version'
R 'type echo'
R 'type -a echo'
R '/usr/bin/echo --version | head -1'
R 'help echo | head -3'
R 'man cd; echo "exit=$?"'
R 'man -f cd; echo "exit=$?"'
R 'help cd | head -3'
R 'type cd'
R 'man -f printf'
R 'man 1 printf | grep -A1 "^NAME"'
R 'man -w 3 printf; echo "exit=$?"'
R 'man -k "^printf"'
R 'man bash | grep -E "^ +history \[n\]"'
fi

if want 4; then
S "4. 行を数える・覗く（1.03.2）"
R 'cd ~/text'
R 'cat fruits.txt'
R 'cat -n fruits.txt'
R 'head -3 fruits.txt'
R 'head -n 3 fruits.txt'
R 'tail -2 fruits.txt'
R 'tail -n +6 fruits.txt'
R 'head -n -5 fruits.txt'
R 'head -c 12 fruits.txt'
R 'wc fruits.txt'
R 'wc -l fruits.txt'
R 'wc -w -c fruits.txt'
R 'wc -l < fruits.txt'
R 'cat fruits.txt | wc -l'
R 'cat notail.txt'
R 'wc -l notail.txt'
R 'od -c notail.txt'
R 'cat -A notail.txt'
R 'echo >> notail.txt; wc -l notail.txt'
R 'cat unix.txt'
R 'cat win.txt'
R 'wc -c unix.txt win.txt'
R 'od -c unix.txt'
R 'od -c win.txt'
R 'cat -A win.txt'
R 'od -An -tx1 unix.txt'
R 'od -t x1 -A d unix.txt'
R 'cat blank.txt'
R 'nl blank.txt'
R 'cat -n blank.txt'
R 'nl -b a blank.txt'
R 'nl fruits.txt'
R 'nl -w 2 -s ": " fruits.txt'
R 'less fruits.txt | head -3'
R 'seq 1 100 | less | tail -2'
R 'printf "line %s\n" 1 2 3 > /tmp/watch.log'
R 'timeout 2 tail -f /tmp/watch.log; echo "exit=$?"'
R '(sleep 1; echo "あとから追記した行" >> /tmp/watch.log) | timeout 3 tail -n 1 -f /tmp/watch.log; echo "exit=$?"'
R 'cat -s blank.txt | cat -A'
fi

if want 5; then
S "5. 列と並び（1.03.2）"
R 'cd ~/text'
R 'cat scores.csv'
R 'cut -d, -f2 scores.csv'
R 'cut -d, -f2,4 scores.csv'
R 'cut -d, -f2- scores.csv'
R 'cut -c1-3 fruits.txt'
R 'cat -A tabs.txt'
R 'cut -f2 tabs.txt'
R 'cut -d, -f2 tabs.txt'
R 'cat spaces.txt'
R 'cut -d" " -f2 spaces.txt'
R 'cut -d" " -f2 spaces.txt | cat -A'
R 'cut -d" " -f4 spaces.txt'
R 'tr -s " " < spaces.txt'
R 'tr -s " " < spaces.txt | cut -d" " -f2'
R 'tr a-z A-Z < fruits.txt'
R 'tr -d "a" < fruits.txt'
R 'tr "," "\t" < scores.csv | cat -A | head -2'
R 'tr a-z A-Z fruits.txt; echo "exit=$?"'
R 'cat fruits.txt | tr a-z A-Z'
R 'sort fruits.txt'
R 'sort -r fruits.txt'
R 'sort -f fruits.txt'
R 'uniq fruits.txt'
R 'sort fruits.txt | uniq'
R 'sort fruits.txt | uniq -c'
R 'sort fruits.txt | uniq -c | sort -rn'
R 'sort fruits.txt | uniq -d'
R 'sort fruits.txt | uniq -u'
R 'sort -u fruits.txt'
R 'tail -n +2 scores.csv | sort -t, -k4'
R 'tail -n +2 scores.csv | sort -t, -k4 -n'
R 'tail -n +2 scores.csv | sort -t, -k4 -nr'
R 'tail -n +2 scores.csv | sort -t, -k3,3 -k4,4nr'
R 'cat names.txt'
R 'cat mails.txt'
R 'paste names.txt mails.txt'
R 'paste -d, names.txt mails.txt'
R 'paste -s -d, fruits.txt'
R 'join names.txt mails.txt'
R 'join -a1 names.txt mails.txt'
R 'join -v1 names.txt mails.txt'
R 'sort -r names.txt > /tmp/names-r.txt; cat /tmp/names-r.txt'
R 'join /tmp/names-r.txt mails.txt; echo "exit=$?"'
R 'echo "B a A b" | tr " " "\n" | sort'
R 'locale | head -3'
fi

if want 6; then
S "6. sed と整形（1.03.2 / 1.03.4）"
R 'cd ~/text'
R 'cat app.conf'
R 'sed "s/8080/9090/" app.conf'
R 'grep -c 9090 app.conf'
R 'sed "s/=/ = /" app.conf'
R 'sed "s/=/ = /g" app.conf'
R 'sed "s/port/PORT/" app.conf'
R 'sed "s/^port=/PORT=/" app.conf'
R 'sed -n "2,4p" app.conf'
R 'sed -n "/port/p" app.conf'
R 'sed "/^#/d" app.conf'
R 'sed "1d" app.conf'
R 'sed "\$d" app.conf'
R 'sed -n "\$p" app.conf'
R 'sed -e "/^#/d" -e "s/8080/9090/g" app.conf'
R 'sed "s|http://localhost|https://example.com|" app.conf | tail -1'
R 'sed -E "s/^([a-z_]+)=(.*)$/\1: \2/" app.conf'
R 'sed "3q" app.conf'
R 'sed "2i\\# ここに挿入" app.conf | head -4'
R 'sed "y/abc/ABC/" fruits.txt'
R 'cp app.conf my.conf'
R 'ls -i my.conf'
R 'sed -i "s/^port=8080/port=9090/" my.conf'
R 'ls -i my.conf'
R 'grep ^port= my.conf'
R 'sed -i.bak "/^#/d" my.conf'
R 'ls -1 my.conf*'
R 'cat my.conf'
R 'diff my.conf.bak my.conf'
R 'ln my.conf hard.conf'
R 'ls -i my.conf hard.conf'
R 'sed -i "s/^port=9090/port=7070/" my.conf'
R 'ls -i my.conf hard.conf'
R 'grep ^port= my.conf hard.conf'
R 'cat -A tabs.txt'
R 'expand tabs.txt'
R 'expand tabs.txt | cat -A'
R 'expand -t 4 tabs.txt | cat -A'
R 'cat -A indent.txt'
R 'expand indent.txt | cat -A'
R 'expand indent.txt | unexpand | cat -A'
R 'expand indent.txt | unexpand -a | cat -A'
R 'cat poem.txt'
R 'fmt -w 40 poem.txt'
R 'fmt -w 40 poem.txt | wc -L'
R 'fmt -w 20 jp.txt'
R 'pr fruits.txt | head -5'
R 'pr -3 -t fruits.txt'
R 'pr -l 12 fruits.txt | grep -c "Page"'
R 'seq 2500 > big.txt'
R 'split big.txt'
R 'wc -l xa*'
R 'split -l 1000 -d big.txt part_'
R 'wc -l part_*'
R 'split -n 2 fruits.txt half_; wc -c half_*'
R 'cat half_aa; echo "<-- ここまでが half_aa"'
R 'split -n l/2 fruits.txt line_; wc -l line_*'
R 'cat xa* | wc -l'
R 'cat xa* | cmp - big.txt; echo "exit=$?"'
fi

if want 7; then
S "7. リダイレクト（1.03.3）"
R 'cd ~/text'
R 'ls fruits.txt nosuch.txt'
R 'ls fruits.txt nosuch.txt > out.txt'
R 'cat out.txt'
R 'ls fruits.txt nosuch.txt 2> err.txt'
R 'cat err.txt'
R 'ls fruits.txt nosuch.txt > both.txt 2>&1'
R 'cat both.txt'
R 'ls fruits.txt nosuch.txt 2>&1 > only.txt'
R 'cat only.txt'
R 'ls fruits.txt nosuch.txt &> amp.txt'
R 'cat amp.txt'
R 'ls fruits.txt nosuch.txt 2> /dev/null'
R 'ls fruits.txt nosuch.txt > /dev/null'
R 'stat -c "%A %F" /dev/null'
R 'echo first > note.txt'
R 'echo second > note.txt'
R 'cat note.txt'
R 'echo third >> note.txt'
R 'cat note.txt'
R 'ls nosuch.txt 2>> note.txt'
R 'cat note.txt'
R 'wc -l < fruits.txt'
R 'tr a-z A-Z < fruits.txt > upper.txt'
R 'cat upper.txt'
R 'cp fruits.txt copy.txt'
R 'sort copy.txt > copy.txt'
R 'wc -c copy.txt'
R 'cp fruits.txt copy.txt'
R 'sort copy.txt -o copy.txt'
R 'head -2 copy.txt'
R 'set -o noclobber'
R 'echo again > note.txt'
R 'echo again >| note.txt'
R 'cat note.txt'
R 'set +o noclobber'
C <<'X'
cat << EOF > greet.txt
hello, $HOME
EOF
X
R 'cat greet.txt'
C <<'X'
cat << 'EOF'
hello, $HOME
EOF
X
R 'tr a-z A-Z <<< "here string"'
R 'ls nosuch.txt; echo "exit=$?"'
R 'ls fruits.txt; echo "exit=$?"'
fi

if want 8; then
S "8. パイプと xargs と tee（1.03.3）"
R 'cd ~/text'
R 'cut -d" " -f9 access.log | sort | uniq -c | sort -rn'
R 'ls nosuch.txt | wc -l'
R 'ls nosuch.txt 2>&1 | wc -l'
R 'ls nosuch.txt |& wc -l'
R 'find files -type f | sort'
R 'find files -name "*.tmp" | sort'
R 'find files -name "*.tmp" | sort | xargs ls -l'
R 'find files -name "*.tmp" -print0 | sort -z | xargs -0 ls -l'
R 'find files -name "*.tmp" -exec ls -l {} +'
R 'echo a b c | xargs echo'
R 'echo a b c | xargs -n 1 echo'
R 'echo a b c | xargs -n 2 echo'
R 'printf "%s\n" apple banana | xargs -I{} echo "果物: {}"'
R 'echo "report 2026.txt" | xargs ls -l'
R 'find files -name "*.tmp" | sort | xargs -n 1 echo'
R 'find files -name "*.tmp" -print0 | sort -z | xargs -0 -n 1 echo'
R 'printf "%s\n" "files/old data.tmp" | xargs -d "\n" ls -l'
R 'cut -d" " -f1 access.log | sort | uniq -c | sort -rn | tee ip-count.txt | head -2'
R 'cat ip-count.txt'
R 'echo "追記" | tee -a ip-count.txt'
R 'tail -2 ip-count.txt'
R 'echo "ここは $(pwd)"'
R 'echo "ここは `pwd`"'
R 'echo "果物は $(wc -l < fruits.txt) 行"'
R 'wc -l $(find files -name "*.txt" | sort)'
R 'false | true; echo "exit=$? PIPESTATUS=${PIPESTATUS[*]}"'
R 'find files -name "*.tmp" | sort | xargs rm; echo "exit=$?"'
R 'find files -name "*.tmp" | sort'
R 'find files -name "*.tmp" -print0 | xargs -0 rm'
R 'find files -name "*.tmp" | wc -l'
fi

if want 9; then
S "9. 正規表現と grep（1.03.4）"
R 'cd ~/text'
R 'cat ips.txt'
R 'grep 10.0.0.5 ips.txt'
R 'grep -F 10.0.0.5 ips.txt'
R 'grep "10\.0\.0\.5" ips.txt'
R 'grep -x "10\.0\.0\.5" ips.txt'
R 'grep -w 10.0.0.5 ips.txt'
R 'grep -Fx 10.0.0.5 ips.txt'
R 'cat server.log'
R 'grep ERROR server.log'
R 'grep -c ERROR server.log'
R 'grep -n ERROR server.log'
R 'grep -E "^[0-9-]+ [0-9:]+ ERROR" server.log'
R 'grep -v INFO server.log'
R 'grep -i info server.log'
R 'grep WARN server.log'
R 'grep -w WARN server.log'
R 'grep -l ERROR access.log server.log app.conf'
R 'grep -c 8080 access.log server.log app.conf'
R 'grep -rl 8080 . | sort'
R 'grep -E "ERROR|WARN" server.log'
R 'grep "ERROR|WARN" server.log; echo "exit=$?"'
R 'grep "ERROR\|WARN" server.log'
R 'egrep "ERROR|WARN" server.log'
R 'cat /usr/bin/egrep'
R 'cat /usr/bin/fgrep'
R 'zcat /usr/share/doc/grep/changelog.Debian.gz | grep -m1 disable-egrep'
R 'fgrep 10.0.0.5 ips.txt'
R 'egrep -c ERROR server.log 2>/dev/null'
R 'grep "ap+le" fruits.txt; echo "exit=$?"'
R 'grep -E "ap+le" fruits.txt'
R 'grep "ap\+le" fruits.txt'
R 'grep "^b" fruits.txt'
R 'grep "a$" fruits.txt'
R 'grep "^[A-Z]" fruits.txt'
R 'grep -E "^(apple|cherry)$" fruits.txt'
R 'grep -c "" fruits.txt'
R 'grep -c "x*" fruits.txt'
R 'grep "an*a" fruits.txt'
R 'grep -o "an*a" fruits.txt'
R 'grep -E "[0-9]{3}" server.log | head -3'
R 'grep "[0-9]\{3\}" server.log | head -3'
R 'grep -v "^$" blank.txt'
R 'grep "line1$" unix.txt win.txt'
R 'echo grep a* fruits.txt'
R 'grep a* fruits.txt; echo "exit=$?"'
R 'grep "a*" fruits.txt | head -3'
R 'grep -E "^.{6,}$" fruits.txt'
R 'sed -n "/^b/p" fruits.txt'
R 'sed -E "s/^([0-9-]+) ([0-9:]+) /\2 /" server.log | head -2'
R 'sed "s/[0-9]\{1,\}/N/g" ips.txt'
R 'man 7 regex | grep -A1 "^NAME"'
R 'man grep | grep -E "^ +-[EFGP], --"'
fi

if want 10; then
S "10. vi とエディタの切り替え（1.03.5）"
R 'cd ~/text'
R 'cat memo.txt'
R 'cp memo.txt v1.txt'
KEYS 'j dd :wq⏎' 'vim v1.txt' 'j' 'dd' ':wq\r'
R 'cat v1.txt'
KEYS ':call writefile([line(".")], "/tmp/pos.txt")⏎ :q⏎' 'vim v1.txt' ':call writefile([line(".")], "/tmp/pos.txt")\r' ':q\r'
R 'cat /tmp/pos.txt'
R 'grep -n -A3 "jump to the last known cursor" /usr/share/vim/vim91/defaults.vim'
R 'cp memo.txt v2.txt'
KEYS 'yy p :wq⏎' 'vim v2.txt' 'yy' 'p' ':wq\r'
R 'cat v2.txt'
R 'cp memo.txt v3.txt'
KEYS 'j dd p :wq⏎' 'vim v3.txt' 'j' 'dd' 'p' ':wq\r'
R 'cat v3.txt'
R 'cp memo.txt v4.txt'
KEYS 'G yy k P :wq⏎' 'vim v4.txt' 'G' 'yy' 'k' 'P' ':wq\r'
R 'cat v4.txt'
R 'cp memo.txt v5.txt'
KEYS 'o fig ESC :wq⏎' 'vim v5.txt' 'o' 'fig' '\033' ':wq\r'
R 'cat v5.txt'
R 'cp memo.txt v6.txt'
KEYS 'O fruits: ESC :wq⏎' 'vim v6.txt' 'O' 'fruits:' '\033' ':wq\r'
R 'cat v6.txt'
R 'cp memo.txt v7.txt'
KEYS 'i big␣ ESC :wq⏎' 'vim v7.txt' 'i' 'big ' '\033' ':wq\r'
R 'cat v7.txt'
R 'cp memo.txt v8.txt'
KEYS 'a - ESC :wq⏎' 'vim v8.txt' 'a' '-' '\033' ':wq\r'
R 'cat v8.txt'
R 'cp memo.txt v9.txt'
KEYS '/an⏎ x :wq⏎' 'vim v9.txt' '/an\r' 'x' ':wq\r'
R 'cat v9.txt'
R 'cp memo.txt v10.txt'
KEYS 'G ?an⏎ x :wq⏎' 'vim v10.txt' 'G' '?an\r' 'x' ':wq\r'
R 'cat v10.txt'
R 'cp memo.txt v11.txt'
KEYS 'jj cw CHERRY ESC :wq⏎' 'vim v11.txt' 'j' 'j' 'cw' 'CHERRY' '\033' ':wq\r'
R 'cat v11.txt'
R 'cp memo.txt v12.txt'
KEYS 'j l l x :wq⏎' 'vim v12.txt' 'j' 'l' 'l' 'x' ':wq\r'
R 'cat v12.txt'
R 'cp memo.txt v13.txt'
KEYS 'j $ h x :wq⏎' 'vim v13.txt' 'j' '$' 'h' 'x' ':wq\r'
R 'cat v13.txt'
R 'cp memo.txt v14.txt'
KEYS 'j d$ :wq⏎' 'vim v14.txt' 'j' 'd$' ':wq\r'
R 'cat -A v14.txt'
R 'cp memo.txt v15.txt'
KEYS 'j yw P :wq⏎' 'vim v15.txt' 'j' 'yw' 'P' ':wq\r'
R 'cat v15.txt'
R 'cp memo.txt v16.txt'
KEYS '2dd :wq⏎' 'vim v16.txt' '2dd' ':wq\r'
R 'cat v16.txt'
R 'cp memo.txt v17.txt'
KEYS 'dd ZZ' 'vim v17.txt' 'dd' 'ZZ'
R 'cat v17.txt'
R 'cp memo.txt q1.txt'
KEYS 'dd :q⏎ :q!⏎' 'vim q1.txt' 'dd' ':q\r' ':q!\r'
R 'cat q1.txt'
R 'cp memo.txt q2.txt'
KEYS 'dd dd :e!⏎ :wq⏎' 'vim q2.txt' 'dd' 'dd' ':e!\r' ':wq\r'
R 'cat q2.txt'
R 'cp memo.txt ro.txt; chmod 444 ro.txt'
R 'stat -c "%A %s %n" ro.txt'
R 'echo kiwi >> ro.txt; echo "exit=$?"'
KEYS 'dd :w⏎ :w!⏎ :q⏎' 'vim ro.txt' 'dd' ':w\r' ':w!\r' ':q\r'
R 'cat ro.txt'
R 'stat -c "%A %s %n" ro.txt'
R 'cp memo.txt ro2.txt; chmod 444 ro2.txt'
R 'vim -es -c "normal! dd" -c "w!" -c q ro2.txt; echo "exit=$?"'
R 'cat ro2.txt'
R 'vim -es -N -c "normal! dd" -c "w!" -c q ro2.txt; echo "exit=$?"'
R 'cat ro2.txt'
R 'cp memo.txt n1.txt'
KEYS '^K ^O ⏎ ^X' 'nano n1.txt' '\013' '\017' '\r' '\030'
R 'cat n1.txt'
R 'cp memo.txt n2.txt'
KEYS '^W cherry⏎ ^K ^X y ⏎' 'nano n2.txt' '\027' 'cherry\r' '\013' '\030' 'y' '\r'
R 'cat n2.txt'
R 'ls -l /usr/bin/vi /etc/alternatives/vi'
R 'ls -l /usr/bin/editor /etc/alternatives/editor'
R 'update-alternatives --display editor | head -4'
R 'update-alternatives --display editor | grep priority'
R 'editor --version | head -1'
R 'echo "[$EDITOR]"'
R 'EDITOR=vi sensible-editor --version | head -1'
R 'EDITOR=nano sensible-editor --version | head -1'
R 'EDITOR=vi'
R 'bash -c "sensible-editor --version" < /dev/null | head -1'
R 'export EDITOR'
R 'bash -c "sensible-editor --version" | head -1'
R 'env | grep "^EDITOR="'
R 'unset EDITOR'
R 'command -v emacs; echo "exit=$?"'
R 'nano --version | head -1'
R 'vim --version | head -1'
R 'ls -l ~/.viminfo | cut -c1-10'
fi
