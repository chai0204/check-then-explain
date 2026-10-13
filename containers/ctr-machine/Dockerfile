# syntax=docker/dockerfile:1.9
# docker と podman の記事（slug docker / podman）が共有する、仮想マシン型の檻の土台。
#   練習機（Ubuntu 24.04）の中に docker.io 29.1.3・podman 4.9.3 と、小さなイメージ2つ（alpine:3.24.2・busybox:1.38.0。
#   ダイジェストで照合）を入れてある。コンテナの中で dockerd を動かすには特権が要るが、仮想マシンの中なら要らない。
#   名前空間・cgroup・デーモン・rootless を、読者の PC の権限を1つも借りずに本物のカーネルで確かめられる。
#
#   1) bash containers/ctr-machine/guest/make-ctr-guest.sh   （build/ に差分ディスクができる。KVM があれば約15分）
#   2) docker build -t lab-ctr-machine:1.0.0 containers/ctr-machine
#
# 記事の檻（containers/docker・containers/podman）はこれを FROM にして、演習（/lab）と初回の準備を足す。
FROM lab-linuc-machine:1.0.0
USER root

# 練習機のディスクの差分（docker・podman・イメージ）。参照先は土台の /var/lib/lab-vm/linuc-guest.qcow2。
# 足すのは差分だけなので、土台のディスク（約 550MB）をもう一度入れずに済む。
COPY --chown=root:root --chmod=0444 build/ctr-guest.qcow2 /var/lib/lab-vm/ctr-guest.qcow2
COPY --chown=root:root --chmod=0444 build/ctr-guest.sha256 /var/lib/lab-vm/ctr-guest.sha256
# 差分は、作ったときの土台のディスクのビットの上でしか正しくない（違う土台に重ねると、練習機から見えるディスクが壊れる）。
# 土台 lab-linuc-machine を作り直したのに差分を作り直していなければ、ここで止める。
COPY --chown=root:root --chmod=0444 build/ctr-guest.base.sha256 /var/lib/lab-vm/ctr-guest.base.sha256
RUN cmp -s /var/lib/lab-vm/linuc-guest.sha256 /var/lib/lab-vm/ctr-guest.base.sha256 \
 || { echo "土台 linuc-guest.qcow2 が、差分を作ったときと違う。bash containers/ctr-machine/guest/make-ctr-guest.sh で差分を作り直す" >&2; exit 1; }

# 読者の差分を、土台ではなく上の差分の上に載せ替える（vm が起動の前に呼ぶ。中の説明を参照）。
# /etc/lab-vm は土台の層で 0755 で作ってあるので、COPY --chmod でモードは変わらない。
COPY --chown=root:root --chmod=0644 host/pre-start.sh /etc/lab-vm/pre-start.sh

USER lab
