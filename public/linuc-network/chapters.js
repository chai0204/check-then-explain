// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// 辞書ページの章タイトルもここから引く（2箇所で持つとずれる）。
window.CHAPTERS = [
  { n: 1, url: "/linuc-network/theory/01-address",   t: "アドレスは、分けるたびに減る" },
  { n: 2, url: "/linuc-network/theory/02-interface", t: "ifconfig に見えないアドレスがある" },
  { n: 3, url: "/linuc-network/theory/03-owner",     t: "ifup は、自分が付けたものしか知らない" },
  { n: 4, url: "/linuc-network/theory/04-route",     t: "返事をしたのは、相手ではなかった" },
  { n: 5, url: "/linuc-network/theory/05-trace",     t: "traceroute は、断られた返事で道を知る" },
  { n: 6, url: "/linuc-network/theory/06-ipv6",      t: "IPv6 のアドレスは、頼まなくても付いている" },
  { n: 7, url: "/linuc-network/theory/07-ports",     t: "LISTEN していても、外からは入れない" },
  { n: 8, url: "/linuc-network/theory/08-dns",       t: "resolv.conf に書いた1行は、消される" },
  { n: 9, url: "/linuc-network/theory/09-names",     t: "dig と ping は、別の表を引いている" },
];
