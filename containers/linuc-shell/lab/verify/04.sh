#!/usr/bin/env bash
# 演習 04 の判定。観測型（別の空ディレクトリで mkbak.sh を実際に2回実行し、出力と作られたファイルを見る）。
set -uo pipefail
s="$HOME/work/04/mkbak.sh"
[ -d "$HOME/work/04" ] || { echo "前提不足: ~/work/04 がありません。先に lab start 04"; exit 2; }
echo "判定 : 観測型（空のディレクトリに a.txt と「my notes.txt」を用意し、mkbak.sh を引数なしで1回・2つ渡して1回実行した）"
if [ ! -f "$s" ]; then echo "観測 : $s が無い"; exit 1; fi

t=$(mktemp -d /tmp/labchk04.XXXXXX)   # mkbak.sh を走らせる場所
o=$(mktemp -d /tmp/labchk04o.XXXXXX)  # 出力をためる場所
cd "$t" || exit 2
printf 'A\n' > a.txt
printf 'B\n' > "my notes.txt"
timeout 10 bash "$s"                    > "$o/out0" 2> "$o/err0"; rc0=$?
timeout 10 bash "$s" a.txt "my notes.txt" > "$o/out2" 2> "$o/err2"; rc2=$?
made=$(ls -1A | grep -vxF -e a.txt -e "my notes.txt" | sed 's/.*/[&]/' | tr '\n' ' ')
out0=$(cat "$o/out0"); err0=$(head -1 "$o/err0")
out2=$(cat "$o/out2"); err2=$(head -1 "$o/err2")
ok_a=0; cmp -s a.txt a.txt.bak 2>/dev/null && ok_a=1
ok_m=0; cmp -s "my notes.txt" "my notes.txt.bak" 2>/dev/null && ok_m=1
cd / && find "$t" "$o" -mindepth 1 -delete && rmdir "$t" "$o"

echo "観測 : 引数なし   終了ステータス $rc0  標準出力「$out0」  標準エラー「$err0」"
echo "       2つ渡した  終了ステータス $rc2  標準出力「$out2」  標準エラー「$err2」"
echo "       作られたファイル: ${made:-（なし）}"

ng=0
[ "$rc0" = 1 ]               || { echo "       → 引数なしの終了ステータスが 1 ではない"; ng=1; }
grep -q '使い方' <<<"$err0"   || { echo "       → 引数なしのとき、標準エラーに「使い方」が出ていない"; ng=1; }
[ -z "$out0" ]               || { echo "       → 引数なしのとき、標準出力に何か出ている"; ng=1; }
[ "$rc2" = 0 ]               || { echo "       → 2つ渡したときの終了ステータスが 0 ではない"; ng=1; }
[ "$ok_a" = 1 ]              || { echo "       → [a.txt.bak] が a.txt と同じ中身でできていない"; ng=1; }
[ "$ok_m" = 1 ]              || { echo "       → [my notes.txt.bak] が「my notes.txt」と同じ中身でできていない"; ng=1; }
[ "$made" = "[a.txt.bak] [my notes.txt.bak] " ] || { echo "       → .bak の2つ以外のファイルができている（または足りない）"; ng=1; }
grep -q '2 個コピーした' <<<"$out2" || { echo "       → 「2 個コピーした」が出ていない"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       引数なしでは使い方を標準エラーに出して 1、空白入りの名前も1つのファイルとしてコピーした"
echo "       → 呼んだ側のシェルが切った引数を、\"\$@\" はその区切りのまま受け渡す"
exit 0
