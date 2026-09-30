#!/usr/bin/env bash
# 演習 05 の判定。痕跡型（読者が書いた調査結果を検査する）。
# 調べれば分かることを、実際に調べたかどうかで判定する。
set -uo pipefail
D="05"
A="$D/answers.txt"
command -v wasm-objdump >/dev/null || { echo "前提不足: wasm-objdump が見つかりません"; exit 2; }

[ -f "$D/mystery.wasm" ] || {
  echo "観測 : ~/work/$D/mystery.wasm が無い（lab start 05 で配置されます）"
  exit 1
}
[ -s "$A" ] || { echo "観測 : $A が空、または存在しない"; exit 1; }

miss=()
grep -qi 'read_file'  "$A" || miss+=("import の1つ（ファイルを読む側）")
grep -qi 'http_post'  "$A" || miss+=("import のもう1つ（外に送る側）")
grep -qiE '_start'    "$A" || miss+=("export している関数の名前")
grep -qiE 'memory'    "$A" || miss+=("export しているメモリ")
grep -qiE 'passwd'    "$A" || miss+=("メモリに置かれた1つめの文字列")
grep -qiE 'collect|example\.invalid|https' "$A" || miss+=("メモリに置かれた2つめの文字列（送信先）")

if [ ${#miss[@]} -gt 0 ]; then
  echo "観測 : answers.txt に次の項目が見つからない"
  for m in "${miss[@]}"; do echo "         ・$m"; done
  echo "       wasm-objdump -x mystery.wasm の Import / Export / Data セクションを見てください"
  exit 1
fi

# 実行してみた記録があるか（何も起きなかったことを自分で確かめたか）
grep -qiE 'unknown import|env::read_file|失敗|エラー|error|何も' "$A" || {
  echo "観測 : answers.txt に、実際に wasmtime で実行したときの結果が見つからない"
  echo "       最後の手順（import を渡さずに実行する）が残っています"
  exit 1
}

# 判定側でも独立に確かめる
rout=$(cd "$D" && wasmtime run mystery.wasm 2>&1 || true)
imports=$(wasm-objdump -x "$D/mystery.wasm" 2>/dev/null | sed -n '/^Import\[/,/^Function\[/p' | grep -c 'env\.')

echo "判定 : 痕跡型（あなたが書いた調査結果を、objdump の出力と突き合わせた）"
echo "観測 : answers.txt に import 2件・export 2件・Data の文字列2件が記録されている"
echo "       mystery.wasm の Import セクションには env. から始まる項目が ${imports} 件ある"
echo "       import を渡さずに実行すると、次のように拒否される:"
printf '%s\n' "$rout" | grep -iE 'unknown import|Caused by|Error' | head -3 | sed 's/^/         /'
echo "       → 配布された .wasm が何を要求しているかは、実行しなくても分かる"
exit 0
