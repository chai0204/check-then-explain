#!/usr/bin/env bash
# 模範解答のとおりに5演習すべてを解き、lab check が全部通るかを確認する。
# solutions/*.md に書いたコードと、ここで書くコードは一致させる。
cd "$HOME" || exit 1
fail=0
step() { printf '\n########## %s ##########\n' "$*"; }

step "01 41バイトの計算機をつくる"
lab start 01 >/dev/null
cd ~/work/01 || exit 1
cat > add.wat <<'WAT'
(module
  (func (export "add") (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.add))
WAT
wat2wasm add.wat -o add.wasm
ls -l add.wasm; xxd add.wasm
wasmtime run --invoke add add.wasm 3 4
printf '(module\n  (func (export "greet") (result string)\n    unreachable))\n' > str.wat
wat2wasm str.wat -o str.wasm > observed.txt 2>&1
cat observed.txt
cd ~ && lab check 01 || fail=1

step "02 ホストから能力をもらう"
lab start 02 >/dev/null
cd ~/work/02 || exit 1
cat > imp.wat <<'WAT'
(module
  (import "env" "log" (func $log (param i32)))
  (func (export "run")
    i32.const 42
    call $log))
WAT
wat2wasm imp.wat -o imp.wasm
cat > host.mjs <<'JS'
import { readFile } from "node:fs/promises";
const bytes = await readFile("imp.wasm");
const { instance } = await WebAssembly.instantiate(bytes, {
  env: { log: (n) => console.log("ホストが受け取った値:", n) },
});
instance.exports.run();
JS
cat > ng.mjs <<'JS'
import { readFile } from "node:fs/promises";
const bytes = await readFile("imp.wasm");
try {
  await WebAssembly.instantiate(bytes, { env: {} });
} catch (e) {
  console.log(e.constructor.name + ":", e.message);
}
JS
wasmtime run --invoke run imp.wasm > observed.txt 2>&1
cat observed.txt
node host.mjs
node ng.mjs
cd ~ && lab check 02 || fail=1

step "03 数値2つで文字列を渡す"
lab start 03 >/dev/null
cd ~/work/03 || exit 1
cat > mem.wat <<'WAT'
(module
  (memory (export "mem") 1)
  (data (i32.const 0) "hello wasm")
  (func (export "ptr") (result i32) i32.const 0)
  (func (export "len") (result i32) i32.const 10))
WAT
wat2wasm mem.wat -o mem.wasm
cat > read.mjs <<'JS'
import { readFile } from "node:fs/promises";
const { instance } = await WebAssembly.instantiate(await readFile("mem.wasm"), {});
const { mem, ptr, len } = instance.exports;
console.log("ptr =", ptr(), " len =", len());
const bytes = new Uint8Array(mem.buffer, ptr(), len());
console.log("組み立てた文字列 =", new TextDecoder().decode(bytes));
console.log("線形メモリの実体 =", mem.buffer.constructor.name, mem.buffer.byteLength, "バイト");
JS
node read.mjs
wasm-objdump -x mem.wasm | tail -4
cd ~ && lab check 03 || fail=1

step "04 同じ .wasm を2つのホストに渡す"
lab start 04 >/dev/null
cd ~/work/04 || exit 1
cat > wasi.wat <<'WAT'
(module
  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (memory (export "memory") 1)
  (data (i32.const 8) "hello from wasi\n")
  (func (export "_start")
    i32.const 0
    i32.const 8
    i32.store
    i32.const 4
    i32.const 16
    i32.store
    i32.const 1
    i32.const 0
    i32.const 1
    i32.const 20
    call $fd_write
    drop))
WAT
wat2wasm wasi.wat -o wasi.wasm
cat > browser.mjs <<'JS'
import { readFile } from "node:fs/promises";
try {
  const { instance } = await WebAssembly.instantiate(await readFile("wasi.wasm"), {});
  instance.exports._start();
} catch (e) {
  console.log(e.constructor.name + ":", e.message);
}
JS
echo "--- wasmtime ---"; wasmtime run wasi.wasm
echo "--- ブラウザ相当 ---"; node browser.mjs | tee observed.txt
echo "--- 逆向き（WASI を使っていない .wasm を wasmtime に渡す） ---"
cp ../03/mem.wasm .
wasmtime run mem.wasm
echo "終了コード: $?" | tee -a observed.txt
cd ~ && lab check 04 || fail=1

step "05 実行する前に調べる"
lab start 05 >/dev/null
cd ~/work/05 || exit 1
wasm-objdump -x mystery.wasm > dump.txt
{
  echo "1. import:"
  echo "   env.read_file  (i32,i32)->i32"
  echo "   env.http_post  (i32,i32)->nil"
  echo "2. export: memory（メモリ）と _start（関数）"
  echo "3. メモリの初期データ: オフセット0 に /etc/passwd、オフセット64 に https://example.invalid/collect"
  echo "4. 推測: /etc/passwd を read_file で読み、その URL へ http_post で送ろうとしている。"
  echo "   ホストが import を1つも渡さなければ、インスタンス化の段階で止まるので何もできない。"
  echo "5. 実際に実行した結果:"
  wasmtime run mystery.wasm 2>&1 | sed 's/^/   /'
} > answers.txt
cat answers.txt
cd ~ && lab check 05 || fail=1

step "最終状態"
lab ls
printf '\n総合: %s\n' "$([ $fail -eq 0 ] && echo '全演習の verify が通った' || echo '通らない演習がある')"
exit $fail
