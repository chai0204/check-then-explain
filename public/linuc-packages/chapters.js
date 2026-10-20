// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// 辞書ページの章タイトルもここから引く（2箇所で持つとずれる）。
// 第1〜8章は Debian 系の檻、第9〜11章は RPM 系の檻（2026-10-20 に、普通の使い方から順を追う形に組み直した）。
window.CHAPTERS = [
  { n: 1,  url: "/linuc-packages/theory/01-install",    t: "パッケージを入れて、使って、消す" },
  { n: 2,  url: "/linuc-packages/theory/02-list",       t: "いま何が入っているかを調べる" },
  { n: 3,  url: "/linuc-packages/theory/03-files",      t: "入れたファイルがどこに置かれたかを調べる" },
  { n: 4,  url: "/linuc-packages/theory/04-ledger",     t: "台帳とファイルを見比べる" },
  { n: 5,  url: "/linuc-packages/theory/05-depends",    t: "依存関係のあるパッケージを入れて、消す" },
  { n: 6,  url: "/linuc-packages/theory/06-repository", t: "パッケージはどこから来るか" },
  { n: 7,  url: "/linuc-packages/theory/07-deb-file",   t: ".deb ファイルを直接入れる" },
  { n: 8,  url: "/linuc-packages/theory/08-build",      t: "パッケージを自分で作る" },
  { n: 9,  url: "/linuc-packages/theory/09-rpm",        t: "RPM 系で同じことをする" },
  { n: 10, url: "/linuc-packages/theory/10-yum-repo",   t: "yum のリポジトリを足して、署名を確かめる" },
  { n: 11, url: "/linuc-packages/theory/11-rpm-file",   t: ".rpm ファイルを rpm で直接入れて、確かめる" },
];
