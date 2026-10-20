#!/bin/bash
# LinuC 主題1.04 Debian 系の檻: 課題文の「いまの状態」の画面を、読者と同じ打ち方で取る（2026-10-20 の作り直しから）。
# 演習ごとに檻を起動し直し、lab start NN のあとに、課題文の「いまの状態」に書いたコマンドを順に打つ。
# 記録 logs/linuc-packages-deb-extra.log と課題文の突き合わせは probe/linuc-packages-taskcheck.py。
#   bash probe/linuc-packages-deb-extra.sh（または bash probe/linuc-packages-run.sh extra）
cd "$(dirname "$0")/.." || exit 1
exec python3 -I probe/linuc-packages-seq.py --script /dev/stdin --cage deb \
  --out logs/linuc-packages-deb-extra.log \
  --note "課題文の「いまの状態」の画面（演習ごとに檻を起動し直し、lab start NN のあとに打った）" <<'INPUT'
========== 演習01 ==========
$ lab start 01
$ labhello
========== 演習02 ==========
$ lab start 02
$ apt list --installed 'lab*'
========== 演習03 ==========
$ lab start 03
$ labsvc
========== 演習04 ==========
$ lab start 04
$ labbackup
$ dpkg -l labbackup | tail -1
========== 演習05 ==========
$ lab start 05
$ apt list --installed 'labweb*'
========== 演習06 ==========
$ lab start 06
$ labcalc 2 3
$ find /srv/lab-tools -maxdepth 3
========== 演習07 ==========
$ lab start 07
$ cd ~/work/07
$ ls
$ labnote
$ dpkg -I labnote_1.0_all.deb
========== 演習08 ==========
$ lab start 08
$ cd ~/work/08
$ ls
$ cat labmine.sh
$ sh labmine.sh
INPUT
