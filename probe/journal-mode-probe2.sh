#!/usr/bin/env bash
# journal-mode-probe.sh の実験7〜9を採り直す。
# 前回は sed の & を \& とエスケープして SQL に壊れた文が流れた。awk に変えた。
cd "$(mktemp -d)" || exit 1
say() { printf '\n========== %s ==========\n' "$*"; }
run() { printf '$ %s\n' "$*"; eval "$@" 2>&1; printf '[exit %s]\n' "$?"; }

gen() {  # gen <件数> → INSERT 文を標準出力に出す
  seq 1 "$1" | awk '{printf "INSERT INTO t VALUES(%d);\n", $1}'
}

run "sqlite3 w.db 'CREATE TABLE t(n INTEGER);'"
run "sqlite3 w.db 'PRAGMA journal_mode=WAL;'"

say "7. チェックポイント: -wal はどこまで育ち、いつ本体に移るか"
run 'ls -l w.db*'
echo '--- 1000行を1トランザクションで入れる ---'
{ echo 'BEGIN;'; gen 1000; echo 'COMMIT;'; } | sqlite3 w.db
run 'ls -l w.db*'
run "sqlite3 w.db 'SELECT count(*) FROM t;'"
echo '--- もう3000行入れる（自動チェックポイントの閾値 1000 ページを超えるか） ---'
{ echo 'BEGIN;'; gen 3000; echo 'COMMIT;'; } | sqlite3 w.db
run 'ls -l w.db*'
echo '--- 手で全部移す（TRUNCATE は -wal を 0 に切り詰める） ---'
run "sqlite3 w.db 'PRAGMA wal_checkpoint(TRUNCATE);'"
run 'ls -l w.db*'
echo '--- ↑ 3カラムは busy / log / checkpointed（移したページ数） ---'

say "8. WAL の DB を読み取り専用ディレクトリに置くと読めるか"
mkdir ro
run 'cp w.db ro/'
run 'chmod 555 ro'
echo '--- 読み取りだけでも -shm を作ろうとするか ---'
run "sqlite3 ro/w.db 'SELECT count(*) FROM t;'"
run "sqlite3 'file:ro/w.db?immutable=1' 'SELECT count(*) FROM t;'"
run 'chmod 755 ro'

say "9. 本体だけコピーすると何が欠けるか（3ファイルの面倒さ）"
echo '--- -wal に未反映の変更を残した状態をつくる ---'
{ echo 'BEGIN;'; gen 50; echo 'COMMIT;'; } | sqlite3 w.db
run 'ls -l w.db*'
run "sqlite3 w.db 'SELECT count(*) FROM t;'"
echo '--- 本体だけコピーして、そちらを読む ---'
run 'cp w.db only-main.db'
run "sqlite3 only-main.db 'SELECT count(*) FROM t;'"
echo '--- 3ファイルまとめてコピーした場合 ---'
run 'cp w.db full.db; cp w.db-wal full.db-wal 2>/dev/null; cp w.db-shm full.db-shm 2>/dev/null; ls -l full.db*'
run "sqlite3 full.db 'SELECT count(*) FROM t;'"
echo '--- 公式が勧める方法（.backup はロックを見て整合を取る） ---'
run "sqlite3 w.db '.backup safe.db'"
run "sqlite3 safe.db 'SELECT count(*) FROM t;'"

say "10. 旧モードへ戻せるか / 戻すと何が消えるか"
run "sqlite3 w.db 'PRAGMA journal_mode=DELETE;'"
run 'ls -l w.db*'
run "sqlite3 w.db 'PRAGMA journal_mode;'"

say "完了"
