// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// 辞書ページの章タイトルもここから引く（2箇所で持つとずれる）。
window.CHAPTERS = [
  { n: 1, url: "/docker/theory/01-process",    t: "コンテナは、練習機の上で動く1つのプロセス" },
  { n: 2, url: "/docker/theory/02-pid1",       t: "コンテナの PID 1 は、合図を無視する" },
  { n: 3, url: "/docker/theory/03-image",      t: "イメージを決めるのは、名前ではなくダイジェスト" },
  { n: 4, url: "/docker/theory/04-storage",    t: "コンテナの書き込みは、イメージの上の1枚に入る" },
  { n: 5, url: "/docker/theory/05-ports",      t: "ポートの公開は、宛先の書き換え" },
  { n: 6, url: "/docker/theory/06-build",      t: "ビルドのキャッシュは、変えた段から後ろを全部作り直す" },
  { n: 7, url: "/docker/theory/07-privileges", t: "渡したものだけが、コンテナの力になる" },
];
