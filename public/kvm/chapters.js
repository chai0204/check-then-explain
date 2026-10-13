// 章の一覧。/shared/theory.js が進捗バーと章ナビの描画に使う。
// 辞書ページの章タイトルもここから引く（2箇所で持つとずれる）。
window.CHAPTERS = [
  { n: 1, url: "/kvm/theory/01-cpu",     t: "仮想化支援機能は、CPU の自己申告" },
  { n: 2, url: "/kvm/theory/02-dev-kvm", t: "KVM の入口は /dev/kvm ひとつ" },
  { n: 3, url: "/kvm/theory/03-accel",   t: "QEMU は、頼まれたときだけ KVM を使う" },
  { n: 4, url: "/kvm/theory/04-speed",   t: "速くなるのは、CPU が命令を実行する部分だけ" },
  { n: 5, url: "/kvm/theory/05-guest",   t: "中から見える CPU は、アクセラレータで変わる" },
  { n: 6, url: "/kvm/theory/06-site",    t: "このサイトの練習機が KVM を使わない理由" },
];
