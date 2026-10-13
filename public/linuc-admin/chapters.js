// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// 辞書ページの章タイトルもここから引く（2箇所で持つとずれる）。
window.CHAPTERS = [
  { n: 1, url: "/linuc-admin/theory/01-ledger",     t: "ユーザの台帳は3枚に分かれている" },
  { n: 2, url: "/linuc-admin/theory/02-useradd",    t: "useradd は、頼まれたことしかしない" },
  { n: 3, url: "/linuc-admin/theory/03-membership", t: "所属は、書いたとおりに置き換わる" },
  { n: 4, url: "/linuc-admin/theory/04-lock",       t: "ロックは、扉を1つ閉めるだけ" },
  { n: 5, url: "/linuc-admin/theory/05-crontab",    t: "crontab には「誰が」の列が無い" },
  { n: 6, url: "/linuc-admin/theory/06-daily",      t: "毎日の仕事は、名前で選ばれる" },
  { n: 7, url: "/linuc-admin/theory/07-at",         t: "拒否リストを消すと、誰も使えなくなる" },
  { n: 8, url: "/linuc-admin/theory/08-locale",     t: "ロケールは、名前で指しているだけ" },
  { n: 9, url: "/linuc-admin/theory/09-iconv",      t: "文字コードは、読む側が決める" },
];
