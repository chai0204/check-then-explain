#!/usr/bin/env bash
# 演習 02 の判定。観測型（today を名前だけで実際に2回実行する）。
#   1回目: この判定はあなたのシェルの子として動く。受け継いだ PATH のコピーで探す
#   2回目: 環境を空にしてログインシェルを新しく起動し、その PATH で探す
set -uo pipefail
want=$(date '+%Y年%-m月%-d日')
bin="$HOME/bin/today"

# 1) あなたのシェルから受け継いだ PATH
here=$(cd / && command -v today 2>/dev/null)
if [ -n "$here" ]; then here_out=$(cd / && today 2>&1); here_rc=$?; else here_out=""; here_rc=127; fi

# 2) 新しいログインシェル（docker の既定の PATH から始めて、~/.profile に PATH を作らせる）
#    起動ファイルが何か表示しても混ざらないよう、見たい値には目印を付けて取り出す。
new=$(cd / && env -i HOME="$HOME" USER="$(id -un)" LOGNAME="$(id -un)" TERM=dumb \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        bash -l -c 'echo "__WHERE__=$(command -v today)"; echo "__PATH__=$PATH"
                    echo "__WANT__=$(date "+%Y年%-m月%-d日")"
                    out=$(today 2>&1); echo "__RC__=$?"; echo "__OUT__=$out"' 2>/dev/null)
pick() { sed -n "s/^__$1__=//p" <<<"$new" | tail -1; }
new_where=$(pick WHERE); new_path=$(pick PATH); new_rc=$(pick RC); new_out=$(pick OUT)
# 今日の日付は、そのシェルの中で作って比べる。env -i で TZ も消えるので、日本時間の 0〜9 時は
# このシェルの日付（Asia/Tokyo）と1日ずれる（2026-10-21 の 0 時台に、正しく解いても ✗ になっていた）
new_want=$(pick WANT); [ -n "$new_want" ] || new_want=$want
[ -n "$new_where" ] || { new_rc=127; new_out=""; }

echo "判定 : 観測型（today を名前だけで2回実行した。あなたのシェルから受け継いだ PATH と、新しいログインシェルの PATH）"
echo "観測 : 受け継いだ PATH = $PATH"
echo "         today の在りか = ${here:-（見つからない）}  終了ステータス $here_rc  出力「${here_out}」"
echo "       新しいログインシェルの PATH = ${new_path:-（読めない）}"
echo "         today の在りか = ${new_where:-（見つからない）}  終了ステータス ${new_rc:-?}  出力「${new_out}」"
if [ -e "$bin" ]; then echo "       $bin の権限 = $(stat -c %A "$bin")"; else echo "       $bin は無い"; fi

ng=0
[ "$here" = "$bin" ]      || { echo "       → いまのシェルの PATH では $bin が見つからない"; ng=1; }
[ "$new_where" = "$bin" ] || { echo "       → 新しいログインシェルでは $bin が見つからない"; ng=1; }
{ [ "$here_rc" = 0 ] && [ "$here_out" = "$want" ]; } || { echo "       → いまのシェルでの出力が「$want」ではない"; ng=1; }
{ [ "$new_rc" = 0 ] && [ "$new_out" = "$new_want" ]; } || { echo "       → 新しいログインシェルでの出力が「$new_want」ではない"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       どちらの PATH でも $bin が見つかり、今日の日付が出た"
echo "       → 子のプロセスが見ている PATH は、起動したときに親から写したコピー"
exit 0
