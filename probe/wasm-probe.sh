#!/usr/bin/env bash
# WASM 教材の演習候補を実機で確認する。失敗したら失敗したまま記録する。
cd "$(mktemp -d)" || exit 1
say() { printf '\n========== %s ==========\n' "$*"; }
run() { printf '$ %s\n' "$*"; eval "$@" 2>&1; printf '[exit %s]\n' "$?"; }

say "0. 環境"
run 'wasmtime --version'
run 'wat2wasm --version'
run 'node --version'

say "1. 41バイトの計算機（WAT を手で書いて動かす）"
cat > add.wat <<'WAT'
(module
  (func (export "add") (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.add))
WAT
run 'cat add.wat'
run 'wat2wasm add.wat -o add.wasm'
run 'ls -l add.wasm'
run 'xxd add.wasm'
run 'wasmtime run --invoke add add.wasm 3 4'
echo '--- WASM の型に文字列は無い。(result i32) を文字列にしようとすると？ ---'
cat > str.wat <<'WAT'
(module
  (func (export "greet") (result string)
    unreachable))
WAT
run 'wat2wasm str.wat -o str.wasm'

say "2. 能力は import でしか増えない"
cat > imp.wat <<'WAT'
(module
  (import "env" "log" (func $log (param i32)))
  (func (export "run")
    i32.const 42
    call $log))
WAT
run 'cat imp.wat'
run 'wat2wasm imp.wat -o imp.wasm'
echo '--- wasmtime は env.log を持っていない ---'
run 'wasmtime run --invoke run imp.wasm'
echo '--- Node から import を渡すと動くか ---'
cat > host_ok.mjs <<'JS'
import { readFile } from "node:fs/promises";
const bytes = await readFile("imp.wasm");
const { instance } = await WebAssembly.instantiate(bytes, {
  env: { log: (n) => console.log("ホストが受け取った値:", n) },
});
instance.exports.run();
JS
run 'node host_ok.mjs'
echo '--- import を1つ削ると何が起きるか ---'
cat > host_ng.mjs <<'JS'
import { readFile } from "node:fs/promises";
const bytes = await readFile("imp.wasm");
try {
  await WebAssembly.instantiate(bytes, { env: {} });
} catch (e) {
  console.log(e.constructor.name + ":", e.message);
}
JS
run 'node host_ng.mjs'

say "3. 境界を越えられるのは数値だけ（文字列は ptr と len の約束）"
cat > mem.wat <<'WAT'
(module
  (memory (export "mem") 1)
  (data (i32.const 0) "hello wasm")
  (func (export "ptr") (result i32) i32.const 0)
  (func (export "len") (result i32) i32.const 10))
WAT
run 'cat mem.wat'
run 'wat2wasm mem.wat -o mem.wasm'
echo '--- 数値しか返らないことを確認する ---'
run 'wasmtime run --invoke ptr mem.wasm'
run 'wasmtime run --invoke len mem.wasm'
echo '--- ホスト側で ptr と len を使って文字列に組み立てる ---'
cat > readstr.mjs <<'JS'
import { readFile } from "node:fs/promises";
const { instance } = await WebAssembly.instantiate(await readFile("mem.wasm"), {});
const { mem, ptr, len } = instance.exports;
console.log("ptr =", ptr(), " len =", len());
const bytes = new Uint8Array(mem.buffer, ptr(), len());
console.log("組み立てた文字列 =", new TextDecoder().decode(bytes));
console.log("線形メモリの実体 =", mem.buffer.constructor.name, mem.buffer.byteLength, "バイト");
JS
run 'node readstr.mjs'

say "4. 同じ .wasm が、ホストが違うと動かない"
cat > wasi.wat <<'WAT'
(module
  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (memory (export "memory") 1)
  (data (i32.const 8) "hello from wasi\n")
  (func (export "_start")
    ;; iovec{ptr=8, len=16} を addr 0 に置く
    i32.const 0
    i32.const 8
    i32.store
    i32.const 4
    i32.const 16
    i32.store
    ;; fd_write(fd=1, iovs=0, iovs_len=1, nwritten=20)
    i32.const 1
    i32.const 0
    i32.const 1
    i32.const 20
    call $fd_write
    drop))
WAT
run 'wat2wasm wasi.wat -o wasi.wasm'
echo '--- wasmtime は WASI を持っている ---'
run 'wasmtime run wasi.wasm'
echo '--- ブラウザ相当（素の Node）は WASI を持っていない ---'
cat > wasi_browser.mjs <<'JS'
import { readFile } from "node:fs/promises";
try {
  const { instance } = await WebAssembly.instantiate(await readFile("wasi.wasm"), {});
  instance.exports._start();
} catch (e) {
  console.log(e.constructor.name + ":", e.message);
}
JS
run 'node wasi_browser.mjs'
echo '--- 逆に、ブラウザ用の .wasm を wasmtime に渡すと？ ---'
run 'wasmtime run mem.wasm'

say "5. バイナリの中身を読む"
run 'wasm-objdump -h add.wasm'
run 'wasm-objdump -x mem.wasm'
run 'wasm2wat add.wasm'

say "完了"
