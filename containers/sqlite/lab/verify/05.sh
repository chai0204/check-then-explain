#!/usr/bin/env bash
# 演習 05 の判定。観測型（最終状態）＋観測記録（失敗を自分で見たこと）。
set -uo pipefail
D="05/sub"
DB="$D/d.db"
OBS="05/observed.txt"
command -v sqlite3 >/dev/null || { echo "前提不足: sqlite3 が見つかりません"; exit 2; }

[ -d "$D" ] || { echo "観測 : ~/work/$D が存在しない"; exit 1; }
[ -f "$DB" ] || { echo "観測 : ~/work/$DB が存在しない"; exit 1; }

[ -s "$OBS" ] || { echo "観測 : $OBS が空、または存在しない"; exit 1; }
grep -qi 'readonly database' "$OBS" || {
  echo "観測 : $OBS に 'attempt to write a readonly database' が見つからない"
  echo "       貼られている内容の先頭: $(head -c 150 "$OBS" | tr '\n' ' ')"
  echo "       （chmod 555 sub をした状態で INSERT を試す必要があります）"
  exit 1
}

n=$(sqlite3 "$DB" "SELECT count(*) FROM t;" 2>&1) || { echo "観測 : t テーブルを読めない（$n）"; exit 1; }
case "$n" in ''|*[!0-9]*) echo "観測 : 行数を数えられない（$n）"; exit 1 ;; esac
[ "$n" -ge 2 ] || {
  perm=$(stat -c %A "$D")
  echo "観測 : t の行数が $n（2以上を期待）"
  echo "       sub の現在の権限: $perm"
  case "$perm" in *w*) echo "       ディレクトリには書ける状態です。INSERT がまだ済んでいません" ;;
                  *)   echo "       ディレクトリに書き込み権限がありません。ここが原因です" ;; esac
  exit 1
}

dperm=$(stat -c %A "$D"); fperm=$(stat -c %A "$DB")
echo "判定 : 観測型（最終状態の行数と権限）＋あなたの観測記録"
echo "観測 : t の行数 = ${n}、sub = ${dperm}、d.db = ${fperm}"
echo "       observed.txt に 'readonly database' の記録があり、失敗を自分の目で見ています"
echo "       （著者の環境では d.db が -rw-r--r-- のまま sub を dr-xr-xr-x にしただけで"
echo "        attempt to write a readonly database (8) になりました）"
exit 0
