#!/usr/bin/env bash
# 演習 04 の判定。観測型（wasmtime で実際に出力が出るかを見る）。
set -uo pipefail
D="04"
command -v wat2wasm >/dev/null || { echo "前提不足: wat2wasm が見つかりません"; exit 2; }
command -v wasmtime >/dev/null || { echo "前提不足: wasmtime が見つかりません"; exit 2; }
command -v node     >/dev/null || { echo "前提不足: node が見つかりません"; exit 2; }

for f in wasi.wat wasi.wasm browser.mjs; do
  [ -f "$D/$f" ] || { echo "観測 : ~/work/$D/$f が存在しない"; exit 1; }
done

dump=$(wasm-objdump -x "$D/wasi.wasm" 2>/dev/null)
echo "$dump" | grep -q 'wasi_snapshot_preview1' || {
  echo "観測 : wasi.wasm が wasi_snapshot_preview1 を import していない"
  echo "$dump" | sed -n '/^Import\[/,/^[A-Z]/p' | sed 's/^/         /'
  exit 1
}
echo "$dump" | grep -q '"_start"' || {
  echo "観測 : wasi.wasm が _start を export していない"
  echo "       （wasmtime run は _start を探して呼びます）"
  exit 1
}

# wasmtime で実際に標準出力に何か出るか
out=$(cd "$D" && wasmtime run wasi.wasm 2>/dev/null)
[ -n "$out" ] || {
  echo "観測 : wasmtime run wasi.wasm が標準出力に何も出さない"
  echo "       wasmtime の全出力（標準エラーを含む）:"
  (cd "$D" && wasmtime run wasi.wasm 2>&1 | sed 's/^/         /')
  exit 1
}

# ブラウザ相当では落ちること
bout=$(cd "$D" && node browser.mjs 2>&1)
echo "$bout" | grep -qiE 'typeerror|linkerror|error' || {
  echo "観測 : node browser.mjs がエラーを表示しない"
  echo "       実際の出力:"; echo "$bout" | sed 's/^/         /'
  exit 1
}

OBS="$D/observed.txt"
[ -s "$OBS" ] || { echo "観測 : $OBS が空、または存在しない"; exit 1; }
grep -qiE 'wasi_snapshot_preview1' "$OBS" || {
  echo "観測 : $OBS に、ブラウザ相当で落ちたときのメッセージが見つからない"
  echo "       貼られている内容: $(head -c 200 "$OBS" | tr '\n' ' ')"
  exit 1
}
grep -qE '終了コード|exit' "$OBS" || {
  echo "観測 : $OBS に、逆向き（mem.wasm を wasmtime に渡す）の結果が見つからない"
  echo "       手順4がまだ残っています"
  exit 1
}

# 逆向きの事実を判定側でも確かめる（エラーにならず、何も出ない）
if [ -f "$D/mem.wasm" ]; then
  rout=$(cd "$D" && wasmtime run mem.wasm 2>&1); rc=$?
else
  rout=""; rc="-"
fi

echo "判定 : 観測型（2つのホストで同じ .wasm を実行し、逆向きも確かめた）"
echo "観測 : wasmtime では標準出力に「$(printf '%s' "$out" | head -1)」が出た"
echo "       ブラウザ相当（素の Node）では失敗する"
if [ "$rc" = "0" ] && [ -z "$rout" ]; then
  echo "       逆向き: mem.wasm を wasmtime に渡すと終了コード 0 で、出力は空（何も起きない）"
fi
echo "       → 移植性は .wasm の性質ではなく、ホストが約束を満たすかで決まる"
exit 0
