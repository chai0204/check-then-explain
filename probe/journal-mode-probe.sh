#!/usr/bin/env bash
# journal_mode（delete / WAL）の挙動を実測する。第4章に解説を足すための素材。
# 失敗したら失敗したまま記録する。
cd "$(mktemp -d)" || exit 1
say() { printf '\n========== %s ==========\n' "$*"; }
run() { printf '$ %s\n' "$*"; eval "$@" 2>&1; printf '[exit %s]\n' "$?"; }

# 書き込みを保持する道具（ロックを取ってから制御を返す）
cat > holdw.sh <<'EOS'
DB="$1"; SEC="${2:-10}"; R="${3:-p}"
if [ "$R" = c ]; then
  F=$(mktemp -u); mkfifo "$F"; sqlite3 "$DB" < "$F" >/dev/null 2>&1 & P=$!
  exec 3>"$F"; printf 'BEGIN IMMEDIATE;\nINSERT INTO t VALUES(999);\n' >&3
  sleep "$SEC"; printf 'COMMIT;\n.quit\n' >&3; exec 3>&-; wait $P 2>/dev/null; rm -f "$F"; exit 0
fi
bash "$0" "$DB" "$SEC" c &
for _ in $(seq 1 60); do
  if sqlite3 "$DB" 'BEGIN IMMEDIATE; ROLLBACK;' >/dev/null 2>&1; then sleep 0.05; else break; fi
done
EOS
# 読み取りを保持する道具（トランザクション内の SELECT を握ったままにする）
cat > holdr.sh <<'EOS'
DB="$1"; SEC="${2:-10}"; R="${3:-p}"
if [ "$R" = c ]; then
  F=$(mktemp -u); mkfifo "$F"; sqlite3 "$DB" < "$F" >/dev/null 2>&1 & P=$!
  exec 3>"$F"; printf 'BEGIN;\nSELECT count(*) FROM t;\n' >&3
  sleep "$SEC"; printf 'COMMIT;\n.quit\n' >&3; exec 3>&-; wait $P 2>/dev/null; rm -f "$F"; exit 0
fi
bash "$0" "$DB" "$SEC" c &
sleep 1
EOS
chmod +x holdw.sh holdr.sh

say "0. 既定値"
run "sqlite3 d.db 'CREATE TABLE t(n INTEGER); INSERT INTO t VALUES(1);'"
run "sqlite3 d.db 'PRAGMA journal_mode;'"
run "sqlite3 d.db 'PRAGMA wal_autocheckpoint;'"
run "sqlite3 d.db 'PRAGMA synchronous;'"

say "1. delete モード: 書き込み中にだけ -journal が現れる"
run 'ls d.db*'
./holdw.sh d.db 4
run 'ls -l d.db*'
run 'xxd -l 32 d.db-journal 2>/dev/null || echo "(-journal が無い)"'
sleep 5
echo '--- 解放後 ---'
run 'ls d.db*'

say "2. delete モード: 読み取りを保持すると書き込みは通るか"
./holdr.sh d.db 4
run "sqlite3 d.db 'INSERT INTO t VALUES(2);'"
sleep 5
run "sqlite3 d.db 'INSERT INTO t VALUES(2); SELECT count(*) FROM t;'"

say "3. WAL に切り替える"
run "sqlite3 w.db 'CREATE TABLE t(n INTEGER); INSERT INTO t VALUES(1);'"
run "sqlite3 w.db 'PRAGMA journal_mode=WAL;'"
run 'ls -l w.db*'
echo '--- 別プロセスで開いても wal か（ファイルに永続化されているか） ---'
run "sqlite3 w.db 'PRAGMA journal_mode;'"

say "4. WAL モード: 書き込み中に現れるファイル"
./holdw.sh w.db 4
run 'ls -l w.db*'
run 'xxd -l 32 w.db-wal 2>/dev/null || echo "(-wal が無い)"'
sleep 5
echo '--- 解放後（-wal は残るか） ---'
run 'ls -l w.db*'

say "5. WAL モード: 読み取りを保持しても書き込めるか（WAL の本当の利点）"
./holdr.sh w.db 4
run "sqlite3 w.db 'INSERT INTO t VALUES(2);'"
run "sqlite3 w.db 'SELECT count(*) FROM t;'"
sleep 5

say "6. WAL モード: 書き込みを保持したら、別の書き込みと読み取りはどうなるか"
./holdw.sh w.db 4
run "sqlite3 w.db 'INSERT INTO t VALUES(3);'"
run "sqlite3 w.db 'SELECT count(*) FROM t;'"
sleep 5

say "7. チェックポイント"
run 'ls -l w.db*'
run "sqlite3 w.db 'PRAGMA wal_checkpoint(TRUNCATE);'"
run 'ls -l w.db*'
echo '--- 1000行入れて -wal がどれだけ育つか ---'
run "bash -c \"{ echo 'BEGIN;'; seq 1 1000 | sed 's/.*/INSERT INTO t VALUES(\&);/'; echo 'COMMIT;'; } | sqlite3 w.db\""
run 'ls -l w.db*'
run "sqlite3 w.db 'PRAGMA wal_checkpoint(TRUNCATE);'"
run 'ls -l w.db*'

say "8. WAL の DB を読み取り専用ディレクトリに置くと開けるか"
mkdir ro
run "sqlite3 w.db 'PRAGMA wal_checkpoint(TRUNCATE);'"
run 'cp w.db ro/'
run 'chmod 555 ro'
run "sqlite3 ro/w.db 'SELECT count(*) FROM t;'"
run 'chmod 755 ro'

say "9. 本体だけコピーすると何が欠けるか（3ファイルの面倒さ）"
run "bash -c \"{ echo 'BEGIN;'; seq 1 50 | sed 's/.*/INSERT INTO t VALUES(\&);/'; echo 'COMMIT;'; } | sqlite3 w.db\""
run 'ls -l w.db*'
run 'cp w.db only-main.db'
run "sqlite3 w.db 'SELECT count(*) FROM t;'"
run "sqlite3 only-main.db 'SELECT count(*) FROM t;'"
echo '--- ↑ 本体だけコピーすると -wal にあった分が欠ける（はず） ---'

say "完了"
