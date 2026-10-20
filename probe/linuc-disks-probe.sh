#!/bin/bash
# LinuC 主題1.05: 本文の章以外の表示（実践編の入口・lab env・課題文の出し方）と、検証環境ブロックの版を記録する
# （あなたの PC＝ホストで走らせる）。
#
#   bash probe/linuc-disks-probe.sh [イメージ]       （既定 lab-linuc-disks:1.1.0）
#   → logs/linuc-disks-probe.log
#
# 1.0.x までは、この台本が理論編の全章の記録の出どころだった（檻の中で、1行ごとに ssh … bash -lic で流していた）。
# 1.1.0 で章立てを「順を追う」形に作り直したとき、章の記録は読者と同じ打ち方の通しの記録
# （probe/linuc-disks-seq.py → logs/linuc-disks-seq.log）に移した。ここに残すのは、章の外の表示だけである。
# 台本は probe/linuc-disks-probe.txt。書式は probe/linuc-disks-seq.py の steps_from_file を見る。
set -euo pipefail
cd "$(dirname "$0")/.."
IMG=${1:-lab-linuc-disks:1.1.0}
exec python3 -I probe/linuc-disks-seq.py --steps probe/linuc-disks-probe.txt \
  --image "$IMG" --name linuc-disks-r11-probe --out logs/linuc-disks-probe.log
