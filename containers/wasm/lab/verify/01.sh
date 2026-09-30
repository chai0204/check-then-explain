#!/usr/bin/env bash
# 演習 01 の判定。観測型（実際に呼び出して戻り値を見る）。
set -uo pipefail
D="01"
command -v wat2wasm >/dev/null || { echo "前提不足: wat2wasm が見つかりません"; exit 2; }
command -v wasmtime >/dev/null || { echo "前提不足: wasmtime が見つかりません"; exit 2; }

[ -f "$D/add.wat" ]  || { echo "観測 : ~/work/$D/add.wat が存在しない"; exit 1; }
[ -f "$D/add.wasm" ] || {
  echo "観測 : ~/work/$D/add.wasm が存在しない（add.wat はある）"
  echo "       wat2wasm でコンパイルする手順が残っています"
  exit 1
}

# マジックナンバーの確認（\0asm）
magic=$(xxd -l 4 -p "$D/add.wasm")
[ "$magic" = "0061736d" ] || {
  echo "観測 : add.wasm の先頭4バイトが 0061736d ではない（実際: $magic）"
  exit 1
}

# 実際に呼んで 7 が返るか
out=$(cd "$D" && wasmtime run --invoke add add.wasm 3 4 2>/dev/null | tail -1)
[ "$out" = "7" ] || {
  echo "観測 : wasmtime run --invoke add add.wasm 3 4 の戻り値が「$out」（7 を期待）"
  echo "       wasmtime の全出力:"
  (cd "$D" && wasmtime run --invoke add add.wasm 3 4 2>&1 | sed 's/^/         /')
  exit 1
}
# 別の入力でも正しいか（定数 7 を返す実装を弾く）
out2=$(cd "$D" && wasmtime run --invoke add add.wasm 100 -30 2>/dev/null | tail -1)
[ "$out2" = "70" ] || {
  echo "観測 : add(3,4)=7 は通ったが、add(100,-30) が「$out2」（70 を期待）"
  echo "       引数を使わずに定数を返していませんか"
  exit 1
}

OBS="$D/observed.txt"
[ -s "$OBS" ] || { echo "観測 : $OBS が空、または存在しない（文字列を返そうとしたときのメッセージを貼ってください）"; exit 1; }
grep -qiE 'unexpected token string|expected \)' "$OBS" || {
  echo "観測 : $OBS に wat2wasm の型エラーが見つからない"
  echo "       貼られている内容: $(head -c 150 "$OBS" | tr '\n' ' ')"
  exit 1
}

bytes=$(stat -c %s "$D/add.wasm")
echo "判定 : 観測型（2組の引数で実際に呼び出し、戻り値を確認した）"
echo "観測 : add.wasm は ${bytes} バイト、先頭4バイトは 0061736d（\\0asm）"
echo "       add(3,4)=7 / add(100,-30)=70 — 引数を使って計算している"
echo "       observed.txt に wat2wasm の型エラーの記録があり、string 型が無いことを自分で確かめています"
exit 0
