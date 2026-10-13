// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// 辞書ページの章タイトルもここから引く（2箇所で持つとずれる）。
window.CHAPTERS = [
  { n: 1,  url: "/linuc-boot/theory/01-virsh",     t: "virsh は電源を入れ、止まるよう頼むだけ" },
  { n: 2,  url: "/linuc-boot/theory/02-ssh",       t: "入れるかは受け取る側のファイルが決める" },
  { n: 3,  url: "/linuc-boot/theory/03-container", t: "コンテナのカーネルはホストのもの" },
  { n: 4,  url: "/linuc-boot/theory/04-install",   t: "GUI が無くても既定は graphical.target" },
  { n: 5,  url: "/linuc-boot/theory/05-boot",      t: "ファームウェアが必ず読めるのは FAT の中のファイルだけ" },
  { n: 6,  url: "/linuc-boot/theory/06-target",    t: "Ubuntu では、root にパスワードが無いとシングルユーザモードは何も聞かない" },
  { n: 7,  url: "/linuc-boot/theory/07-shutdown",  t: "halt では電源は切れない" },
  { n: 8,  url: "/linuc-boot/theory/08-signal",    t: "kill は止めない、合図を送るだけ" },
  { n: 9,  url: "/linuc-boot/theory/09-hup",       t: "exit では消えず、切断で消える" },
  { n: 10, url: "/linuc-boot/theory/10-x11",       t: "X では画面の側がサーバー" },
];
