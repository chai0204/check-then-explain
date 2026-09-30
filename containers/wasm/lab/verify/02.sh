#!/usr/bin/env bash
# 演習 02 の判定。観測型（Node で実際に動かして、ホスト側に 42 が渡ったかを見る）。
set -uo pipefail
D="02"
command -v wat2wasm >/dev/null || { echo "前提不足: wat2wasm が見つかりません"; exit 2; }
command -v node     >/dev/null || { echo "前提不足: node が見つかりません"; exit 2; }
command -v wasmtime >/dev/null || { echo "前提不足: wasmtime が見つかりません"; exit 2; }

for f in imp.wat imp.wasm host.mjs ng.mjs; do
  [ -f "$D/$f" ] || { echo "観測 : ~/work/$D/$f が存在しない"; exit 1; }
done

# imp.wasm が env.log を import しているか（objdump で外から確かめる）
imports=$(wasm-objdump -x "$D/imp.wasm" 2>/dev/null | sed -n '/^Import\[/,/^[A-Z]/p')
echo "$imports" | grep -q 'env' || {
  echo "観測 : imp.wasm が env からの import を持っていない"
  echo "       wasm-objdump が見た Import セクション:"
  echo "${imports:-（Import セクションが無い）}" | sed 's/^/         /'
  exit 1
}

# ホスト側に 42 が渡ったか
out=$(cd "$D" && node host.mjs 2>&1)
echo "$out" | grep -q '42' || {
  echo "観測 : node host.mjs の出力に 42 が現れない"
  echo "       実際の出力:"; echo "$out" | sed 's/^/         /'
  exit 1
}

# import を外した版がリンクで失敗しているか
ngout=$(cd "$D" && node ng.mjs 2>&1)
echo "$ngout" | grep -qi 'linkerror' || {
  echo "観測 : node ng.mjs の出力に LinkError が現れない"
  echo "       実際の出力:"; echo "$ngout" | sed 's/^/         /'
  echo "       （例外を捕まえて、エラーの名前とメッセージを表示する必要があります）"
  exit 1
}

OBS="$D/observed.txt"
[ -s "$OBS" ] || { echo "観測 : $OBS が空、または存在しない"; exit 1; }
grep -qi 'unknown import' "$OBS" || {
  echo "観測 : $OBS に wasmtime の 'unknown import' が見つからない"
  echo "       貼られている内容: $(head -c 150 "$OBS" | tr '\n' ' ')"
  exit 1
}

echo "判定 : 観測型（wasm-objdump で import を確認し、Node で2通り実行した）"
echo "観測 : imp.wasm は env からの import を持っている"
echo "       node host.mjs の出力に 42 がある（ホスト側の関数が呼ばれた）"
echo "       node ng.mjs は LinkError になる（import を外すと成立しない）"
echo "       observed.txt に wasmtime の unknown import の記録がある"
echo "       → 同じ .wasm が3通りの結末になることを、自分で確かめました"
exit 0
