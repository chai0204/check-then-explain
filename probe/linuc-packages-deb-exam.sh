#!/bin/bash
# LinuC 主題1.04 Debian 系の檻: 本文の表と説明が拠っている man の記述（2026-10-20 の作り直しから）。
# 本文は man を写さず、表の「何をするか」の欄や確認問題の答えにまとめている。そのもとの記述を、読者と同じ打ち方で取る。
# man の出力をパイプに渡すと、ページャを使わずに、端末の幅（80 桁）で整形して出る。
#   bash probe/linuc-packages-deb-exam.sh（または bash probe/linuc-packages-run.sh exam）
cd "$(dirname "$0")/.." || exit 1
exec python3 -I probe/linuc-packages-seq.py --script /dev/stdin --cage deb \
  --out logs/linuc-packages-deb-exam.log \
  --note "本文の表と説明が拠っている man の記述" <<'INPUT'
========== 第2章: dpkg は端末へ出すとき less に渡し、LESS を -FRSXMQ にする（man dpkg-query）。-F は「1画面に収まれば閉じる」、-S は「長い行を切る」（man less） ==========
$ man dpkg-query | grep -A6 '^       LESS$'
$ man less 2>/dev/null | grep -A2 -E '^       -(F|S) or'
========== 第1章: man-db のトリガが動かす mandb の -p は、索引から消えた説明書の行を消さない（man mandb） ==========
$ man mandb 2>/dev/null | grep -A3 -E '^       -p, --no-purge'
========== 第5章: autoremove の説明と、印は apt-mark で付け替えられること（man apt） ==========
$ man apt | sed -n '/^       autoremove (apt-get(8))$/,/^       satisfy (apt-get(8))$/p'
========== 第5章: apt-cache showpkg は、版ごとの依存関係と逆向きの依存関係をまとめて出す（man apt-cache） ==========
$ man apt-cache | sed -n '/^       showpkg pkg\.\.\.$/,/^       stats$/p'
========== 第6章: sources.list.d/ のファイルは .list（1行の形式）か .sources（deb822 形式）で終わる。1行の形式の欄と、[ ] のオプションは省ける（man sources.list） ==========
$ man sources.list | sed -n '/^SOURCES.LIST.D$/,/^DEB822-STYLE FORMAT$/p'
========== 第6章の表: apt の upgrade と full-upgrade（man apt） ==========
$ man apt | sed -n '/^       upgrade (apt-get(8))$/,/^       install, reinstall, remove, purge (apt-get(8))$/p'
========== 第6章の表: apt-get の upgrade と dist-upgrade（man apt-get） ==========
$ man apt-get | sed -n '/^       upgrade$/,/^       dselect-upgrade$/p'
========== 第6章の表: install は、入っているものを1つだけ上げるのにも使う（man apt-get） ==========
$ man apt-get | grep -A5 'This is also the target to use'
========== 第7章: -f は --fix-broken（man apt-get） ==========
$ man apt-get | sed -n '/^       -f, --fix-broken$/,/^       -m, --ignore-missing, --fix-missing$/p'
========== 第7章: dpkg --configure の -a（man dpkg） ==========
$ man dpkg | sed -n '/^       --configure package\.\.\.|-a|--pending$/,/^           Configuring consists of the following steps:$/p'
========== 第7章: debconf-show は、そのパッケージの質問と答えを出し、もう出された質問に * を付ける（man debconf-show） ==========
$ man debconf-show | sed -n '/^DESCRIPTION$/,/^OPTIONS$/p'
========== 第7章: dpkg-reconfigure の -f（使う画面の種類）（man dpkg-reconfigure） ==========
$ man dpkg-reconfigure | sed -n '/^       -ftype, --frontend=type$/,/^       -pvalue, --priority=value$/p'
========== 第10章の表: apt-get clean と distclean（man apt-get） ==========
$ man apt-get | sed -n '/^       clean$/,/^       autoclean (and the auto-clean alias since 1.1)$/p'
$ man apt-get | sed -n '/^       distclean (and the dist-clean alias)$/,/^       autoremove (and the auto-remove alias since 1.1)$/p'
INPUT
