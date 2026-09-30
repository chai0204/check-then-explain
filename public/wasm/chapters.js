// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// theory.js 側にハードコードすると1テーマしか載らないので、テーマごとにここで渡す。
window.CHAPTERS = [
  { n: 1, url: "/wasm/theory/01-machine", t: "41バイトの計算機" },
  { n: 2, url: "/wasm/theory/02-import",  t: "能力は import から" },
  { n: 3, url: "/wasm/theory/03-memory",  t: "越えるのは数値だけ" },
  { n: 4, url: "/wasm/theory/04-host",    t: "ホストが違うと動かない" },
  { n: 5, url: "/wasm/theory/05-binary",  t: "バイナリを読む" },
];
