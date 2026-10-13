#!/usr/bin/env bash
# 練習機のディスク（containers/linuc-machine/build/linuc-guest.qcow2）を作る。
#
# ホストで実行する:   bash containers/linuc-machine/guest/make-guest.sh
#   途中から再開:     RESUME=1 bash containers/linuc-machine/guest/make-guest.sh
# 中で lab-linuc-vmhost:1.0.0 を root で起動し、/dev/kvm があれば KVM で速く回す
# （読者の環境では KVM を使わない。ここは著者のビルドを速くするためだけ）。
#
# 入力は2つだけで、どちらも固定されている:
#   - Ubuntu 24.04 minimal クラウドイメージ release-20260905（SHA256 で照合。apt の固定時刻より前の版）
#   - apt の snapshot 20260929T000000Z（コンテナの檻と同じ時刻）
# 出力のビットはビルドごとに変わる（ssh のホスト鍵・machine-id・時刻）。読者に届くのは
# イメージのダイジェストで固定された1つなので、全員が同じ鍵・同じ machine-id を見る。
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
BUILD=$ROOT/build
mkdir -p "$BUILD"

# 外側の lab が練習機に入る鍵。ディスクと対で作る（ディスクを作り直すなら鍵も作り直す）。
if [ ! -f "$BUILD/lab_ed25519" ]; then
  ssh-keygen -q -t ed25519 -N '' -C lab@host -f "$BUILD/lab_ed25519"
fi

KVM=()
[ -r /dev/kvm ] && [ -w /dev/kvm ] && KVM=(--device /dev/kvm)
docker run --rm --user root "${KVM[@]}" -e RESUME="${RESUME:-0}" \
  -v "$BUILD":/build -v "$HERE":/guest:ro \
  --entrypoint bash lab-linuc-vmhost:1.0.0 /guest/inside-builder.sh 2>&1 | tee "$BUILD/make-guest.log"
