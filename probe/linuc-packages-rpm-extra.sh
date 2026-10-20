#!/bin/bash
# LinuC 主題1.04 RPM 系の檻: 課題文の「いまの状態」の画面を、読者と同じ打ち方で取る（2026-10-20 の作り直しから）。
# 演習ごとに檻を起動し直し、lab start NN のあとに、課題文の「いまの状態」に書いたコマンドを順に打つ。
# 記録 logs/linuc-packages-rpm-extra.log と課題文の突き合わせは probe/linuc-packages-taskcheck.py。
#   bash probe/linuc-packages-rpm-extra.sh（または bash probe/linuc-packages-run.sh extra）
cd "$(dirname "$0")/.." || exit 1
exec python3 -I probe/linuc-packages-seq.py --script /dev/stdin --cage rpm \
  --out logs/linuc-packages-rpm-extra.log \
  --note "課題文の「いまの状態」の画面（演習ごとに檻を起動し直し、lab start NN のあとに打った）" <<'INPUT'
========== 演習09 ==========
$ lab start 09
$ labapp
========== 演習10 ==========
$ lab start 10
$ labcalc 2 3
$ ls /srv/lab-tools-rpm
========== 演習11 ==========
$ lab start 11
$ labmotd
========== 演習12 ==========
$ lab start 12
$ cd ~/work/12
$ ls
$ labtool
INPUT
