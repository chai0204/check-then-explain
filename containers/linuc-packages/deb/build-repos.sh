#!/bin/bash
# 自作パッケージを dpkg-deb --build で .deb にし、file: で読めるリポジトリ2つに並べる。
# build ステージでだけ動く（apt-ftparchive が要るのはここだけ。読者の檻には入れない）。
#
#   /srv/lab-repo   … 檻の中で最初から apt のソースに入っている。スイートは2つ:
#                       lab         … 最初からソースにある（labhello は 1.0）
#                       lab-updates … ソースに入っていない。第6章で読者が足す（labhello 1.1 だけ）
#                     Ubuntu の noble（発売時の版）と noble-updates（後から出た版）と同じ形にする。
#                     中身（pool/）は1つで、スイートごとに目録（dists/<スイート>/）を分ける。
#   /srv/lab-tools  … 入っていない。演習06 で読者が足す（スイート tools）
#   /out/labnote_1.0_all.deb … リポジトリに置かない単体の .deb（演習07 の配布物）
#
# リポジトリは Debian と同じ dists/ と pool/ の形にする。読者が sources.list に書く
# 「URI・ディストリビューション・コンポーネント」の3つが、ディレクトリのどこに対応するかを
# 目で確かめられるようにするため（平たい ./ 形式だとこの対応が見えない）。
set -euo pipefail

# dpkg-deb は SOURCE_DATE_EPOCH があれば中のファイルの mtime をこの時刻に揃える。
# 揃えないと `dpkg -c` の出力がビルドした日時で変わり、本文と読者の画面がずれる。
export SOURCE_DATE_EPOCH=1790812800   # 2026-10-01 00:00:00 UTC

SRC=/build/pkgs

build() {  # build <ソースのディレクトリ名> <出力先ディレクトリ>
  local d="$SRC/$1" out="$2"
  # 権限を揃える（ビルド環境の umask に左右されないように）
  find "$d" -type d -exec chmod 0755 {} +
  find "$d" -type f -exec chmod 0644 {} +
  if [ -d "$d/usr/bin" ]; then chmod 0755 "$d"/usr/bin/*; fi
  # man ページは Debian の決まりどおり gzip -9n で縮めて置く（-n は名前と時刻を入れない。中身が毎回同じになる）
  if [ -d "$d/usr/share/man" ]; then find "$d/usr/share/man" -type f -name '*.[0-9]' -exec gzip -9n {} +; fi
  # Installed-Size（KiB）を control に足す。dpkg-deb は自分では計算しない。
  # これが無いと apt が「0 B の追加ディスク」と表示し、実物のパッケージと見た目が違ってしまう。
  local kib
  kib=$(du -sk --exclude=DEBIAN "$d" | cut -f1)
  grep -q '^Installed-Size:' "$d/DEBIAN/control" \
    || sed -i "/^Maintainer:/i Installed-Size: $kib" "$d/DEBIAN/control"
  mkdir -p "$out"
  dpkg-deb --root-owner-group --build "$d" "$out/"
}

pool() {  # pool <パッケージ名> → pool/main/<頭文字>/<名前>
  local n="$1" h="${1:0:1}"
  case "$n" in lib*) h="${n:0:4}" ;; esac
  printf 'pool/main/%s/%s' "$h" "$n"
}

# index <リポジトリの根> <スイート> <pool の中のファイル ...>
#   スイートに載せる .deb だけを、同じ相対パスでハードリンクした作業用の木から目録を作る。
#   apt-ftparchive は渡したディレクトリの下を全部数えるので、pool を1つにしたまま
#   スイートごとに載せるものを分けるには、こうする（Filename は本物の pool のパスと同じになる）。
index() {
  local root="$1" dist="$2"; shift 2
  local stage="/build/stage/$dist" f
  rm -rf "$stage"
  for f in "$@"; do
    mkdir -p "$stage/$(dirname "$f")"
    ln "$root/$f" "$stage/$f"
  done
  mkdir -p "$root/dists/$dist/main/binary-amd64"
  (cd "$stage" && apt-ftparchive packages pool/main) > "$root/dists/$dist/main/binary-amd64/Packages"
  gzip -9n -k "$root/dists/$dist/main/binary-amd64/Packages"
  # apt-file が読む「どのファイルがどのパッケージにあるか」の索引
  (cd "$stage" && apt-ftparchive contents pool/main) > "$root/dists/$dist/main/Contents-amd64"
  gzip -9n -k "$root/dists/$dist/main/Contents-amd64"
  (cd "$root" && apt-ftparchive \
    -o APT::FTPArchive::Release::Origin=check-then-explain \
    -o APT::FTPArchive::Release::Label="lab $dist" \
    -o APT::FTPArchive::Release::Suite="$dist" \
    -o APT::FTPArchive::Release::Codename="$dist" \
    -o APT::FTPArchive::Release::Architectures=amd64 \
    -o APT::FTPArchive::Release::Components=main \
    -o APT::FTPArchive::Release::Description="LinuC 1.04 practice repository ($dist)" \
    release "dists/$dist") > /tmp/Release
  mv /tmp/Release "$root/dists/$dist/Release"
}

R=/srv/lab-repo
LAB=()
for p in liblab_1.0 labapp_1.0 labhello_1.0 labsvc_1.0 labsvc-common_1.0 labnote-data_1.0 \
         labfortune_1.0 labbackup_1.0 labweb_1.0 labweb-data_1.0; do
  n="${p%_*}"
  build "$p" "$R/$(pool "$n")"
  LAB+=("$(pool "$n")/${p}_all.deb")
done
build labhello_1.1      "$R/$(pool labhello)"
build lab-mathtools_1.0 "/srv/lab-tools/$(pool lab-mathtools)"
build labnote_1.0       /out

index "$R"           lab         "${LAB[@]}"
index "$R"           lab-updates "$(pool labhello)/labhello_1.1_all.deb"
index /srv/lab-tools tools       "$(pool lab-mathtools)/lab-mathtools_1.0_all.deb"

find /srv /out -type f | sort
