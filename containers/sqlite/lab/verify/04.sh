#!/usr/bin/env bash
# 演習 04 の判定。痕跡型（journal_mode の変更）＋観測記録。
set -uo pipefail
DB="04/lock.db"
OBS="04/observed.txt"
command -v sqlite3 >/dev/null || { echo "前提不足: sqlite3 が見つかりません"; exit 2; }
[ -f "$DB" ] || { echo "観測 : ~/work/$DB が存在しない"; exit 1; }

sqlite3 "$DB" "SELECT count(*) FROM t;" >/dev/null 2>&1 || {
  echo "観測 : $DB に t テーブルが無い、または読めない"
  echo "       存在するテーブル: $(sqlite3 "$DB" "SELECT coalesce(group_concat(name,', '),'(なし)') FROM sqlite_master WHERE type='table';" 2>/dev/null)"
  exit 1
}

mode=$(sqlite3 "$DB" "PRAGMA journal_mode;" 2>/dev/null)
[ "$mode" = "wal" ] || {
  echo "観測 : journal_mode が $mode（wal を期待）"
  echo "       この値はファイルに保存されるので、一度 WAL にすれば次回も wal のままです"
  exit 1
}

[ -s "$OBS" ] || { echo "観測 : $OBS が空、または存在しない"; exit 1; }
grep -qi 'database is locked' "$OBS" || {
  echo "観測 : $OBS に 'database is locked' が見つからない"
  echo "       記録されている内容: $(head -c 150 "$OBS" | tr '\n' ' ')"
  # 「エラーが無い」だけだと原因が分からないので、
  # 書き込みが通ってしまった可能性を観測事実として示す。
  if ! grep -qiE 'error' "$OBS"; then
    echo "       エラーが1行もありません。SQLite は成功した INSERT には何も出力しないので、"
    echo "       書き込みが通った場合も observed.txt は空に近くなります"
  fi
  rows=$(sqlite3 "$DB" "SELECT count(*) FROM t;" 2>/dev/null)
  echo "       いまの t の行数: ${rows}（hold.sh が入れる 999 を含みます）"
  exit 1
}

# WAL 化した後も locked が起きたことを記録できているか（2回以上の出現で判定する）
hits=$(grep -ci 'database is locked' "$OBS")
rows=$(sqlite3 "$DB" "SELECT count(*) FROM t;" 2>/dev/null)

echo "判定 : 痕跡型（DB に保存された journal_mode）＋あなたの観測記録"
echo "観測 : journal_mode = wal に変更されている / t の行数 = ${rows}"
echo "       observed.txt に 'database is locked' が ${hits} 箇所ある"
if [ "$hits" -ge 2 ]; then
  echo "       2箇所以上あるので、WAL にしても書き込みが排他であることを自分で確かめられています"
else
  echo "       ※ 1箇所だけです。WAL にした後にも同じ実験をすると、もう1つ出ます"
fi
exit 0
