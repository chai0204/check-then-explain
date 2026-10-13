// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// 辞書ページの章タイトルもここから引く（2箇所で持つとずれる）。
window.CHAPTERS = [
  { n: 1, url: "/linuc-files/theory/01-permissions",  t: "名前と中身は別の場所にある" },
  { n: 2, url: "/linuc-files/theory/02-umask",        t: "umask は引き算ではない" },
  { n: 3, url: "/linuc-files/theory/03-special-bits", t: "特殊なビットは「誰として」と「誰が消せるか」" },
  { n: 4, url: "/linuc-files/theory/04-cp-mv-rm",     t: "コピーは作り直し、移動は書き換え" },
  { n: 5, url: "/linuc-files/theory/05-find",         t: "find は名前をたどり、属性で選ぶ" },
  { n: 6, url: "/linuc-files/theory/06-tar",          t: "tar は束ねるだけ" },
  { n: 7, url: "/linuc-files/theory/07-links",        t: "リンクは名前を増やすか、道順を書くか" },
  { n: 8, url: "/linuc-files/theory/08-locate",       t: "locate は索引の写真を引く" },
];
