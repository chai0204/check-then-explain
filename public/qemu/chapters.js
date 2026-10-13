// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// 辞書ページの章タイトルもここから引く（2箇所で持つとずれる）。
window.CHAPTERS = [
  { n: 1, url: "/qemu/theory/01-machine",  t: "何も渡さなくても、PC が1台組み上がる" },
  { n: 2, url: "/qemu/theory/02-serial",   t: "シリアルの先は、あなたの端末そのもの" },
  { n: 3, url: "/qemu/theory/03-disk",     t: "ディスクは、書いたところだけを持つファイル" },
  { n: 4, url: "/qemu/theory/04-tcg",      t: "CPU は、命令を翻訳して動いている" },
  { n: 5, url: "/qemu/theory/05-network",  t: "ネットワークも、QEMU のプロセスの中にある" },
  { n: 6, url: "/qemu/theory/06-firmware", t: "ファームウェアは、差し替えられるファイル" },
  { n: 7, url: "/qemu/theory/07-libvirt",  t: "libvirt は、コマンド行を組み立てているだけ" },
];
