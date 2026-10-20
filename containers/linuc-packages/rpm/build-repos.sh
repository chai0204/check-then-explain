#!/bin/bash
# 自作 RPM を rpmbuild で作り、署名して、createrepo_c で yum のリポジトリにする。
# build ステージでだけ動く（rpmbuild・createrepo_c・秘密鍵は読者の檻に入れない）。
#
#   /srv/lab-rpm         … 檻の中で最初から [lab] として有効（「lab packages」の鍵で署名）。labhello は 1.0
#   /srv/lab-updates-rpm … 登録されていない。第10章で読者が足す（labhello 1.1 だけ。別の鍵「lab updates」で署名。
#                          公開鍵は檻の /etc/pki/rpm-gpg/RPM-GPG-KEY-lab-updates に置くが、rpm の台帳には入れない。
#                          読者が .repo の gpgkey= に書くと、yum が入れる前に取り込んでよいかを尋ねる）
#   /srv/lab-tools-rpm   … 登録されていない。演習10 で読者が足す（別の鍵「lab tools」で署名。
#                          公開鍵はリポジトリの中に RPM-GPG-KEY-lab-tools として置く）
#   /srv/lab-files       … リポジトリではない。署名の無い単体の rpm と、比べるための
#                          AlmaLinux 公式の rpm（tree）を置く（第10章）
#   /out/RPM-GPG-KEY-lab         … [lab] の公開鍵（檻の /etc/pki/rpm-gpg/ に入れ、台帳にも入れる）
#   /out/RPM-GPG-KEY-lab-updates … lab-updates の公開鍵（檻の /etc/pki/rpm-gpg/ に置くだけ）
set -euo pipefail

# ビルド日時と中のファイルの mtime を揃える（rpm -qi の Build Date を毎回同じにするため）
export SOURCE_DATE_EPOCH=1790812800   # 2026-10-01 00:00:00 UTC
RPMDEF=(
  --define '_topdir /build/rpmbuild'
  --define '_buildhost linuc-build'
  --define 'use_source_date_epoch_as_buildtime 1'
  --define 'clamp_mtime_to_source_date_epoch 1'
)
mkdir -p /build/rpmbuild /srv/lab-rpm /srv/lab-updates-rpm /srv/lab-tools-rpm /srv/lab-files /out

rb() { rpmbuild -bb --quiet "${RPMDEF[@]}" "$@"; }
for s in liblab labapp labtool labtool-data labmotd lab-mathtools labnosig; do
  rb "/build/specs/$s.spec"
done
rb --define 'ver 1.0' /build/specs/labhello.spec
rb --define 'ver 1.1' /build/specs/labhello.spec

R=/build/rpmbuild/RPMS/noarch
cp "$R"/liblab-1.0-1.noarch.rpm "$R"/labapp-1.0-1.noarch.rpm \
   "$R"/labhello-1.0-1.noarch.rpm \
   "$R"/labtool-1.0-1.noarch.rpm "$R"/labtool-data-1.0-1.noarch.rpm \
   "$R"/labmotd-1.0-1.noarch.rpm                       /srv/lab-rpm/
cp "$R"/labhello-1.1-1.noarch.rpm                       /srv/lab-updates-rpm/
cp "$R"/lab-mathtools-1.0-1.noarch.rpm                  /srv/lab-tools-rpm/
cp "$R"/labnosig-1.0-1.noarch.rpm                       /srv/lab-files/
# 比べるための本物: AlmaLinux が署名した公式のパッケージを1つ置く（vault 9.7 から取る）
dnf download --destdir /srv/lab-files tree

# ---- 署名用の鍵を3本作る（秘密鍵はこのステージから外に出さない） ----
export GNUPGHOME=/build/gnupg
install -d -m 0700 "$GNUPGHOME"
genkey() {  # genkey <名前> <メール>
  printf '%s\n' '%no-protection' 'Key-Type: RSA' 'Key-Length: 3072' \
    "Name-Real: $1" "Name-Email: $2" 'Expire-Date: 0' '%commit' > /build/keyparams
  gpg --batch --gen-key /build/keyparams
}
genkey 'lab packages' 'lab@example.invalid'
genkey 'lab updates'  'updates@example.invalid'
genkey 'lab tools'    'tools@example.invalid'
gpg --list-keys --keyid-format long

sign() {  # sign <鍵の名前> <rpm ...>
  local name="$1"; shift
  rpm --define "_gpg_name $name" --addsign "$@"
}
sign 'lab packages' /srv/lab-rpm/*.rpm
sign 'lab updates'  /srv/lab-updates-rpm/*.rpm
sign 'lab tools'    /srv/lab-tools-rpm/*.rpm
# /srv/lab-files/labnosig は署名しない（それが第10章の教材）

gpg --export --armor 'lab packages' > /out/RPM-GPG-KEY-lab
gpg --export --armor 'lab updates'  > /out/RPM-GPG-KEY-lab-updates
gpg --export --armor 'lab tools'    > /srv/lab-tools-rpm/RPM-GPG-KEY-lab-tools

for d in /srv/lab-rpm /srv/lab-updates-rpm /srv/lab-tools-rpm; do
  createrepo_c --quiet "$d"
done

find /srv /out -type f | sort
