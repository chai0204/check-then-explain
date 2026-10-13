#!/usr/bin/env bash
# 演習 06 の判定。観測型（menu.sh に入力を流し込んで実際に実行し、出力と終了ステータスを見る）。
set -uo pipefail
s="$HOME/work/06/menu.sh"
[ -d "$HOME/work/06" ] || { echo "前提不足: ~/work/06 がありません。先に lab start 06"; exit 2; }
echo "判定 : 観測型（入力 1 → 2 → x → q を流し込んで実行した。q を入れずに入力を終える場合も実行した）"
if [ ! -f "$s" ]; then echo "観測 : $s が無い"; exit 1; fi

me=$(id -un); host=$(hostname)
err="1・2・q のどれかを入力してください"
out=$(cd /tmp && printf '1\n2\nx\nq\n' | timeout 5 bash "$s" 2>&1); rc=$?
# 入力の終わりで止まるかだけを見る。止まらない書き方だと案内を延々と出し続けるので、出力は捨てる。
(cd /tmp && printf '1\n' | timeout 5 bash "$s" >/dev/null 2>&1); rc_eof=$?

n_me=$(grep -cxF -- "$me" <<<"$out")
n_host=$(grep -cxF -- "$host" <<<"$out")
n_err=$(grep -cF -- "$err" <<<"$out")
n_bye=$(grep -cF -- "終了します" <<<"$out")
echo "観測 : 1→2→x→q のとき  終了ステータス $rc"
echo "         「$me」の行 $n_me 個 / 「$host」の行 $n_host 個 / 「$err」$n_err 個 / 「終了します」$n_bye 個"
if [ "$rc_eof" = 124 ]; then
  echo "       1 だけ入れて入力を終えたとき  5 秒たっても終わらなかった（打ち切った）"
else
  echo "       1 だけ入れて入力を終えたとき  終了ステータス $rc_eof で終わった"
fi

ng=0
[ "$rc" = 0 ]      || { echo "       → q のあとの終了ステータスが 0 ではない"; ng=1; }
[ "$n_me" -ge 1 ]  || { echo "       → 1 を入れたのにユーザ名の行が無い"; ng=1; }
[ "$n_host" -ge 1 ] || { echo "       → 2 を入れたのにホスト名の行が無い"; ng=1; }
[ "$n_err" = 1 ]   || { echo "       → x を1回入れたのに、案内が $n_err 回出た"; ng=1; }
[ "$n_bye" = 1 ]   || { echo "       → 「終了します」が $n_bye 回出た"; ng=1; }
[ "$rc_eof" != 124 ] || { echo "       → 入力が終わってもループが止まらない"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       入力ごとに決まったコマンドだけが動き、q と入力の終わりの両方で止まった"
echo "       → while は条件のコマンド（read）の終了ステータスで回り、case は最初に当たった1つだけを実行する"
exit 0
