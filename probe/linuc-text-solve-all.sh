#!/bin/bash
# 全演習を模範解答どおりに通す。目的は2つ。
#   1) 未達のとき判定が ✗ を出し、観測した事実を出すこと（鳴らない検査は無いより悪い）
#   2) 解答どおりにやれば ✔ になること
# 途中で「読者がやりがちな間違い」も1つずつ踏み、そのとき判定が何を観測するかを記録する。
#
# 走らせ方: bash probe/linuc-text-run.sh solve
# 中でやっていること（読者と同じ起動オプション。1つのコンテナで最初から最後まで通す）:
#   docker run -d --name linuc-text-solve --hostname linuc \
#     -v /home/lab/work -v /home/lab/.lab lab-linuc-text:1.0.0 sleep infinity
#   docker cp probe/linuc-text-solve-all.sh linuc-text-solve:/tmp/solve.sh
#   docker exec -u lab -w /home/lab linuc-text-solve bash -l -i /tmp/solve.sh > logs/linuc-text-solve-all.log
#   docker rm -f -v linuc-text-solve
# 対話的なログインシェル（bash -l -i）で走らせる理由は probe と同じ。lab check は
# このシェルの子プロセスなので、export した変数と PATH がそのまま判定に届く。
# docker exec のプロセスは umask 0000 で始まる（docker run で起動した読者のシェルは 0022。実測 2026-10-13）。
# 読者と同じにするため、記録を始める前にそろえる（この行は記録に出ない）。
umask 022
H() { printf '\n\n########## %s ##########\n' "$*"; }
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
C() { local c; c=$(cat); printf '\n$ %s\n' "$c"; eval "$c" 2>&1; }
KEYS() {
  local show=$1 cmd=$2; shift 2
  printf '\n$ %s\n（打鍵: %s）\n' "$cmd" "$show"
  { sleep 1.2; for k in "$@"; do printf '%b' "$k"; sleep 0.5; done; sleep 1.2; } \
    | TERM=xterm script -qec "$cmd" /dev/null > /tmp/screen.raw 2>&1
  grep -ao 'E[0-9]\{2,3\}: [^[:cntrl:]]*' /tmp/screen.raw | sort -u
}

H "A. 何もしていない状態で lab check（01 は ✗、ほかは lab start 前なので ⚠ になるはず）"
R 'lab check; echo "exit=$?"'
R 'lab ls'

H "B. 演習01 — 標準のエディタを vi にする"
R 'lab start 01'
R 'echo "[$EDITOR]"; editor --version | head -1'
R 'lab check 01; echo "exit=$?"'
R 'echo "--- 値を入れただけ（シェル変数）---"'
R 'EDITOR=vi'
R 'echo "[$EDITOR]"; bash -c "echo \"子から見ると [\$EDITOR]\""'
R 'lab check 01; echo "exit=$?"'
R 'echo "--- export する ---"'
R 'export EDITOR'
R 'lab check 01; echo "exit=$?"'

H "C. 演習02 — 自作のコマンドを名前だけで動かす"
R 'lab start 02'
R 'cd ~/work/02'
R 'ls -l bin/'
R '~/work/02/bin/greet'
R 'greet; echo "exit=$?"'
R 'lab check 02; echo "exit=$?"'
R 'echo "--- 相対パスで足す（よくある間違い）---"'
R 'PATH="$PATH:bin"'
R 'greet'
R 'lab check 02; echo "exit=$?"'
R 'PATH="${PATH%:bin}"; echo "$PATH"'
R 'echo "--- 絶対パスで足す ---"'
R 'PATH="$PATH:$HOME/work/02/bin"'
R 'cd /tmp; greet; cd ~/work/02'
R 'lab check 02; echo "exit=$?"'
R 'echo "--- 参考: 引用符の中の ~ は文字のまま PATH に入る ---"'
C <<'X'
bash -c 'PATH="/usr/bin:/bin:~/work/02/bin"; echo "$PATH"; cd /tmp; type -P greet; env greet; echo "env の終了コード=$?"'
X

H "D. 演習03 — アクセスログのステータスを数える"
R 'lab start 03'
R 'cd ~/work/03'
R 'head -3 access.log; wc -l access.log'
R 'lab check 03; echo "exit=$?"'
R 'echo "--- sort を抜くと（よくある間違い）---"'
R 'cut -d" " -f9 access.log | uniq -c | sort -rn > answer.txt; head -4 answer.txt; wc -l answer.txt'
R 'lab check 03; echo "exit=$?"'
R 'echo "--- 模範解答 ---"'
R 'cut -d" " -f9 access.log | uniq -c | head -4'
R 'cut -d" " -f9 access.log | sort | uniq -c | sort -rn > answer.txt'
R 'cat answer.txt'
R 'lab check 03; echo "exit=$?"'

