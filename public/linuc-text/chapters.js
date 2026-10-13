// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// 辞書ページの章タイトルもここから引く（2箇所で持つとずれる）。
window.CHAPTERS = [
  { n: 1,  url: "/linuc-text/theory/01-quote",    t: "引用符と変数は届く前に片づく" },
  { n: 2,  url: "/linuc-text/theory/02-path",     t: "カレントは探さない" },
  { n: 3,  url: "/linuc-text/theory/03-man",      t: "man は別物を説明することがある" },
  { n: 4,  url: "/linuc-text/theory/04-lines",    t: "1行は改行で終わる範囲" },
  { n: 5,  url: "/linuc-text/theory/05-columns",  t: "uniq は隣どうしだけ" },
  { n: 6,  url: "/linuc-text/theory/06-sed",      t: "sed は結果を見せるだけ" },
  { n: 7,  url: "/linuc-text/theory/07-redirect", t: "リダイレクトは左から配線" },
  { n: 8,  url: "/linuc-text/theory/08-pipe",     t: "xargs は空白で区切る" },
  { n: 9,  url: "/linuc-text/theory/09-regex",    t: ". は何にでも当たる" },
  { n: 10, url: "/linuc-text/theory/10-vi",       t: ":w! は読み取り専用にも書く" },
];
