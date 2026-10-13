// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// 辞書ページの章タイトルもここから引く（2箇所で持つとずれる）。
window.CHAPTERS = [
  { n: 1, url: "/linuc-shell/theory/01-startup",  t: "起動ファイルはシェルの生まれ方で決まる" },
  { n: 2, url: "/linuc-shell/theory/02-source",   t: "子のシェルは親を書き換えられない" },
  { n: 3, url: "/linuc-shell/theory/03-lists",    t: "&& と || は直前の数だけを見る" },
  { n: 4, url: "/linuc-shell/theory/04-script",   t: "先頭行を読むのはカーネル" },
  { n: 5, url: "/linuc-shell/theory/05-args",     t: "引数は渡す側で切られている" },
  { n: 6, url: "/linuc-shell/theory/06-status",   t: "返せるのは 0〜255 の数1つ" },
  { n: 7, url: "/linuc-shell/theory/07-loops",    t: "パイプの先で数えた数は持ち帰れない" },
  { n: 8, url: "/linuc-shell/theory/08-function", t: "関数は子ではない" },
];
