#!/bin/bash
# 演習05 で配るスクリプト。点検結果のうち OK は標準出力へ、NG は標準エラー出力へ出す。
echo "OK: disk"
echo "NG: memory" >&2
echo "OK: network"
echo "NG: cpu" >&2
echo "OK: clock"
