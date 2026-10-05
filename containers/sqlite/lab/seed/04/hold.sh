#!/usr/bin/env bash
# 指定した DB に対してトランザクションを開き、そのまま指定秒数だけ保持する。
# 「もう1人の書き込み手」を用意するための道具で、演習の主役ではない。
#
#   使い方:  ./hold.sh <DBファイル> [保持する秒数]
#   例:      ./hold.sh lock.db 15
#
# ★ 末尾に & を付ける必要はない。
#   ロックを実際に取り終わってから制御を返すので、戻ってきた直後に
#   書き込みを試せば必ずロックに当たる。
#
# （& を付けて1行で繋ぐ形にしていたとき、hold.sh が起動する前に
#   読者の書き込みが走って成功してしまう事故が起きた。10〜20ms の隙間がある。
#   それを構造的に防ぐため、ロック取得を待つ親と、保持する子に分けている。）
set -uo pipefail
DB="${1:?使い方: ./hold.sh <DBファイル> [秒数]}"
SEC="${2:-15}"
ROLE="${3:-parent}"

# ---- 子: 実際にトランザクションを開いて保持する --------------------------
#   名前付きパイプ（FIFO）で sqlite3 の標準入力を開いたままにする。
#   sqlite3 は入力が閉じるまで終了しないので、その間ロックが生きる。
if [ "$ROLE" = child ]; then
  FIFO=$(mktemp -u); mkfifo "$FIFO"
  sqlite3 "$DB" < "$FIFO" > /dev/null 2>&1 &
  SQL_PID=$!
  exec 3>"$FIFO"
  printf 'BEGIN IMMEDIATE;\nINSERT INTO t VALUES(999);\n' >&3
  sleep "$SEC"
  printf 'COMMIT;\n.quit\n' >&3
  exec 3>&-
  wait "$SQL_PID" 2>/dev/null
  rm -f "$FIFO"
  echo "[hold] コミットして解放しました。"
  exit 0
fi

# ---- 親: 子を起動し、ロックが効いたことを確認してから制御を返す ----------
bash "$0" "$DB" "$SEC" child &

locked=0
for _ in $(seq 1 60); do
  # 自分で BEGIN IMMEDIATE を取ってみる。取れたら、まだ子が掴んでいない。
  if sqlite3 "$DB" 'BEGIN IMMEDIATE; ROLLBACK;' >/dev/null 2>&1; then
    sleep 0.05
  else
    locked=1; break
  fi
done

if [ "$locked" = 1 ]; then
  echo "[hold] $DB にトランザクションを開きました。${SEC} 秒間そのままにします。"
  echo "[hold] いま書き込みを試してください（この時点でロックは効いています）。"
else
  echo "[hold] ロックを確認できませんでした。もう一度試してください。" >&2
  exit 1
fi
