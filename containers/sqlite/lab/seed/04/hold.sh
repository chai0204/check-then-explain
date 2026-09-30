#!/usr/bin/env bash
# 指定した DB に対してトランザクションを開き、そのまま指定秒数だけ保持する。
# 「もう1つの書き込み手」を用意するための道具で、演習の主役ではない。
#
#   使い方:  ./hold.sh <DBファイル> [保持する秒数]
#   例:      ./hold.sh lock.db 15 &
#
# 中では名前付きパイプ（FIFO）を使って sqlite3 の標準入力を開いたままにしている。
# sqlite3 は入力が閉じるまで終了しないので、その間トランザクションが生き続ける。
set -uo pipefail
DB="${1:?使い方: ./hold.sh <DBファイル> [秒数]}"
SEC="${2:-15}"

FIFO=$(mktemp -u); mkfifo "$FIFO"
sqlite3 "$DB" < "$FIFO" > /dev/null 2>&1 &
SQL_PID=$!
exec 3>"$FIFO"

printf 'BEGIN IMMEDIATE;\nINSERT INTO t VALUES(999);\n' >&3
echo "[hold] $DB にトランザクションを開きました。${SEC} 秒間そのままにします。"
echo "[hold] いま別のコマンドで書き込みを試してください。"
sleep "$SEC"

printf 'COMMIT;\n.quit\n' >&3
exec 3>&-
wait "$SQL_PID" 2>/dev/null
rm -f "$FIFO"
echo "[hold] コミットして解放しました。"
