#!/bin/bash
# LinuC 主題1.04 RPM 系の檻: 本文の表と説明が拠っている yum・rpm・yumdownloader の説明（2026-10-20 の作り直しから）。
# この檻（AlmaLinux 9 のコンテナ）には、dnf・yum・rpm の man が入っていない（man -w dnf が No manual entry）。
# そこで、コマンド自身が出す説明（yum help・--help）を取る。--help の1行目 usage: には、別名を引いた先の名前が出る。
#   bash probe/linuc-packages-rpm-exam.sh（または bash probe/linuc-packages-run.sh exam）
cd "$(dirname "$0")/.." || exit 1
exec python3 -I probe/linuc-packages-seq.py --script /dev/stdin --cage rpm \
  --out logs/linuc-packages-rpm-exam.log \
  --note "本文の表と説明が拠っている yum・rpm・yumdownloader の説明" <<'INPUT'
========== この檻には dnf・yum・rpm の man が無い ==========
$ man -w dnf yum rpm yumdownloader
========== 第9章・第10章: yum のサブコマンドの説明（yum help） ==========
$ yum help | grep -E '^(autoremove|check-update|clean|deplist|info|install|list|makecache|provides|reinstall|remove|repolist|repoquery|search|upgrade) '
========== 第10章: update は upgrade の、whatprovides は provides の、groupinstall は group の別名 ==========
$ yum update --help | head -1
$ yum whatprovides --help | head -1
$ yum groupinstall --help | head -1
========== 第10章・演習12: repoquery と yumdownloader は、dnf の働きを呼ぶ道具（yum-utils）へのリンク ==========
$ ls -l /usr/bin/repoquery /usr/bin/yumdownloader
$ rpm -qf /usr/bin/yumdownloader
$ yumdownloader --help | head -1
$ yumdownloader --help | grep -A1 -E '^  --(destdir|source|resolve) '
========== 第10章: Last metadata expiration check の行を出す条件（dnf のプログラム。いちばん新しい目録の経過秒 age が 0 なら出さない） ==========
$ grep -n -B2 -A3 'Last metadata expiration check' /usr/lib/python3.9/site-packages/dnf/base.py
========== 第10章: 壊れたファイルを作るのに使った dd の bs・seek・conv=notrunc・status（dd --help） ==========
$ dd --help | grep -E '^  (bs|seek|conv|status)=|notrunc'
========== 第11章: rpm の -i・-U・-F・-e と --nodeps・--replacepkgs・--setperms（rpm --help） ==========
$ rpm --help | grep -E -- '^  -(i|U|F|e), |--nodeps|--replacepkgs|--setperms'
INPUT
