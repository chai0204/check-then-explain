// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// 辞書ページの章タイトルもここから引く（2箇所で持つとずれる）。
window.CHAPTERS = [
  { n: 1, url: "/linuc-disks/theory/01-look",       t: "練習機に入り、つながっているディスクを眺める" },
  { n: 2, url: "/linuc-disks/theory/02-first-disk", t: "空のディスクを使えるようにする" },
  { n: 3, url: "/linuc-disks/theory/03-partition",  t: "パーティションの表を読む・直す" },
  { n: 4, url: "/linuc-disks/theory/04-gpt",        t: "新しい形式の表（GPT）と、起動に使う区画" },
  { n: 5, url: "/linuc-disks/theory/05-mkfs",       t: "ファイルシステムの種類と作り方" },
  { n: 6, url: "/linuc-disks/theory/06-media",      t: "USB メモリと CD をマウントする" },
  { n: 7, url: "/linuc-disks/theory/07-fstab",      t: "起動のたびにマウントする" },
  { n: 8, url: "/linuc-disks/theory/08-swap",       t: "スワップと tmpfs" },
  { n: 9, url: "/linuc-disks/theory/09-lvm",        t: "LVM で、2台のディスクを1つにまとめる" },
  { n: 10, url: "/linuc-disks/theory/10-hardware",  t: "部品の情報を読む" },
  { n: 11, url: "/linuc-disks/theory/11-modules",   t: "ドライバと、USB メモリの抜き差し" },
];
