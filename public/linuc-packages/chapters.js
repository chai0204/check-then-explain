// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// 辞書ページの章タイトルもここから引く（2箇所で持つとずれる）。
window.CHAPTERS = [
  { n: 1, url: "/linuc-packages/theory/01-package",     t: "入っているかどうかは台帳が決める" },
  { n: 2, url: "/linuc-packages/theory/02-apt",         t: "apt は目録を読んで台帳に書く" },
  { n: 3, url: "/linuc-packages/theory/03-sources",     t: "目録は取りに行くまで古いまま" },
  { n: 4, url: "/linuc-packages/theory/04-dpkg",        t: "dpkg は依存を読めるが取りに行かない" },
  { n: 5, url: "/linuc-packages/theory/05-yum",         t: "yum は目録を自分で取りに行く" },
  { n: 6, url: "/linuc-packages/theory/06-rpm-query",   t: "rpm -V が黙るのは台帳どおりだから" },
  { n: 7, url: "/linuc-packages/theory/07-rpm-install", t: "OK は確かめた範囲の OK" },
];
