#!/bin/bash
# LinuC 主題1.03: 通しの記録を取り直し、本文と突き合わせる。
#   bash probe/linuc-text-seq.sh   → logs/linuc-text-seq.log（端末 80 桁）と logs/linuc-text-seq-wide.log（200 桁）
#
# 本文の記録（probe）は章ごとに新しいコンテナで取る。読者は docker run -it の PID 1 の bash -l のまま章をまたぐので、
# 本文の端末ブロックから機械的に作った入力（$ 行・> の続き・vim / nano の打鍵・問いへの答え）を、読者と同じ起動の
# 1つのシェルに第1章から第10章まで通して打ち、本文の「コマンド＋直後の出力」の組と順に突き合わせる。
#   入力を作って打つ: probe/linuc-text-seq.py   突き合わせ: probe/linuc-text-seqcompare.py
# 以前は第4〜8章の後の第9章 grep -rl だけを残していた（第6章の my.conf などで3行増える）。
# 第6章・第7章の終わりに後片付けの行を足して直したので、通し全体を取る形に置き換えた（2026-10-13）。
exec bash "$(dirname "$0")/linuc-text-run.sh" seq
