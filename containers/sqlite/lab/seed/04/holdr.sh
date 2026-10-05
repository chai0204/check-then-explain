#!/usr/bin/env bash
# hold.sh の読み取り版。トランザクションの中で SELECT を打ち、そのまま保持する。
# 「読んでいる人が居る」状態を作るための道具で、演習の主役ではない。
#
#   使い方:  ./holdr.sh <DBファイル> [保持する秒数]
#   例:      ./holdr.sh lock.db 15
#
# hold.sh と同じく & は要らない。ただし読み取りロックは外から
# 「取れたか」を確かめにくいので、こちらは固定で少し待ってから制御を返す。
set -uo pipefail
DB="${1:?使い方: ./holdr.sh <DBファイル> [秒数]}"
SEC="${2:-15}"
ROLE="${3:-parent}"

if [ "$ROLE" = child ]; then
  FIFO=$(mktemp -u); mkfifo "$FIFO"
  sqlite3 "$DB" < "$FIFO" > /dev/null 2>&1 &
  SQL_PID=$!
  exec 3>"$FIFO"
  # BEGIN のあと SELECT を1回打つと、この接続は読み取りの位置を握ったままになる
  printf 'BEGIN;\nSELECT count(*) FROM t;\n' >&3
  sleep "$SEC"
  printf 'COMMIT;\n.quit\n' >&3
  exec 3>&-
  wait "$SQL_PID" 2>/dev/null
  rm -f "$FIFO"
  echo "[holdr] 読み取りを終えて解放しました。"
  exit 0
fi

bash "$0" "$DB" "$SEC" child &
sleep 1
echo "[holdr] $DB を読み取ったまま保持しています（${SEC} 秒間）。"
echo "[holdr] いま書き込みを試してください。"
