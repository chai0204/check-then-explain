#!/usr/bin/env bash
# 演習 03 の判定。観測型（Node でメモリを読んで文字列が組み立てられるかを見る）。
set -uo pipefail
D="03"
command -v wat2wasm >/dev/null || { echo "前提不足: wat2wasm が見つかりません"; exit 2; }
command -v node     >/dev/null || { echo "前提不足: node が見つかりません"; exit 2; }

for f in mem.wat mem.wasm read.mjs; do
  [ -f "$D/$f" ] || { echo "観測 : ~/work/$D/$f が存在しない"; exit 1; }
done

dump=$(wasm-objdump -x "$D/mem.wasm" 2>/dev/null)
echo "$dump" | grep -q '"mem"' || {
  echo "観測 : mem.wasm が memory を \"mem\" として export していない"
  echo "$dump" | sed -n '/^Export\[/,/^[A-Z]/p' | sed 's/^/         /'
  exit 1
}
echo "$dump" | grep -q 'hello wasm' || {
  echo "観測 : Data セクションに 'hello wasm' が見つからない"
  echo "$dump" | sed -n '/^Data\[/,$p' | sed 's/^/         /'
  exit 1
}

# 独立した検証器で ptr/len とメモリを読み、文字列が取り出せるかを確かめる
probe=$(mktemp --suffix=.mjs)
cat > "$probe" <<'JS'
import { readFile } from "node:fs/promises";
const { instance } = await WebAssembly.instantiate(await readFile(process.argv[2]), {});
const e = instance.exports;
if (typeof e.ptr !== "function") { console.log("NG ptr が関数として export されていない"); process.exit(1); }
if (typeof e.len !== "function") { console.log("NG len が関数として export されていない"); process.exit(1); }
if (!e.mem || !e.mem.buffer)     { console.log("NG mem が memory として export されていない"); process.exit(1); }
const p = e.ptr(), l = e.len();
if (typeof p !== "number" || typeof l !== "number") { console.log("NG ptr/len が数値を返していない"); process.exit(1); }
const s = new TextDecoder().decode(new Uint8Array(e.mem.buffer, p, l));
console.log("OK", p, l, e.mem.buffer.byteLength, s);
JS
res=$(cd "$D" && node "$probe" mem.wasm 2>&1); rm -f "$probe"
case "$res" in
  OK*) ;;
  *) echo "観測 : 独立した検証器が mem.wasm から文字列を取り出せなかった"
     echo "       $res"; exit 1 ;;
esac
read -r _ p l total s <<< "$res"
[ "$s" = "hello wasm" ] || { echo "観測 : 取り出した文字列が「$s」（hello wasm を期待）"; exit 1; }

# 読者のスクリプトも動き、文字列とメモリサイズを表示しているか
out=$(cd "$D" && node read.mjs 2>&1)
echo "$out" | grep -q 'hello wasm' || {
  echo "観測 : node read.mjs の出力に 'hello wasm' が現れない"
  echo "       実際の出力:"; echo "$out" | sed 's/^/         /'
  exit 1
}
echo "$out" | grep -qE '65536|64 ?KB|64 ?KiB' || {
  echo "観測 : node read.mjs の出力にメモリの大きさ（65536）が現れない"
  echo "       実際の出力:"; echo "$out" | sed 's/^/         /'
  exit 1
}

echo "判定 : 観測型（独立した検証器で mem を読み、あなたのスクリプトも実行した）"
echo "観測 : ptr()=${p} / len()=${l} という数値だけが返る"
echo "       その2つを使ってメモリから取り出すと「${s}」になる"
echo "       線形メモリの実体は ${total} バイト（1ページ）"
echo "       Data セクションに 'hello wasm' が平文で入っている"
exit 0
