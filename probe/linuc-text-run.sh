#!/bin/bash
# LinuC 主題1.03 の記録を取り直し、理論編の章を作り直す。
#
#   bash probe/linuc-text-run.sh            probe（章ごと）と solve-all の両方を取り直し、章を作り直す
#   bash probe/linuc-text-run.sh probe      probe だけ
#   bash probe/linuc-text-run.sh solve      solve-all だけ
#   bash probe/linuc-text-run.sh extra      追加の記録（probe/linuc-text-probe-extra.sh。事実確認で直した箇所の裏付け）だけ
#
# どちらも読者と同じ起動オプション（--hostname linuc と2つのボリューム）で起動したコンテナの中で走らせる。
# ボリュームは名前を付けず、終わったら docker rm -v で消す（名前付きボリュームを残さないため）。
# probe は章ごとに新しいコンテナで走らせる。前の章で作ったファイルや変数が、次の章の出力を変えないように。
set -u
cd "$(dirname "$0")/.." || exit 1
IMG=lab-linuc-text:1.0.1
what=${1:-all}

run_probe() {
  local out=logs/linuc-text-probe.log ch name
  : > "$out"
  for ch in 0 1 2 3 4 5 6 7 8 9 10; do
    name=linuc-text-probe-$ch
    docker rm -f -v "$name" >/dev/null 2>&1
    docker run -d --name "$name" --hostname linuc -v /home/lab/work -v /home/lab/.lab "$IMG" sleep infinity >/dev/null
    docker cp probe/linuc-text-probe.sh "$name":/tmp/probe.sh
    # 対話シェル（bash -i）を端末なしで起動すると、起動時に2行の警告が標準エラー出力に出る。記録には入れない。
    docker exec -u lab -w /home/lab "$name" bash -l -i /tmp/probe.sh "$ch" >> "$out" 2>/dev/null
    docker rm -f -v "$name" >/dev/null
  done
  echo "probe: $(grep -c '^\$ ' "$out") コマンドを記録 → $out"
}

run_extra() {
  local out=logs/linuc-text-probe-extra.log ch name
  : > "$out"
  for ch in 3 6 8 10; do
    name=linuc-text-extra-$ch
    docker rm -f -v "$name" >/dev/null 2>&1
    docker run -d --name "$name" --hostname linuc -v /home/lab/work -v /home/lab/.lab "$IMG" sleep infinity >/dev/null
    docker cp probe/linuc-text-probe-extra.sh "$name":/tmp/probe-extra.sh
    docker exec -u lab -w /home/lab "$name" bash -l -i /tmp/probe-extra.sh "$ch" >> "$out" 2>/dev/null
    docker rm -f -v "$name" >/dev/null
  done
  echo "extra: $(grep -c '^\$ ' "$out") コマンドを記録 → $out"
}

run_solve() {
  local out=logs/linuc-text-solve-all.log name=linuc-text-solve
  docker rm -f -v "$name" >/dev/null 2>&1
  docker run -d --name "$name" --hostname linuc -v /home/lab/work -v /home/lab/.lab "$IMG" sleep infinity >/dev/null
  docker cp probe/linuc-text-solve-all.sh "$name":/tmp/solve.sh
  docker exec -u lab -w /home/lab "$name" bash -l -i /tmp/solve.sh > "$out" 2>/dev/null
  docker rm -f -v "$name" >/dev/null
  echo "solve-all: ✔ $(grep -c '^✔ 0' "$out") / ✗ $(grep -c '^✗ 0' "$out") → $out"
}

case $what in
  probe) run_probe ;;
  solve) run_solve ;;
  extra) run_extra ;;
  all)   run_probe; run_extra; run_solve ;;
  *) echo "使い方: bash probe/linuc-text-run.sh [all|probe|extra|solve]"; exit 2 ;;
esac
python3 -I probe/linuc-text-gen.py probe/linuc-text-tpl/*.tpl > /dev/null && echo "章を作り直した"
node tools/logcheck.mjs linuc-text --strict
