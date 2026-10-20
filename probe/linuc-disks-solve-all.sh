#!/bin/bash
# LinuC 主題1.05 の全演習を、模範解答どおりに通す（あなたの PC＝ホストで走らせる）。目的は3つ。
#   1) 未達のとき判定が ✗ を出すこと（鳴らない検査は無いより悪い）。読者がやりがちな途中の状態でも ✗ になること
#   2) 模範解答どおりにやれば ✔ になること
#   3) 課題文（containers/linuc-disks/lab/tasks/NN.md）の「いまの状態」に載せる画面を、読者と同じ打ち方で取ること
#
# 走らせ方:
#   bash probe/linuc-disks-solve-all.sh [イメージ]        （既定 lab-linuc-disks:1.1.0）
#   → logs/linuc-disks-solve-all.log
#
# 1.0.x までは、檻の中で bash の関数（1行ごとに ssh … bash -lic）で流していた。それでは端末の表示が読者と
# 違いうる（課題文に画面を載せるようになったので、それが問題になった）。1.1.0 からは本文の記録と同じ道具
# probe/linuc-disks-seq.py の --steps で、読者と同じ起動・同じ打ち方（疑似端末 80 桁 × 24 行・対話シェルに1行ずつ）
# で打つ。台本は probe/linuc-disks-solve-all.txt。新しいボリュームで、練習機は工場出荷時の状態から始める。
set -euo pipefail
cd "$(dirname "$0")/.."
IMG=${1:-lab-linuc-disks:1.1.0}
exec python3 -I probe/linuc-disks-seq.py --steps probe/linuc-disks-solve-all.txt \
  --image "$IMG" --name linuc-disks-r11-solve --out logs/linuc-disks-solve-all.log
