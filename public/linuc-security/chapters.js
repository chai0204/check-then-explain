// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// 辞書ページの章タイトルもここから引く（2箇所で持つとずれる）。
window.CHAPTERS = [
  { n: 1, url: "/linuc-security/theory/01-suid",     t: "SUID は、実行する人ではなく持ち主で動く" },
  { n: 2, url: "/linuc-security/theory/02-accounts", t: "「ロックした」は「無効化した」ではない" },
  { n: 3, url: "/linuc-security/theory/03-sessions", t: "入っている人と、入れる上限" },
  { n: 4, url: "/linuc-security/theory/04-ports",    t: "開いているポートは、数えないと見えない" },
  { n: 5, url: "/linuc-security/theory/05-sudo",     t: "sudo は、許したものだけに絞る" },
  { n: 6, url: "/linuc-security/theory/06-services", t: "シャドウと、使っていないサービスを止める" },
  { n: 7, url: "/linuc-security/theory/07-firewall", t: "ファイアウォールは、自分を締め出せる" },
  { n: 8, url: "/linuc-security/theory/08-crypto",   t: "鍵は、持ち主で非対称になっている" },
  { n: 9, url: "/linuc-security/theory/09-cloud",    t: "クラウドでは、守る範囲が分かれている" },
];
