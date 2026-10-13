// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// 辞書ページの章タイトルもここから引く（2箇所で持つとずれる）。
window.CHAPTERS = [
  { n: 1, url: "/podman/theory/01-daemonless", t: "podman には、頼む相手のデーモンがいない" },
  { n: 2, url: "/podman/theory/02-userns",     t: "コンテナの中の root は、外では student" },
  { n: 3, url: "/podman/theory/03-storage",    t: "イメージの置き場所は、ユーザごとに別" },
  { n: 4, url: "/podman/theory/04-network",    t: "rootless のネットワークは、カーネルの外で中継される" },
  { n: 5, url: "/podman/theory/05-pod",        t: "pod は、ネットワークを分け合うコンテナの組" },
  { n: 6, url: "/podman/theory/06-systemd",    t: "ログアウトしても動かし続けるのは、systemd の仕事" },
  { n: 7, url: "/podman/theory/07-compat",     t: "同じコマンドで、違う仕組み" },
];
