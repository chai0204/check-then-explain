#!/usr/bin/env bash
# make-guest.sh から、lab-linuc-vmhost の中で root として呼ばれる。
#
#   RESUME=1 … 前回の作業用ディスク（build/work/guest.qcow2）から再開する。customize.sh の 1〜2
#              （apt の固定と全パッケージの入れ直し。snapshot からの取得で 30 分以上かかる）を飛ばす。
#
# 取得した .deb は build/cache/debs/ に回収し、次のビルドで練習機の apt のキャッシュへ戻す。
# snapshot サーバは 1 ファイル約 1.5〜2 秒かかる（実測 2026-10-13）ので、作り直しのたびに取り直さないため。
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
B=/build
G=/guest
RESUME=${RESUME:-0}
IMG_URL=https://cloud-images.ubuntu.com/minimal/releases/noble/release-20260905/ubuntu-24.04-minimal-cloudimg-amd64.img
IMG_SHA=46b0dbaffa6950a7da5ff2dc5ed34c46084610b3b6d1fae8f1ec2d7e953984a3

echo "== 0. ビルド用の道具（cloud-localds）をこの使い捨てコンテナにだけ入れる"
apt-get update -qq && apt-get install -y -qq --no-install-recommends cloud-image-utils >/dev/null

echo "== 1. 公式クラウドイメージ（release-20260905）"
# apt の固定時刻（20260929）より**前**の版を土台にする。後の版（20261008）を使うと、入っているパッケージが
# snapshot より新しくなり、apt で足すときに依存の版が合わずに落ちうる。前の版なら full-upgrade で
# snapshot の時刻にそろい、コンテナの檻と全く同じ版になる。
mkdir -p $B/cache/debs $B/work
if [ ! -f $B/cache/noble-minimal.img ] || ! echo "$IMG_SHA  $B/cache/noble-minimal.img" | sha256sum -c --quiet; then
  curl -sSL -o $B/cache/noble-minimal.img "$IMG_URL"
fi
echo "$IMG_SHA  $B/cache/noble-minimal.img" | sha256sum -c

if [ "$RESUME" = 1 ] && [ -f $B/work/guest.qcow2 ] && [ -f $B/work/seed.img ] && [ -f $B/work/vars.fd ]; then
  echo "== 2. 再開: 前回の作業用ディスクをそのまま使う"
  START=3
else
  RESUME=0; START=1
  echo "== 2. 初回起動用の cloud-init（ユーザ student と鍵だけ。残りは customize.sh で行う）"
  cat > $B/work/user-data <<EOF
#cloud-config
users:
  - name: student
    gecos: LinuC student
    shell: /bin/bash
    groups: [adm, sudo]
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys: [ "$(cat $B/lab_ed25519.pub)" ]
ssh_pwauth: false
EOF
  printf 'instance-id: linuc-build\nlocal-hostname: linuc\n' > $B/work/meta-data
  cloud-localds $B/work/seed.img $B/work/user-data $B/work/meta-data
  rm -f $B/work/guest.qcow2
  qemu-img create -q -f qcow2 -F qcow2 -b $B/cache/noble-minimal.img $B/work/guest.qcow2 20G
  cp /usr/share/OVMF/OVMF_VARS_4M.fd $B/work/vars.fd
fi

ACCEL=tcg; [ -w /dev/kvm ] && ACCEL=kvm
echo "== 3. 起動（accel=$ACCEL）"
# NIC は実行時の定義（domain.xml.in）と同じ MAC・同じ PCI 位置にする。
# netplan はインターフェース名で設定するので、名前（enp0s16）が変わると実行時にネットワークが上がらない。
qemu-system-x86_64 -machine q35 -accel $ACCEL -cpu max -smp 4 -m 3072 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
  -drive if=pflash,format=raw,file=$B/work/vars.fd \
  -drive file=$B/work/guest.qcow2,if=virtio,discard=unmap \
  -drive file=$B/work/seed.img,if=virtio,format=raw \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-net-pci,netdev=n0,mac=52:54:00:12:34:56,addr=0x10 \
  -device virtio-rng-pci \
  -display none -serial file:$B/work/serial.log -daemonize -pidfile $B/work/qemu.pid
pid=$(cat $B/work/qemu.pid)
cleanup() { kill "$pid" 2>/dev/null || true; }
trap cleanup EXIT

SSH=(ssh -q -i $B/lab_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 -p 2222 student@127.0.0.1)
for i in $(seq 1 300); do "${SSH[@]}" true 2>/dev/null && break; sleep 1; done
"${SSH[@]}" true || { echo "ssh に届かない"; tail -40 $B/work/serial.log; exit 1; }
echo "ssh ready after ${i}s"

n=$(find $B/cache/debs -name '*.deb' | wc -l)
if [ "$n" -gt 0 ]; then
  echo "== 3b. 前回取得した .deb（$n 個）を練習機の apt のキャッシュへ戻す"
  tar -C $B/cache/debs -cf - . | "${SSH[@]}" 'sudo tar -C /var/cache/apt/archives -xf -'
fi

echo "== 4. 練習機の中で customize.sh を実行（START=$START）"
tar -C $G -cf - customize.sh finalize.sh files | "${SSH[@]}" 'mkdir -p /tmp/lab-build && tar -C /tmp/lab-build -xf -'
"${SSH[@]}" "sudo START=$START bash /tmp/lab-build/customize.sh" > $B/work/customize.log 2>&1 || true
sed 's/^/  | /' $B/work/customize.log
grep -q '^CUSTOMIZE_OK$' $B/work/customize.log || { echo "✗ customize.sh が最後まで走らなかった"; exit 1; }

echo "== 4b. 取得した .deb を回収（次のビルドで再利用する）"
"${SSH[@]}" 'sudo tar -C /var/cache/apt/archives -cf - --wildcards "*.deb"' | tar -C $B/cache/debs -xf -
echo "  回収: $(find $B/cache/debs -name '*.deb' | wc -l) 個 / $(du -sh $B/cache/debs | cut -f1)"

echo "== 5. 片付けて停止（finalize.sh）"
"${SSH[@]}" 'sudo bash /tmp/lab-build/finalize.sh' 2>&1 | tail -3 | sed 's/^/  | /' || true
for i in $(seq 1 120); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
kill -0 "$pid" 2>/dev/null && { echo "止まらない"; exit 1; }
trap - EXIT

echo "== 6. 差分を1つのファイルにまとめて圧縮（土台のクラウドイメージを含めた単独のディスクにする）"
rm -f $B/linuc-guest.qcow2
qemu-img convert -O qcow2 -c $B/work/guest.qcow2 $B/linuc-guest.qcow2
qemu-img info $B/linuc-guest.qcow2 | grep -E 'virtual size|disk size|backing'
sha256sum $B/linuc-guest.qcow2 | tee $B/linuc-guest.sha256
ls -l $B/linuc-guest.qcow2
chown -R 1000:1000 $B
