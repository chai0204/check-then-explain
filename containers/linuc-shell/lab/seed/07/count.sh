#!/bin/bash
# logs/ にある .log ファイルごとに行数を数え、最後に合計を出す。
total=0
for f in logs/*.log; do
    n=0
    cat "$f" | while read -r line; do
        n=$((n + 1))
    done
    echo "$f: $n 行"
    total=$((total + n))
done
echo "合計: $total 行"
