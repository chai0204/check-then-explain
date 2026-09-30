// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// theory.js 側にハードコードすると1テーマしか載らないので、テーマごとにここで渡す。
window.CHAPTERS = [
  { n: 1, url: "/sqlite/theory/01-file",        t: "これはファイルである" },
  { n: 2, url: "/sqlite/theory/02-affinity",    t: "型は宣言ではなく提案" },
  { n: 3, url: "/sqlite/theory/03-transaction", t: "まとめると速い" },
  { n: 4, url: "/sqlite/theory/04-lock",        t: "同時に書けるのは1人" },
  { n: 5, url: "/sqlite/theory/05-directory",   t: "ディレクトリに書けないと" },
];
