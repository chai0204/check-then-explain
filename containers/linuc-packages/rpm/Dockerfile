# syntax=docker/dockerfile:1.9
# LinuC 主題1.04（リポジトリとパッケージ管理）の RPM 系の檻。
# yum（実体は dnf）/ yumdownloader / rpm を、AlmaLinux 9.7 の上で確かめる。
# AlmaLinux のリポジトリは vault.almalinux.org の 9.7（9.8 が出て凍結済み）に固定し、目録もイメージに入れてある。
# 演習の対象は自作の署名つき RPM で、檻の中の file:// リポジトリから入れる。ネットが無くても結果は同じ。
#   build: docker build -t lab-linuc-packages-rpm:1.1.0 -f containers/linuc-packages/rpm/Dockerfile containers
#   （ビルドコンテキストを containers/ にするのは、base/bin/lab をそのまま取り込むため）

# ---- build ステージ: 自作 RPM を作って署名し、リポジトリにする ----------------
FROM almalinux:9.7@sha256:2d57aea965da8fbda97736ec5125c1b683ce271438038ea1906b2391e89b77d2 AS build
# リポジトリの向き先を、日々変わるミラーから vault の 9.7 に変える。
#   mirrorlist= を止め、コメントで置かれている baseurl= を vault の 9.7 にして有効にする。
#   vault の 9.7 は 2026-05-20 から更新されていない（repomd.xml の Last-Modified で確認）ので、
#   目録を期限切れにしない（metadata_expire=-1）。期限が来るたびに取り直す必要が無く、
#   ネットにつながっていない読者でも yum の検索が同じ結果を返す。
RUN cd /etc/yum.repos.d \
 && sed -i -E \
      -e 's|^mirrorlist=|#mirrorlist=|' \
      -e 's|^# ?baseurl=https://repo\.almalinux\.org/almalinux/\$releasever/|baseurl=https://vault.almalinux.org/9.7/|' \
      -e 's|^# ?baseurl=https://vault\.almalinux\.org/\$releasever/|baseurl=https://vault.almalinux.org/9.7/|' \
      -e 's|^metadata_expire=86400$|metadata_expire=-1|' \
      almalinux-*.repo \
 && dnf -y install rpm-build createrepo_c gnupg2 rpm-sign dnf-plugins-core \
 && dnf clean all
COPY linuc-packages/rpm/specs/ /build/specs/
COPY linuc-packages/rpm/build-repos.sh /build/build-repos.sh
RUN bash /build/build-repos.sh

# ---- 読者の檻 ---------------------------------------------------------------
FROM almalinux:9.7@sha256:2d57aea965da8fbda97736ec5125c1b683ce271438038ea1906b2391e89b77d2
ENV LANG=C.UTF-8 TZ=Asia/Tokyo
COPY --from=build /etc/yum.repos.d/ /etc/yum.repos.d/
COPY --chown=root:root --chmod=0644 linuc-packages/rpm/etc/lab.repo /etc/yum.repos.d/lab.repo
COPY --from=build /srv/ /srv/
COPY --from=build --chown=root:root --chmod=0644 /out/RPM-GPG-KEY-lab /etc/pki/rpm-gpg/RPM-GPG-KEY-lab
COPY --from=build --chown=root:root --chmod=0644 /out/RPM-GPG-KEY-lab-updates /etc/pki/rpm-gpg/RPM-GPG-KEY-lab-updates

# 1) [lab] の公開鍵を rpm の台帳に入れる（AlmaLinux の鍵はベースイメージで既に入っている）。
#    lab-updates の鍵（RPM-GPG-KEY-lab-updates）は置くだけで、台帳には入れない（第10章で yum が取り込む）
# 2) 檻で使う道具を入れる
#      yum-utils … yumdownloader（dnf-plugins-core だけでは入らない。実測 2026-10-13）
#      man-db man-pages … man を引けること自体が LinuC の出題範囲
#      jq … lab コマンドが進捗の記録に使う / sudo … 読者ユーザ lab が root になる
#      which file cpio … 本文で使う（cpio は rpm2cpio の受け手）
# 3) 演習と本文の初期状態を作る
#      labhello は入れない（第9章で読者が入れる。1.1 は登録されていない lab-updates にだけある。第10章）
#      labmotd      … 入れたあとで2か所を書き換える（演習11 で rpm -V が見つける対象）
# 4) 読者ユーザ lab（UID 1000・sudo NOPASSWD）。共通ベースと同じ作り
# 5) 目録を作る（dnf makecache）。そして一般ユーザと共有する:
#      dnf は root 以外で動くと /var/cache/dnf を使わず、/var/tmp/dnf-<ユーザ名>-* に
#      目録を一から取り直す（実測 2026-10-13: lab で yum info jq と打っただけで 53MB を落とした）。
#      ネットの無い読者だと失敗し、ネットがあっても本文に無いダウンロードの行が出る。
#      dnf は /var/tmp/dnf-lab-* が「lab の持ち物で権限 0700 のディレクトリ」ならそれを使う
#      （/usr/lib/python3.9/site-packages/dnf/yum/misc.py の getCacheDir）。
#      そこで目録をそちらへ移し、/var/cache/dnf をそこへのシンボリックリンクにする。
#      root と lab が同じ目録を読む（コピーすると 86MB 増える。ハードリンクは dnf が
#      expired_repos.json を書けずに警告を出した。どちらも実測 2026-10-13）。
RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-lab \
 && dnf -y install yum-utils man-db man-pages jq sudo which file cpio diffutils procps-ng bash-completion \
 && dnf -y install labmotd \
 && printf '%s\n' '今日のひとこと: このファイルは、パッケージから入れたあとで書き換えられた。' > /usr/share/labmotd/motd.txt \
 && chmod 0644 /usr/bin/labmotd \
 && useradd -m -u 1000 -s /bin/bash lab \
 && echo 'lab ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/lab \
 && chmod 0440 /etc/sudoers.d/lab \
 && install -d -o lab -g lab -m 0755 /home/lab/.lab /home/lab/work \
 && dnf makecache \
 && rm -rf /var/cache/dnf/*/packages/* \
 && mv /var/cache/dnf /var/tmp/dnf-lab-cache \
 && chown -R lab:lab /var/tmp/dnf-lab-cache \
 && chmod 0700 /var/tmp/dnf-lab-cache \
 && ln -s /var/tmp/dnf-lab-cache /var/cache/dnf \
 && mandb -q

COPY --chown=root:root --chmod=0755 base/bin/lab /usr/local/bin/lab
COPY --chown=root:root --chmod=0644 base/etc/99-lab.sh /etc/profile.d/99-lab.sh
COPY --chown=root:root --chmod=0555 linuc-packages/rpm/lab/ /lab/
LABEL org.opencontainers.image.source=https://github.com/chai0204/check-then-explain
LABEL org.opencontainers.image.description="LinuC 主題1.04（yum・rpm・yumdownloader）を RPM 系で手で確かめる学習用コンテナ"
LABEL org.opencontainers.image.licenses=MIT
# LAB_APT_SNAPSHOT は lab env の「apt 固定」の行に出る。この檻に apt は無いので、そう書く。
ENV LAB_THEME=linuc-packages-rpm LAB_VERSION=1.1.0 LAB_HOME=/lab \
    LAB_APT_SNAPSHOT="なし（RPM 系。下の dnf 固定の行を見る）" \
    LAB_IMAGE=ghcr.io/chai0204/lab-linuc:packages-rpm-1.1.0
USER lab
WORKDIR /home/lab
CMD ["/bin/bash", "-l"]
