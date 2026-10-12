// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// 辞書ページの章タイトルもここから引く（2箇所で持つとずれる）。
window.CHAPTERS = [
  { n: 1, url: "/linuc-services/theory/01-clock",     t: "時計は2つある" },
  { n: 2, url: "/linuc-services/theory/02-timezone",  t: "タイムゾーンは表示の都合だけ" },
  { n: 3, url: "/linuc-services/theory/03-ntp",       t: "基準を渡されるまで始まらない" },
  { n: 4, url: "/linuc-services/theory/04-rsyslog",   t: "宛先は受け手の表が決める" },
  { n: 5, url: "/linuc-services/theory/05-journald",  t: "journald は隣にある別の箱" },
  { n: 6, url: "/linuc-services/theory/06-logrotate", t: "捨てる判断も受け手側にある" },
  { n: 7, url: "/linuc-services/theory/07-mail",      t: "宛先に書いた名前は希望にすぎない" },
];
