#!/usr/bin/env bash
# docker と podman の記事（slug docker / podman）が共有する練習機のディスクを作る。
#
#   bash containers/ctr-machine/guest/make-ctr-guest.sh
#   → containers/ctr-machine/build/ctr-guest.qcow2（土台の上の差分）と ctr-guest.sha256
#   続けて: docker build -t lab-ctr-machine:1.0.0 containers/ctr-machine
#
# 土台は lab-linuc-machine:1.0.0 の練習機のディスク（/var/lib/lab-vm/linuc-guest.qcow2）。それを書き換えず、
# 上に重ねた差分の中で docker.io・podman を入れ、小さなイメージ2つ（alpine・busybox。ダイジェストで照合）を読み込む。
# 出来上がるのは「土台との差分」だけなので、イメージに足す大きさは入れたものの分で済む。
#
# なぜビルドの時に入れるのか: 読者の起動時に入れると、KVM の無い完全エミュレーション（TCG）では数分かかり、
# 取得先（apt の snapshot と Docker Hub）にもつながっていなければならない。ここで入れておけば、読者は何も取りに行かない。
#
# 中では lab-linuc-machine:1.0.0 を root で起動し、/dev/kvm があれば KVM で速く回す（著者のビルドを速くするためだけ。
# 読者は KVM を使わない）。練習機に入る鍵は土台のビルドの鍵（containers/linuc-machine/build/lab_ed25519）を
# 読み取り専用で借りる（土台のディスクの student はこの鍵で入れる）。鍵の中身は出力しない。
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
BUILD=$ROOT/build
KEY=$(cd "$ROOT/../linuc-machine/build" && pwd)/lab_ed25519
[ -f "$KEY" ] || { echo "土台の鍵がありません: $KEY（containers/linuc-machine/guest/make-guest.sh で作る）" >&2; exit 1; }
mkdir -p "$BUILD"

KVM=()
[ -r /dev/kvm ] && [ -w /dev/kvm ] && KVM=(--device /dev/kvm)
docker rm -f docker-ctr-build >/dev/null 2>&1 || true
docker run --rm --name docker-ctr-build --user root "${KVM[@]}" \
  -v "$BUILD":/build -v "$HERE":/guest:ro -v "$KEY":/key/id:ro \
  --entrypoint bash lab-linuc-machine:1.0.0 /guest/inside-ctr-builder.sh 2>&1 | tee "$BUILD/make-ctr-guest.log"
