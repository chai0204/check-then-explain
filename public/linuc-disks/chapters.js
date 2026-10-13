// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// 辞書ページの章タイトルもここから引く（2箇所で持つとずれる）。
window.CHAPTERS = [
  { n: 1, url: "/linuc-disks/theory/01-hardware",  t: "HDD か SSD かは、装置の申告で決まる" },
  { n: 2, url: "/linuc-disks/theory/02-modules",   t: "ドライバは、外しても戻ってくる" },
  { n: 3, url: "/linuc-disks/theory/03-partition", t: "パーティションの表は、目次にすぎない" },
  { n: 4, url: "/linuc-disks/theory/04-esp",       t: "起動の入口は、マウントしなくても見つかる" },
  { n: 5, url: "/linuc-disks/theory/05-lvm",       t: "LV を広げても、ファイルシステムは広がらない" },
  { n: 6, url: "/linuc-disks/theory/06-mkfs",      t: "ファイルシステムは、作った大きさより小さく見える" },
  { n: 7, url: "/linuc-disks/theory/07-swap",      t: "tmpfs は、メモリを先に取らない" },
  { n: 8, url: "/linuc-disks/theory/08-mount",     t: "マウントは、名前ではなく中身の印で指す" },
];
