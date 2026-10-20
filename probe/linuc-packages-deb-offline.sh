#!/bin/bash
# LinuC 主題1.04 Debian 系の檻: ネットにつながっていない読者の代わりに、名前を引けない檻で打つ（2026-10-20 の作り直しから）。
# 理論編の目次・第6章・実践編の「ネットが無いと違って出るのは、Ubuntu 本体に取りに行くところだけ」の裏づけ。
# 節（========== 題 ==========）ごとに檻を起動し直す。
#   bash probe/linuc-packages-deb-offline.sh（または bash probe/linuc-packages-run.sh offline）
cd "$(dirname "$0")/.." || exit 1
exec python3 -I probe/linuc-packages-seq.py --script /dev/stdin --cage deb --offline \
  --out logs/linuc-packages-deb-offline.log \
  --note "ネットにつながっていないときに、本文と違って出るところ（節ごとに檻を起動し直した）" <<'INPUT'
========== 第6章: apt update は、Ubuntu 本体の行が Ign と Err になって W: が出る。練習用のリポジトリから上げる結果は同じ ==========
$ sudo apt install labhello
$ echo 'deb [trusted=yes] file:/srv/lab-repo lab-updates main' | sudo tee /etc/apt/sources.list.d/lab-updates.list
$ sudo apt update
$ apt-cache policy labhello
$ sudo apt upgrade
Do you want to continue? [Y/n] y
$ labhello
========== 演習06: 足したリポジトリから入れる（ネットが無くても通る） ==========
$ echo 'deb [trusted=yes] file:/srv/lab-tools tools main' | sudo tee /etc/apt/sources.list.d/lab-tools.list
$ sudo apt update
$ sudo apt install lab-mathtools
$ lab check 06
INPUT
