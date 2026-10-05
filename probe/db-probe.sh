#!/usr/bin/env bash
# SQLite 教材の演習候補を実機で確認する。失敗したら失敗したまま記録する。
cd "$(mktemp -d)" || exit 1
say() { printf '\n========== %s ==========\n' "$*"; }
run() { printf '$ %s\n' "$*"; eval "$@" 2>&1; printf '[exit %s]\n' "$?"; }

say "0. 環境"
run 'sqlite3 --version'

say "1. DB はファイル1個である（サーバが無い）"
run "sqlite3 notes.db 'CREATE TABLE notes(id INTEGER PRIMARY KEY, body TEXT); INSERT INTO notes(body) VALUES(\"hello\");'"
run 'ls -la notes.db'
run 'file notes.db'
run 'xxd -l 16 notes.db'
echo '--- 常駐プロセスを探す。角括弧の有無で結果が割れる ---'
run 'ps -ef | grep -c "[s]qlite"'
run 'ps -ef | grep -c "sqlite"'
echo '--- ↑ 1 のほうは grep 自身の行。何がヒットしたか ---'
run 'ps -ef | grep "sqlite"'
echo '注: ps -ef の全体はこの探査スクリプト自身が出るため、読者の画面とは一致しない。'
echo '    本文には載せない（PID・時刻・起動の仕方で変わる）。'

say "2. 型は宣言ではなく提案（type affinity）"
run "sqlite3 t2.db 'CREATE TABLE loose(n INTEGER);'"
run "sqlite3 t2.db 'INSERT INTO loose VALUES(42);'"
run "sqlite3 t2.db 'INSERT INTO loose VALUES(\"abc\");'"
run "sqlite3 t2.db 'SELECT n, typeof(n) FROM loose;'"
echo '--- INTEGER 列に \"123\" を入れると数値に変換される（\"abc\" は文字列のまま） ---'
run "sqlite3 t2.db 'INSERT INTO loose VALUES(\"123\"); SELECT n, typeof(n) FROM loose;'"
echo '--- STRICT テーブルなら拒否されるか ---'
run "sqlite3 t2.db 'CREATE TABLE tight(n INTEGER) STRICT;'"
run "sqlite3 t2.db 'INSERT INTO tight VALUES(\"abc\");'"
run "sqlite3 t2.db 'INSERT INTO tight VALUES(7); SELECT n, typeof(n) FROM tight;'"

say "3. トランザクションの有無で速度が変わる"
echo '--- 素で 2000 行 INSERT ---'
run "time sqlite3 t3a.db 'CREATE TABLE a(n INTEGER);' \$(for i in \$(seq 1 200); do printf '\"INSERT INTO a VALUES(%s);\" ' \$i; done)"
cat > naive.sh <<'EOS'
sqlite3 t3a.db 'CREATE TABLE a(n INTEGER);'
i=0; while [ $i -lt 2000 ]; do i=$((i+1)); echo "INSERT INTO a VALUES($i);"; done | sqlite3 t3a.db
EOS
cat > txn.sh <<'EOS'
sqlite3 t3b.db 'CREATE TABLE b(n INTEGER);'
{ echo "BEGIN;"; i=0; while [ $i -lt 2000 ]; do i=$((i+1)); echo "INSERT INTO b VALUES($i);"; done; echo "COMMIT;"; } | sqlite3 t3b.db
EOS
rm -f t3a.db t3b.db
echo '--- 1行1トランザクション（既定） ---'
run 'time bash naive.sh'
run "sqlite3 t3a.db 'SELECT count(*) FROM a;'"
echo '--- BEGIN...COMMIT で囲む ---'
run 'time bash txn.sh'
run "sqlite3 t3b.db 'SELECT count(*) FROM b;'"

say "4. 同時書き込みでロックする"
run "sqlite3 lock.db 'CREATE TABLE t(n INTEGER);'"
run "sqlite3 lock.db 'PRAGMA journal_mode;'"
mkfifo fifo
sqlite3 lock.db < fifo > holder.out 2>&1 &
HOLDER=$!
exec 3>fifo
printf 'BEGIN IMMEDIATE;\nINSERT INTO t VALUES(1);\n' >&3
sleep 1
echo '--- 別プロセスから書き込む（既定 journal_mode=delete, busy_timeout=0） ---'
run "sqlite3 lock.db 'INSERT INTO t VALUES(2);'"
echo '--- 読み取りはできるか ---'
run "sqlite3 lock.db 'SELECT count(*) FROM t;'"
printf 'COMMIT;\n.quit\n' >&3
exec 3>&-
wait $HOLDER 2>/dev/null
run "sqlite3 lock.db 'SELECT count(*) FROM t;'"

echo '--- WAL に変えて同じことをする ---'
run "sqlite3 wal.db 'PRAGMA journal_mode=WAL; CREATE TABLE t(n INTEGER);'"
run 'ls wal.db*'
mkfifo fifo2
sqlite3 wal.db < fifo2 > holder2.out 2>&1 &
H2=$!
exec 4>fifo2
printf 'BEGIN IMMEDIATE;\nINSERT INTO t VALUES(1);\n' >&4
sleep 1
echo '--- WAL でも書き込みは1つだけか ---'
run "sqlite3 wal.db 'INSERT INTO t VALUES(2);'"
echo '--- WAL なら読み取りは待たされないか ---'
run "sqlite3 wal.db 'SELECT count(*) FROM t;'"
printf 'COMMIT;\n.quit\n' >&4
exec 4>&-
wait $H2 2>/dev/null
run 'ls wal.db*'

say "5. ディレクトリに書けないと DB にも書けない"
mkdir subdir
run "sqlite3 subdir/d.db 'CREATE TABLE t(n INTEGER); INSERT INTO t VALUES(1);'"
run 'ls -la subdir/'
echo '--- DB ファイル自体は書き込み可のまま、ディレクトリだけ読み取り専用にする ---'
run 'chmod 555 subdir'
run 'ls -ld subdir; ls -l subdir/d.db'
run "sqlite3 subdir/d.db 'INSERT INTO t VALUES(2);'"
echo '--- 読み取りはできるか ---'
run "sqlite3 subdir/d.db 'SELECT count(*) FROM t;'"
echo '--- WAL でも同じか ---'
run "sqlite3 subdir/d.db 'PRAGMA journal_mode=WAL;'"
echo '--- ディレクトリを戻すと書けるか ---'
run 'chmod 755 subdir'
run "sqlite3 subdir/d.db 'INSERT INTO t VALUES(2); SELECT count(*) FROM t;'"

say "6. 参考: 壊れたファイルを開くとどうなるか"
run 'printf "not a database at all, just text" > broken.db'
run "sqlite3 broken.db 'SELECT 1;'"
run "sqlite3 broken.db 'PRAGMA integrity_check;'"

say "完了"
