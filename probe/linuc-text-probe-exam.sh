#!/bin/bash
# LinuC 主題1.03 の試験対策の追加の記録（公式例題 101 の監査で足した箇所。2026-10-13）。
# イメージは lab-linuc-text:1.0.1（公開済み。作り直さない）。
#
# 走らせ方: bash probe/linuc-text-run.sh exam
#   章ごとに新しいコンテナで、読者と同じ起動オプション（--hostname linuc と2つのボリューム）で
#   bash -l -i /tmp/probe-exam.sh N を走らせ、logs/linuc-text-probe-exam.log にまとめる。
#   本文の雛形では、この記録から引くブロックを <pre><code>@@exam … @@</code></pre>、
#   対話の記録を {{SESSION@exam a-b}} と書く。
#
# 記録の約束は linuc-text-probe.sh と同じ（対話的なログインシェル、umask 022、pty の上の打鍵）。
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
S() { printf '\n\n========== %s ==========\n' "$*"; }
feed() { sleep 1.5; while IFS= read -r l; do printf '%s\n' "$l"; sleep 0.9; done; sleep 2; }
session() { feed | TERM=dumb script -qec "bash -i" /dev/null | tr -d '\r'; }
KEYS() {
  local show=$1 cmd=$2; shift 2
  printf '\n$ %s\n（打鍵: %s）\n' "$cmd" "$show"
  { sleep 1.2; for k in "$@"; do printf '%b' "$k"; sleep 0.5; done; sleep 1.2; } \
    | TERM=xterm script -qec "$cmd" /dev/null > /tmp/screen.raw 2>&1
  grep -ao 'E[0-9]\{2,3\}: [^[:cntrl:]]*' /tmp/screen.raw | sort -u
}
umask 022

ch=${1:-all}
want() { [ "$ch" = all ] || [ "$ch" = "$1" ]; }

if want 2; then
S "2. コマンドの在り処と履歴（試験対策の追加）"
R 'cd ~/text'
echo
echo '--- ここから下は、端末（pty）の上で対話シェルを動かし、1行ずつ打鍵した記録 ---'
session <<'KEYIN'
 export PROMPT_COMMAND='PS1="\$ "'
bash
history -c
echo one
echo two
echo three
history
history -d 2
history
printf '%s\n' 'echo from-file-1' 'echo from-file-2' > /tmp/hist.txt
history -r /tmp/hist.txt
history 4
history -c -w /tmp/hist.txt; wc -l /tmp/hist.txt
exit
exit
KEYIN
echo '--- 対話の記録ここまで ---'
fi

if want 6; then
S "6. sed と整形（試験対策の追加）"
R 'cd ~/text'
R 'seq 1 50 > fifty.txt'
R 'pr -l 20 fifty.txt | grep -o "Page [0-9]*"'
R 'pr -l 20 +1:3 fifty.txt | grep -o "Page [0-9]*"'
R 'pr -l 20 --pages=2:3 fifty.txt | grep -o "Page [0-9]*"'
R 'pr -l 20 +4 fifty.txt | grep -o "Page [0-9]*"'
R 'pr -l 20 +1,3 fifty.txt | grep -c "Page"; echo "exit=${PIPESTATUS[0]}"'
R 'pr -l 20 -p 1:3 fifty.txt'
R 'pr -l 20 --pages 1-3 fifty.txt'
R 'ls -l --time-style="+%Y-%m-%d %H:%M" fruits.txt'
R 'pr fruits.txt | sed -n 3p'
fi

if want 8; then
S "8. パイプと xargs と tee（試験対策の追加）"
R 'cd /tmp'
R 'mkdir -p dir/d1 dir/d2 dir/d3; touch dir/d1/file1.txt dir/d2/file2.txt dir/d3/file3.txt'
R 'find dir -type f | sort | xargs -t rm -f'
R 'find dir | sort'
R 'echo a b c | xargs -t -n 1 echo'
R 'find dir -type f | xargs -c '"'"'rm -f $0'"'"''
R 'find dir -type f | xargs -P rm -f'
R 'cd ~/text'
echo
echo '--- ここから下は、端末（pty）の上で対話シェルを動かし、1行ずつ打鍵した記録 ---'
session <<'KEYIN'
 export PROMPT_COMMAND='PS1="\$ "'
echo a b | xargs -p -n 1 echo
y
n
exit
KEYIN
echo '--- 対話の記録ここまで ---'
fi

if want 9; then
S "9. 正規表現と grep（試験対策の追加）"
R 'cd ~/text'
R 'echo "12345 ddddd" | grep -oE "\d{5}"'
R 'echo "12345 ddddd" | grep -oP "\d{5}"'
R 'echo "12345 ddddd" | grep -oE "[0-9]{5}"'
fi

if want 10; then
S "10. vi とエディタの切り替え（試験対策の追加）"
R 'cd ~/text'
R 'cp memo.txt e1.txt; cp memo.txt e2.txt'
KEYS 'dd :e e2.txt⏎ :e! e2.txt⏎ dd :wq⏎' 'vim e1.txt' 'dd' ':e e2.txt\r' ':e! e2.txt\r' 'dd' ':wq\r'
R 'cat e1.txt'
R 'cat e2.txt'
fi
