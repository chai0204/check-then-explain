#!/usr/bin/env bash
# 模範解答のとおりに5演習すべてを解き、lab check が全部通るかを確認する。
# solutions/*.md に書いたコマンドと、ここで打つコマンドは一致させる。
cd "$HOME" || exit 1
fail=0
step() { printf '\n########## %s ##########\n' "$*"; }

step "01 データベースを1個のファイルとして見る"
lab start 01 >/dev/null
( cd ~/work/01 && sqlite3 notes.db 'CREATE TABLE notes(id INTEGER PRIMARY KEY, body TEXT); INSERT INTO notes(body) VALUES("最初のメモ");' )
lab check 01 || fail=1

step "02 型に嘘をつかせる"
lab start 02 >/dev/null
( cd ~/work/02 \
  && sqlite3 t.db 'CREATE TABLE loose(n INTEGER);' \
  && sqlite3 t.db 'INSERT INTO loose VALUES(42);' \
  && sqlite3 t.db 'INSERT INTO loose VALUES("abc");' \
  && sqlite3 t.db 'INSERT INTO loose VALUES("123");' \
  && sqlite3 t.db 'SELECT n, typeof(n) FROM loose;' \
  && sqlite3 t.db 'CREATE TABLE tight(n INTEGER) STRICT;' \
  && { sqlite3 t.db 'INSERT INTO tight VALUES("abc");' 2> observed.txt; true; } \
  && cat observed.txt )
lab check 02 || fail=1

step "03 同じ2000行を、2通りの速さで入れる"
lab start 03 >/dev/null
( cd ~/work/03 \
  && sqlite3 naive.db 'CREATE TABLE a(n INTEGER);' \
  && sqlite3 txn.db   'CREATE TABLE b(n INTEGER);' \
  && s1=$( { /usr/bin/time -f %e bash -c "seq 1 2000 | sed 's/.*/INSERT INTO a VALUES(&);/' | sqlite3 naive.db"; } 2>&1 ) \
  && s2=$( { /usr/bin/time -f %e bash -c "{ echo 'BEGIN;'; seq 1 2000 | sed 's/.*/INSERT INTO b VALUES(&);/'; echo 'COMMIT;'; } | sqlite3 txn.db"; } 2>&1 ) \
  && printf 'naive=%s\ntxn=%s\n' "$s1" "$s2" > times.txt \
  && cat times.txt )
lab check 03 || fail=1

step "04 2人で同時に書こうとする"
lab start 04 >/dev/null
(
  cd ~/work/04 || exit 1
  sqlite3 lock.db 'CREATE TABLE t(n INTEGER);'
  echo "既定の journal_mode: $(sqlite3 lock.db 'PRAGMA journal_mode;')"
  ./hold.sh lock.db 6 &
  sleep 1
  sqlite3 lock.db 'INSERT INTO t VALUES(1);' >> observed.txt 2>&1
  sqlite3 lock.db 'SELECT count(*) FROM t;'  >> observed.txt 2>&1
  wait
  echo "WAL へ変更: $(sqlite3 lock.db 'PRAGMA journal_mode=WAL;')"
  ./hold.sh lock.db 6 &
  sleep 1
  sqlite3 lock.db 'INSERT INTO t VALUES(2);' >> observed.txt 2>&1
  sqlite3 lock.db 'SELECT count(*) FROM t;'  >> observed.txt 2>&1
  wait
  echo "--- observed.txt ---"; cat observed.txt
)
lab check 04 || fail=1

step "05 書ける権限があるのに、書けない"
lab start 05 >/dev/null
(
  cd ~/work/05 || exit 1
  mkdir -p sub
  sqlite3 sub/d.db 'CREATE TABLE t(n INTEGER); INSERT INTO t VALUES(1);'
  ls -ld sub; ls -l sub/d.db
  chmod 555 sub
  ls -ld sub; ls -l sub/d.db
  sqlite3 sub/d.db 'INSERT INTO t VALUES(2);'      >> observed.txt 2>&1
  sqlite3 sub/d.db 'SELECT count(*) FROM t;'       >> observed.txt 2>&1
  sqlite3 sub/d.db 'PRAGMA journal_mode=WAL;'      >> observed.txt 2>&1
  echo "--- observed.txt ---"; cat observed.txt
  chmod 755 sub
  sqlite3 sub/d.db 'INSERT INTO t VALUES(2); SELECT count(*) FROM t;'
)
lab check 05 || fail=1

step "最終状態"
lab ls
printf '\n総合: %s\n' "$([ $fail -eq 0 ] && echo '全演習の verify が通った' || echo '通らない演習がある')"
exit $fail
