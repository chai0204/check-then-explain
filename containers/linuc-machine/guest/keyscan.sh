#!/usr/bin/env bash
# make-guest.sh の後に1回走らせる: bash containers/linuc-machine/guest/keyscan.sh
# 出来上がった練習機を使い捨ての差分で起動し、ホスト鍵（build/known_hosts）を取り、起動の健全性を記録する。
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
BUILD=$(cd "$HERE/.." && pwd)/build
KVM=()
[ -r /dev/kvm ] && [ -w /dev/kvm ] && KVM=(--device /dev/kvm)
docker run --rm --user root "${KVM[@]}" \
  -v "$BUILD":/build -v "$HERE":/guest:ro \
  --entrypoint bash lab-linuc-vmhost:1.0.0 /guest/inside-keyscan.sh 2>&1 | tee "$BUILD/keyscan.log"
