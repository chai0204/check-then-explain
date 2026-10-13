#!/bin/bash
# KVM の記事: 檻を podman（rootless）で起動したとき、/dev/kvm がどう渡るかの記録（実践編の podman の注意の出どころ）。
#   bash probe/kvm-podman.sh >> logs/kvm-podman.log
# 著者の PC（/dev/kvm は 0666・podman 5.8.6、ランタイムは crun）と、lab の仮想マシンの Ubuntu 24.04（/dev/kvm は 0660・
# podman 4.9.3。apt で crun を入れ、runc も入っている）で走らせた。Ubuntu では、利用者が kvm グループに入っていないときと、
# 入れた後（sudo usermod -aG kvm）の2回。
# 端末の要らない確かめだけなので、docker run -it の代わりに、檻のシェルに1行のコマンドを渡す（bash -c）。
#
# 分かったこと:
#   - rootless の podman では、--group-add の番号は檻の中の番号になり、PC の kvm グループにはならない
#     （檻の中の /dev/kvm は nobody nogroup に見える）。0660 の /dev/kvm は開けない
#   - --group-add keep-groups は、利用者の PC の補助グループを檻の中へ持ち込む。OCI ランタイムが crun のときだけ効く
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
IMG=docker.io/library/lab-kvm:1.0.0
CHK='id; ls -l /dev/kvm; grep -E "^(Groups|CapEff|CapBnd)" /proc/self/status; ( exec 3<>/dev/kvm ) && echo "/dev/kvm を読み書きで開けた"'
printf '\n========== %s ==========\n' "podman（rootless）$(podman --version | cut -d' ' -f3)・$(. /etc/os-release; echo "$PRETTY_NAME")・/dev/kvm $(stat -c '%A %U:%G' /dev/kvm)"
R 'ls -l /dev/kvm'
R 'id -nG | grep -o -w kvm'
R "podman info --format '{{.Host.OCIRuntime.Name}}'"
R "podman run --rm --device /dev/kvm --group-add \"\$(stat -c %g /dev/kvm)\" --entrypoint bash $IMG -c '$CHK'"
# keep-groups: まず podman の既定のランタイムで。runc が入っていれば、runc でも（keep-groups は crun のときだけ効く）
R "podman run --rm --device /dev/kvm --group-add keep-groups --entrypoint bash $IMG -c '$CHK'"
if command -v runc >/dev/null; then
  R "podman run --rm --runtime runc --device /dev/kvm --group-add keep-groups --entrypoint bash $IMG -c '$CHK'"
fi
