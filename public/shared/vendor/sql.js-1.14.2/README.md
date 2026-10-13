# sql.js 1.14.2（SQLite を WebAssembly にしたもの）

トップの記事一覧の「SQL で引く」が、ブラウザの中で台帳（/catalog/catalog.sql）を読み込んで引くために使う。
SQL モードを開いたときだけ読み込む（ふだんのトップは読まない）。

- 出どころ: npm の sql.js 1.14.2（2026-08-14 公開）の dist/sql-wasm.js・dist/sql-wasm.wasm と LICENSE（MIT）。
  `npm install --save-dev --save-exact sql.js@1.14.2` で入れた node_modules から写した（package-lock.json の integrity で照合済み）
- サイトの CSP は script-src 'self' なので CDN からは読めない。自前で配る
- WebAssembly を動かすため、トップのページだけ CSP に 'wasm-unsafe-eval' と connect-src 'self' を足している（public/_headers）
- sha256:
  - sql-wasm.js   f1c84000dbc856c9d87f4f3aabc4d3654bd436165db4be3da13751db3a9c20d7
  - sql-wasm.wasm 38c14f6e379210bc942bdc4ebca44e7bfdb4318ecc1c72ca666a28fdce96670a
  - LICENSE       60a3f6e4d7b29b4321359e683b36cf198d24f58e24582070f56e6fa89d5ee2be
