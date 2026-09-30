#!/usr/bin/env bash
# 演習 02 の判定。観測型。
set -uo pipefail
DB="02/t.db"
OBS="02/observed.txt"
command -v sqlite3 >/dev/null || { echo "前提不足: sqlite3 が見つかりません"; exit 2; }
[ -f "$DB" ] || { echo "観測 : ~/work/$DB が存在しない"; exit 1; }

have() { sqlite3 "$DB" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='$1';" 2>/dev/null; }
[ "$(have loose)" = "1" ] || {
  echo "観測 : loose テーブルが無い"
  echo "       存在するテーブル: $(sqlite3 "$DB" "SELECT coalesce(group_concat(name,', '),'(なし)') FROM sqlite_master WHERE type='table';" 2>/dev/null)"
  exit 1
}
[ "$(have tight)" = "1" ] || { echo "観測 : tight テーブルが無い"; exit 1; }

# loose に text として格納された行があるか（= INTEGER 列に文字列が入った証拠）
txt=$(sqlite3 "$DB" "SELECT count(*) FROM loose WHERE typeof(n)='text';" 2>&1)
[ "$txt" -ge 1 ] 2>/dev/null || {
  echo "観測 : loose に typeof が text の行が無い（現在の中身）"
  sqlite3 "$DB" "SELECT '        '||n||' -> '||typeof(n) FROM loose;" 2>/dev/null
  exit 1
}
# '123' が integer に変換された行があるか（affinity の非対称の証拠）
i123=$(sqlite3 "$DB" "SELECT count(*) FROM loose WHERE n=123 AND typeof(n)='integer';" 2>/dev/null)

# tight が STRICT で定義されているか
sql=$(sqlite3 "$DB" "SELECT sql FROM sqlite_master WHERE name='tight';" 2>/dev/null)
echo "$sql" | grep -qi 'strict' || {
  echo "観測 : tight テーブルに STRICT が付いていない"
  echo "       実際の定義: $sql"
  exit 1
}
# tight に text が入っていないこと（= STRICT が効いている）
ttxt=$(sqlite3 "$DB" "SELECT count(*) FROM tight WHERE typeof(n)='text';" 2>/dev/null)
[ "$ttxt" = "0" ] || { echo "観測 : tight に text 型の行が $ttxt 件ある（STRICT が効いていない）"; exit 1; }

[ -s "$OBS" ] || { echo "観測 : $OBS が空、または存在しない（STRICT が返したメッセージを貼ってください）"; exit 1; }
grep -qiE 'cannot store TEXT value|19' "$OBS" || {
  echo "観測 : $OBS に STRICT の拒否メッセージが見つからない"
  echo "       貼られている内容: $(head -c 120 "$OBS")"
  exit 1
}

echo "判定 : 観測型（格納された値の typeof と、テーブル定義の SQL を外から読んだ）"
echo "観測 : loose には text 型の行が ${txt} 件ある（INTEGER 宣言が拒否していない）"
if [ "${i123:-0}" -ge 1 ]; then
  echo "       うち '123' は integer に変換されて入っている（affinity が働いた側）"
fi
echo "       tight は STRICT で定義されており、text 型の行は 0 件"
exit 0
