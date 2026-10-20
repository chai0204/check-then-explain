# syntax=docker/dockerfile:1.9
# LinuC 主題1.05（ハードウェア・ディスク・パーティション・ファイルシステム）の檻。
# 仮想マシン型（lab-linuc-machine）の練習機に、分割・フォーマット・マウントしてよいディスクを足す。
#   virtio のディスク4本（vdb 2G / vdc 1G / vdd 256M / vde 512M）、SATA の SSD 1本（sda 1G）、光学ドライブ（sr0）、
#   USB の口（USB メモリは起動後に virsh attach-device で挿す）。定義は vm/domain.xml.in。
# 本物のカーネルの上で fdisk / gdisk / parted / LVM / mkfs / mount を打つので、読者に権限を1つも渡さずに済む。
#   build: docker build --build-context labcmd=containers/base --build-context labvm=containers/linuc-machine/host -t lab-linuc-disks:1.1.0 containers/linuc-disks

# ---- 光学ドライブに入れる CD のイメージ ----------------------------------------
#   作る道具（xorriso）は最終イメージに入れない。この段で作って、ISO だけを下の段へ渡す。
#   日付を固定して、作り直しても ISO の UUID（iso9660 では作成日時から決まる）が変わらないようにする。
FROM lab-linuc-base:1.0.0 AS media
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends xorriso \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin /var/cache/apt/archives/*.deb
COPY media/ /media-src/
RUN touch -d '2026-10-13 00:00:00 UTC' /media-src /media-src/* \
 && xorriso -as mkisofs -quiet -r -J -V LINUC_MEDIA \
      --modification-date=2026101300000000 \
      -o /linuc-media.iso /media-src

# ---- 檻 ------------------------------------------------------------------------
FROM lab-linuc-machine:1.0.0
USER root
# COPY --chmod は、まだ無い親ディレクトリも同じモードで作る（0444 なら x の無いディレクトリになり、
# QEMU を動かす lab が ISO を開けない）。土台の最初の版がこれで練習機を定義できなかった（2026-10-13）。
# この層が新しく使う置き場所は、COPY の前に 0755 で作っておく。
RUN install -d -m 0755 /usr/share/lab-disks
COPY --chown=root:root --chmod=0555 lab/ /lab/
# 練習機のハードウェア（ディスク・光学ドライブ・USB の口を足したもの）
COPY --chown=root:root --chmod=0644 vm/domain.xml.in /etc/lab-vm/domain.xml.in
# 起動前に外側で追加ディスクと USB メモリの定義を作る
COPY --chown=root:root --chmod=0644 vm/pre-start.sh  /etc/lab-vm/pre-start.sh
# 初回の起動で1回だけ練習機の中で走る（演習02 のディスクと、演習05 のイメージのファイルを用意する）
COPY --chown=root:root --chmod=0644 vm/provision.sh  /etc/lab-vm/provision.sh
COPY --from=media --chown=root:root --chmod=0444 /linuc-media.iso /usr/share/lab-disks/linuc-media.iso
LABEL org.opencontainers.image.source=https://github.com/chai0204/check-then-explain
LABEL org.opencontainers.image.description="LinuC 主題1.05（ハードウェア・ディスク・パーティション・ファイルシステム）を仮想マシンで確かめる学習用コンテナ"
LABEL org.opencontainers.image.licenses=MIT
# ---- lab コマンドを最新にする（次の版、2026-10-20）--------------------
#   lab の正本は containers/base/bin/lab。土台（lab-base）から作り直すと上の層が全部作り直しになり、
#   本文の記録とずれうるので、最新の lab をここで重ねる。これより前の層は 1.0.1 とキャッシュで同一。
#   build: docker build --build-context labcmd=containers/base --build-context labvm=containers/linuc-machine/host -t lab-linuc-disks:<版> containers/linuc-disks
COPY --from=labcmd --chown=root:root --chmod=0755 bin/lab /usr/local/bin/lab
#   練習機の中の lab が外の lab に頼む中継（lab-remote）も最新にする（lab show を通すため）。
#   build には --build-context labvm=containers/linuc-machine/host も付ける。
COPY --from=labvm --chown=root:root --chmod=0755 libexec/lab-remote /usr/local/libexec/lab-remote
ENV LAB_THEME=linuc-disks LAB_VERSION=1.1.0 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/chai0204/lab-linuc:disks-1.1.0 LAB_VM_AUTOSTART=1
ENV LAB_RESET_HINT="元に戻すには、練習機の外で vm reset --yes（練習機ごと最初の状態に戻ります）"
USER lab
