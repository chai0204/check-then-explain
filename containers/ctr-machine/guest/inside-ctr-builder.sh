#!/usr/bin/env bash
# make-ctr-guest.sh から、lab-linuc-machine:1.0.0 の中で root として呼ばれる。
#
# 土台のディスク（このイメージの /var/lib/lab-vm/linuc-guest.qcow2）の上に作業用の差分を作って練習機を起動し、
# 中で ctr-customize.sh（パッケージとイメージ）を走らせ、片付けて止め、差分だけを圧縮して書き出す。
# 書き出す差分の参照先（backing file）は、イメージの中の土台のパスそのもの（/var/lib/lab-vm/linuc-guest.qcow2）にする。
#
# 取得した .deb は build/cache/debs/ に回収し、次のビルドで練習機の apt のキャッシュへ戻す
# （snapshot.ubuntu.com は 1 ファイル約 1.5〜2 秒かかる。土台のビルドと同じ手当て）。
set -euo pipefail
B=/build
G=/guest
BASE=/var/lib/lab-vm/linuc-guest.qcow2

echo "== 1. 土台のディスクを照合する"
( cd /var/lib/lab-vm && sed "s|/build/linuc-guest.qcow2|$BASE|" linuc-guest.sha256 | sha256sum -c )
# 差分は、この土台のビットの上でしか正しくない。どの土台の上で作ったかを残し、イメージを作るときに照らす（Dockerfile）
cp /var/lib/lab-vm/linuc-guest.sha256 $B/ctr-guest.base.sha256

echo "== 2. 作業用の差分（土台は書き換えない）"
mkdir -p $B/cache/debs $B/work
rm -f $B/work/ctr.qcow2
qemu-img create -q -f qcow2 -F qcow2 -b $BASE $B/work/ctr.qcow2 20G
cp /usr/share/OVMF/OVMF_VARS_4M.fd $B/work/vars.fd

ACCEL=tcg; [ -w /dev/kvm ] && ACCEL=kvm
echo "== 3. 起動（accel=$ACCEL）"
# NIC は実行時の定義（domain.xml.in）と同じ MAC・同じ PCI 位置にする（netplan は enp0s16 という名前で設定している）
qemu-system-x86_64 -machine q35 -accel $ACCEL -cpu max -smp 4 -m 3072 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
  -drive if=pflash,format=raw,file=$B/work/vars.fd \
  -drive file=$B/work/ctr.qcow2,if=virtio,discard=unmap \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-net-pci,netdev=n0,mac=52:54:00:12:34:56,addr=0x10 \
  -device virtio-rng-pci \
  -display none -serial file:$B/work/serial.log -daemonize -pidfile $B/work/qemu.pid
pid=$(cat $B/work/qemu.pid)
cleanup() { kill "$pid" 2>/dev/null || true; }
trap cleanup EXIT

SSH=(ssh -q -i /key/id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 -p 2222 student@127.0.0.1)
for i in $(seq 1 300); do "${SSH[@]}" true 2>/dev/null && break; sleep 1; done
"${SSH[@]}" true || { echo "ssh に届かない"; tail -40 $B/work/serial.log; exit 1; }
echo "ssh ready after ${i}s"

n=$(find $B/cache/debs -name '*.deb' | wc -l)
if [ "$n" -gt 0 ]; then
  echo "== 3b. 前回取得した .deb（$n 個）を練習機の apt のキャッシュへ戻す"
  tar -C $B/cache/debs -cf - . | "${SSH[@]}" 'sudo tar -C /var/cache/apt/archives -xf -'
fi

echo "== 4. 練習機の中で ctr-customize.sh を実行（root）"
tar -C $G -cf - ctr-customize.sh ctr-images.sh ctr-finalize.sh | "${SSH[@]}" 'mkdir -p /tmp/ctr-build && tar -C /tmp/ctr-build -xf -'
"${SSH[@]}" "sudo bash /tmp/ctr-build/ctr-customize.sh" > $B/work/customize.log 2>&1 || true
sed 's/^/  | /' $B/work/customize.log
grep -q '^CTR_CUSTOMIZE_OK$' $B/work/customize.log || { echo "✗ ctr-customize.sh が最後まで走らなかった"; exit 1; }

echo "== 4b. student のイメージ置き場（rootless の podman）に読み込む（student として。sudo を通さない）"
# rootless の podman は、呼んだユーザのログインのセッション（/run/user/1000 と user の systemd）を使う。
# root から runuser で呼ぶとセッションが無く、警告が出て cgroup の扱いが変わるので、student の ssh で直接打つ。
"${SSH[@]}" "bash /tmp/ctr-build/ctr-images.sh podman" > $B/work/images-student.log 2>&1 || true
sed 's/^/  | /' $B/work/images-student.log
grep -q '^CTR_IMAGES_OK$' $B/work/images-student.log || { echo "✗ student の podman にイメージを読み込めなかった"; exit 1; }

echo "== 4c. 取得した .deb を回収（次のビルドで再利用する）"
"${SSH[@]}" "sudo sh -c 'cd /var/cache/apt/archives && tar -cf - *.deb'" | tar -C $B/cache/debs -xf -
echo "  回収: $(find $B/cache/debs -name '*.deb' | wc -l) 個 / $(du -sh $B/cache/debs | cut -f1)"

echo "== 5. 片付けて停止（ctr-finalize.sh）"
"${SSH[@]}" 'sudo bash /tmp/ctr-build/ctr-finalize.sh' > $B/work/finalize.log 2>&1 || true
tail -5 $B/work/finalize.log | sed 's/^/  | /'
for i in $(seq 1 120); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
kill -0 "$pid" 2>/dev/null && { echo "止まらない"; exit 1; }
trap - EXIT

echo "== 6. 差分だけを圧縮して書き出す（参照先はイメージの中の土台のパス）"
# -B: 出力を「土台の上の差分」として作る。入力のうち土台と同じ部分は書かない（差分の大きさで済む）
rm -f $B/ctr-guest.qcow2
qemu-img convert -O qcow2 -c -B $BASE -F qcow2 $B/work/ctr.qcow2 $B/ctr-guest.qcow2
qemu-img info $B/ctr-guest.qcow2 | grep -E 'virtual size|disk size|backing file'
qemu-img compare -q $B/work/ctr.qcow2 $B/ctr-guest.qcow2 && echo "  作業用の差分と書き出した差分は、ゲストから見て同じ中身"
sha256sum $B/ctr-guest.qcow2 | tee $B/ctr-guest.sha256
ls -l $B/ctr-guest.qcow2
chown -R 1000:1000 $B
