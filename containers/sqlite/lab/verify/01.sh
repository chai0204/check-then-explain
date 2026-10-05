#!/usr/bin/env bash
# 演習 01 の判定。観測型（外から見て分かる結果だけで判定する）。
# 書き方の契約: exit 0=達成 / 1=未達 / 2=前提不足（環境側の問題）
# 出力は「観測した事実」だけにする。直し方は書かない。
set -uo pipefail
DB="01/notes.db"

command -v sqlite3 >/dev/null || { echo "前提不足: sqlite3 が見つかりません"; exit 2; }

if [ ! -f "$DB" ]; then
  echo "観測 : ~/work/$DB が存在しない"
  if [ -d 01 ]; then
    echo "       ~/work/01 の中身: $(ls -A 01 2>/dev/null | tr '\n' ' ' || echo '(空)')"
  else
    echo "       ~/work/01 そのものが無い（lab start 01 で作られます）"
  fi
  # 別の書ける場所で作ってしまった場合に、そこを教える。
  # （/home のような書けない場所で試した場合はファイル自体が無いので何も出ない）
  found=$(find "$HOME" -maxdepth 4 -name 'notes.db' 2>/dev/null | grep -v "/work/01/" | head -3)
  if [ -n "$found" ]; then
    echo "       ただし別の場所に notes.db があります:"
    printf '         %s\n' $found
    echo "       判定は ~/work/01 の中だけを見ます"
  fi
  exit 1
fi

head -c 15 "$DB" 2>/dev/null | grep -q 'SQLite format 3' || {
  echo "観測 : $DB の先頭16バイトが SQLite のヘッダになっていない"
  echo "       実際の先頭: $(head -c 16 "$DB" | od -c -A n | head -1)"
  exit 1
}

schema=$(sqlite3 "$DB" "SELECT sql FROM sqlite_master WHERE type='table' AND name='notes';" 2>&1) || {
  echo "観測 : $DB を開けたが sqlite_master を読めない"
  echo "       sqlite3 の返答: $schema"
  exit 1
}
[ -n "$schema" ] || {
  echo "観測 : $DB に notes という名前のテーブルが無い"
  echo "       存在するテーブル: $(sqlite3 "$DB" "SELECT group_concat(name,', ') FROM sqlite_master WHERE type='table';" 2>/dev/null || echo '(なし)')"
  exit 1
}

echo "$schema" | grep -qi 'id[^,]*INTEGER[^,]*PRIMARY[[:space:]]*KEY' || {
  echo "観測 : notes テーブルはあるが、id INTEGER PRIMARY KEY が見つからない"
  echo "       実際の定義: $schema"
  exit 1
}
echo "$schema" | grep -qi 'body[^,)]*TEXT' || {
  echo "観測 : notes テーブルはあるが、body TEXT が見つからない"
  echo "       実際の定義: $schema"
  exit 1
}

n=$(sqlite3 "$DB" "SELECT count(*) FROM notes;" 2>&1) || {
  echo "観測 : notes テーブルを SELECT できない"; echo "       sqlite3 の返答: $n"; exit 1
}
case "$n" in ''|*[!0-9]*) echo "観測 : 行数を数えられない（返答: $n）"; exit 1 ;; esac
[ "$n" -ge 1 ] || { echo "観測 : notes テーブルの行数が 0"; exit 1; }

bytes=$(stat -c %s "$DB")
echo "判定 : 観測型（ファイルの先頭バイトとテーブルの中身を外から読んだ）"
echo "観測 : $DB は ${bytes} バイト、先頭に SQLite format 3 があり、notes に ${n} 行ある"
echo "       スキーマ: $schema"
exit 0