H "E. 演習04 — 設定ファイルを sed で書き換える"
R 'lab start 04'
R 'cd ~/work/04'
R 'cat app.conf'
R 'lab check 04; echo "exit=$?"'
R 'echo "--- 行頭を決めずに置換し、.bak も残さない（よくある間違い）---"'
R 'sed "s/8080/9090/" app.conf | grep 9090'
R 'sed -i "s/8080/9090/" app.conf'
R 'lab check 04; echo "exit=$?"'
R 'lab reset 04'
R 'cat app.conf; echo "exit=$?"'
R 'cd ~/work/04; cat app.conf'
R 'echo "--- 模範解答 ---"'
R 'sed -i.bak -e "s/^port=8080$/port=9090/" -e "/^#/d" app.conf'
R 'cat app.conf'
R 'diff app.conf.bak app.conf'
R 'lab check 04; echo "exit=$?"'

H "F. 演習05 — 出力を2本に分けて保存する"
R 'lab start 05'
R 'cd ~/work/05'
R './check.sh'
R 'lab check 05; echo "exit=$?"'
R 'echo "--- 2>&1 を先に書く（よくある間違い）---"'
R './check.sh > ok.log'
R './check.sh 2>&1 > all.log'
R 'lab check 05; echo "exit=$?"'
R 'echo "--- 模範解答 ---"'
R './check.sh > ok.log 2> ng.log'
R './check.sh > all.log 2>&1'
R 'cat all.log'
R 'lab check 05; echo "exit=$?"'

H "G. 演習06 — 名前に空白のあるファイルもまとめて消す"
R 'lab start 06'
R 'cd ~/work/06'
R 'find . -type f | sort'
R 'lab check 06; echo "exit=$?"'
R 'echo "--- -print0 / -0 なしで消す（よくある間違い）---"'
R 'find . -name "*.tmp" | xargs -n 1 echo'
R 'find . -name "*.tmp" | xargs rm; echo "exit=$?"'
R 'lab check 06; echo "exit=$?"'
R 'echo "--- 模範解答 ---"'
R 'find . -name "*.tmp" -print0 | xargs -0 rm'
R 'find . -type f | sort'
R 'lab check 06; echo "exit=$?"'

H "H. 演習07 — レベルが ERROR か WARN の行だけを抜き出す"
R 'lab start 07'
R 'cd ~/work/07'
R 'grep -c ERROR server.log'
R 'lab check 07; echo "exit=$?"'
R 'echo "--- 位置を決めずに選ぶ（よくある間違い）---"'
R 'grep -E "ERROR|WARN" server.log > hits.txt; wc -l hits.txt'
R 'lab check 07; echo "exit=$?"'
R 'echo "--- 模範解答 ---"'
R 'grep -E "^[^ ]+ [^ ]+ (ERROR|WARN) " server.log > hits.txt'
R 'cat hits.txt'
R 'lab check 07; echo "exit=$?"'

H "I. 演習08 — vi で TODO を直す（本物の vim に打鍵を流し込む）"
R 'lab start 08'
R 'cd ~/work/08'
R 'cat todo.txt'
R 'lab check 08; echo "exit=$?"'
R 'echo "--- buy milk を切り取った後に call bob も dd してから貼る（順番の間違い）---"'
KEYS 'j dd j dd G p :wq⏎' 'vim todo.txt' 'j' 'dd' 'j' 'dd' 'G' 'p' ':wq\r'
R 'cat todo.txt'
R 'lab check 08; echo "exit=$?"'
R 'lab reset 08'
R 'cd ~/work/08'
R 'echo "--- 模範解答 ---"'
KEYS 'gg j dd G p gg j o buy␣eggs ESC j dd /report⏎ cw summary ESC :wq⏎' 'vim todo.txt' 'gg' 'j' 'dd' 'G' 'p' 'gg' 'j' 'o' 'buy eggs' '\033' 'j' 'dd' '/report\r' 'cw' 'summary' '\033' ':wq\r'
R 'cat todo.txt'
R 'lab check 08; echo "exit=$?"'

H "J. 全問通した状態で lab check と lab ls"
R 'lab check; echo "exit=$?"'
R 'lab ls'

H "K. 最終環境"
R 'lab env'
