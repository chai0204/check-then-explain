#!/usr/bin/env bash
# 練習機（ゲスト）の中で root として1回だけ走る（inside-ctr-builder.sh から）。
# ここで入れたものが、docker と podman の記事の練習機の初期状態になる。
#
#   - docker.io（dockerd・containerd・runc）と docker-buildx（docker build の BuildKit）
#   - podman（conmon・crun・netavark・aardvark-dns）と rootless に要るもの（uidmap・slirp4netns・passt・catatonit）
#   - 読者 student を docker グループに入れる（docker の記事の第7章で、それが何を渡しているかを確かめる）
#   - root の docker に、小さなイメージ2つ（alpine・busybox）を読み込み、ダイジェストを照合する
#
# apt はこの練習機の固定（snapshot 20260929T000000Z）をそのまま使う。版はすべてその時刻のもの。
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
#   docker.io と podman を同じ練習機に入れる。podman-docker（docker という名前で podman を呼ぶ）は docker.io と
#   Conflicts なので入れない。crun は podman の既定の OCI ランタイム（docker は runc を使う。2つを比べられる）。
#   passt は podman 5 の rootless の既定の網（pasta）。この podman 4.9 の既定は slirp4netns で、pasta は選べば使える。
apt-get install -y --no-install-recommends -o Dpkg::Options::=--force-confold \
  docker.io docker-buildx podman crun catatonit uidmap slirp4netns passt netavark aardvark-dns dbus-user-session

systemctl is-active docker.service containerd.service
docker version --format 'docker {{.Server.Version}}'
podman --version

#   docker の CLI は、root の dockerd に /run/docker.sock で頼む。このソケットは root:docker の 660 なので、
#   docker グループに入っていれば sudo なしで頼める（＝ root の dockerd に何でも頼める。第7章）
usermod -aG docker student

#   root の docker のイメージ置き場（containerd）に読み込む
bash /tmp/ctr-build/ctr-images.sh docker

#   ログイン時の案内（土台は「LinuC 練習機」）。丸ごと書く（追記しない。土台と同じ理由）
cat > /etc/motd <<'EOF'

  練習機（Ubuntu 24.04 / 仮想マシン）— Docker と Podman の記事
  - 採点は外のコンテナが持っています。この中でも lab check NN で答え合わせできます
  - 管理用の NIC（enp0s16）を止めると ssh が切れます。そのときは外で vm console

EOF

#   判定（lab check）の通り道の qemu-guest-agent を、ターゲットの切り替えで止めない（土台の既知の不具合の手当て）。
#   qemu-guest-agent は udev が起動するだけでどのターゲットにも属さないので、systemctl isolate で止められる。
systemctl add-wants multi-user.target qemu-guest-agent.service

mandb -q
echo CTR_CUSTOMIZE_OK
