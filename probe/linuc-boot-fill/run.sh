#!/bin/bash
# linuc-boot の章の端末ブロックを、記録（logs/linuc-boot-*.log）から作り直す。
#   probe（と比べるための probe/linuc-boot-rhel-compare.sh）を取り直したら、これを走らせてから
#   node tools/logcheck.mjs linuc-boot --strict で照合する。本文の文章（地の文）は fill*.py の中にある。
set -e
export PYTHONDONTWRITEBYTECODE=1   # probe/ に __pycache__ を作らない
cd "$(dirname "$0")"
for f in fill01 fill02 fill05 fill06 fill07 fill08 fill09 fill10 fill_index; do python3 "$f.py"; done
python3 ../linuc-boot-sync.py --write
