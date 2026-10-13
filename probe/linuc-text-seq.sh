#!/bin/bash
# LinuC 主題1.03: 章を順に同じ起動のまま打ったときに、本文と画面が変わる箇所の記録。
#   bash probe/linuc-text-seq.sh   → logs/linuc-text-seq.log
# 本文の記録（probe）は章ごとに新しいコンテナで取る。読者は同じ起動のまま第4章から順に打つことが多いので、
# 第4〜8章を打ってから第9章を打ち、第9章の grep -rl 8080 の出力を残す（第6章の my.conf などが増える）。
set -u
cd "$(dirname "$0")/.." || exit 1
IMG=lab-linuc-text:1.0.1
name=linuc-text-seq
out=logs/linuc-text-seq.log
docker rm -f -v "$name" >/dev/null 2>&1
docker run -d --name "$name" --hostname linuc -v /home/lab/work -v /home/lab/.lab "$IMG" sleep infinity >/dev/null
docker cp probe/linuc-text-probe.sh "$name":/tmp/probe.sh
for ch in 4 5 6 7 8; do docker exec -u lab -w /home/lab "$name" bash -l -i /tmp/probe.sh "$ch" >/dev/null 2>&1; done
{
  printf '========== 第4〜8章を同じ起動のまま打った後の第9章 ==========\n'
  docker exec -u lab -w /home/lab "$name" bash -l -i /tmp/probe.sh 9 2>/dev/null | grep -A8 -F '$ grep -rl 8080 . | sort' | sed '/^$/q'
} > "$out"
docker rm -f -v "$name" >/dev/null
echo "→ $out"
