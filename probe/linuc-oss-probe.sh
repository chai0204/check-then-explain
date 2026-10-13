#!/bin/bash
# LinuC 主題1.11（オープンソースの文化）の本文に載せる全コマンドを、素の Ubuntu の中で実際に通す。
# ここに出ない出力は本文に書かない（憲章 §3）。
#
# このコースには檻（専用イメージ）も演習も無い。主題1.11 は知識問題で、
# 出題範囲に打つコマンドが無いため（オーナー了承済み 2026-10-13）。
# そのかわり、どの Ubuntu にもある「ライセンスの実物」を読む:
#   /usr/share/common-licenses/     主要なライセンスの全文（base-files が置く）
#   /usr/share/doc/<pkg>/copyright  パッケージごとの著作権者とライセンス（Debian の機械可読形式）
#
# 記録はシリーズ共通の土台と同じ素のイメージで取る。読者の起動コマンドと同じ --hostname を付ける:
#   docker run -d --name linuc-oss-probe --hostname linuc \
#     ubuntu:24.04@sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3 sleep infinity
#   docker cp probe/linuc-oss-probe.sh linuc-oss-probe:/tmp/probe.sh
#   docker exec linuc-oss-probe bash /tmp/probe.sh > logs/linuc-oss-probe.log 2>&1
#   docker rm -f linuc-oss-probe
#
# 読者は `docker run --rm -it` の対話シェル（root・カレントは /）で同じコマンドを打つ。
# 端末の有無で見た目が変わる ls は -1 を付けて、1行1件に揃えてある。
# 確認済み（2026-10-13）: docker で2回流して記録が完全に一致。podman 5.8.6 rootless でも1文字も違わない。
# 端末あり・対話シェル（~/.bashrc の ls/grep の --color=auto が効く状態）でも、色と CR を落とせば同じ文字になる。
# 出力の並びが環境で変わりうる grep -r には | sort を付けてある（readdir の順はファイルシステム次第）。
set -u
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
S() { printf '\n\n========== %s ==========\n' "$*"; }
cd /

S "0. 環境（素の Ubuntu には lab コマンドが無いので、同じ情報を個別に取る）"
R 'grep PRETTY_NAME /etc/os-release'
R 'uname -m'
R 'hostname'
R 'whoami'
R 'dpkg-query -W base-files bash coreutils dpkg libc6'
R "dpkg -l | grep -c '^ii'"

S "1. 持ち主はいる（1.11.1 オープンソースの定義・著作物）"
R 'ls --version'
R 'head -6 /usr/share/common-licenses/GPL-3'
R "grep -A2 '^Files: \*\$' /usr/share/doc/coreutils/copyright"
R "grep -A2 '^Files: \*\$' /usr/share/doc/bash/copyright"
R "grep -B1 -A1 'Michael Wood' /usr/share/doc/bash/copyright"
R 'grep -A2 "two steps" /usr/share/common-licenses/GPL-2'
R 'grep -A3 "^The laws of most" /usr/share/common-licenses/CC0-1.0'
R 'echo "--- 最小イメージは man を消してある ---"'
R 'man ls'
R 'find /usr/share/man -type f | wc -l'
R 'ls -1 /usr/share/doc/bash/'
R 'ls -1 /usr/share/doc/*/copyright | wc -l'
R 'cat /usr/share/doc/*/copyright | wc -l'
R "grep -v '^\$' /etc/dpkg/dpkg.cfg.d/excludes"
R 'grep -A8 "4. Conveying Verbatim Copies." /usr/share/common-licenses/GPL-3'

S "1b. 自由とソースコード（1.11.1 自由・ソースコード）"
R 'grep -A5 "When we speak of free software" /usr/share/common-licenses/GPL-3'
R 'grep -A4 "1. Source Code." /usr/share/common-licenses/GPL-3'
R "grep -A1 '^Source:' /usr/share/doc/bash/copyright"
R "grep -A2 '^Source:' /usr/share/doc/liblzma5/copyright"

S "1c. 無保証（1.11.1 無保証）"
R 'bash --version'
R 'grep -A9 "15. Disclaimer of Warranty" /usr/share/common-licenses/GPL-3'
R 'grep -A1 "BECAUSE THE PROGRAM IS LICENSED FREE OF CHARGE" /usr/share/common-licenses/GPL-2'
R 'grep -iL warrant /usr/share/common-licenses/*'
R 'grep -A2 "The Document may include Warranty Disclaimers" /usr/share/common-licenses/GFDL-1.3'
R 'grep -A1 "You may charge any price" /usr/share/common-licenses/GPL-3'

S "1d. ライセンスはたくさんある・開発は続いている（1.11.1 多くのライセンスが存在・継続した開発）"
R 'ls -1 /usr/share/common-licenses/'
R 'ls -l /usr/share/common-licenses/GPL /usr/share/common-licenses/LGPL'
R 'dpkg -S /usr/share/common-licenses'
R 'grep -l /usr/share/common-licenses /usr/share/doc/*/copyright | wc -l'
R "grep -l '^Format: .*copyright-format' /usr/share/doc/*/copyright | wc -l"
R "grep -h '^License:' /usr/share/doc/*/copyright | sort -u | wc -l"
R "grep -h '^License:' /usr/share/doc/*/copyright | sort | uniq -c | sort -rn | head -10"
R 'zcat /usr/share/doc/bash/changelog.Debian.gz | head -5'
R "zcat /usr/share/doc/bash/changelog.Debian.gz | grep -c '^bash ('"
R "zcat /usr/share/doc/bash/changelog.Debian.gz | grep '^bash (' | tail -1"
R 'zcat /usr/share/doc/liblzma5/changelog.Debian.gz | head -9'

S "2. コピーレフトは、配るときに効く（1.11.1 GPL / AGPL / LGPL / MPL・改変と再配布）"
R 'grep -A1 "is a free, copyleft license" /usr/share/common-licenses/GPL-3'
R 'grep -rl copyleft /usr/share/common-licenses/ | sort'
R 'grep -n "^  [0-9]*\. [A-Z]" /usr/share/common-licenses/GPL-3'
R 'grep -A2 "You may make, run and propagate" /usr/share/common-licenses/GPL-3'
R "grep -A2 'To \"convey\"' /usr/share/common-licenses/GPL-3"
R 'grep -A2 "^Activities other than" /usr/share/common-licenses/GPL-2'
R 'grep -A4 "6. Conveying Non-Source Forms." /usr/share/common-licenses/GPL-3'
R 'grep -A1 "a) The work must carry prominent notices" /usr/share/common-licenses/GPL-3'
R 'grep -A4 "c) You must license the entire work" /usr/share/common-licenses/GPL-3'
R 'grep -A8 "13. Use with the GNU Affero" /usr/share/common-licenses/GPL-3'
R 'ls /usr/share/common-licenses/ | grep -ic agpl'
R 'grep -il affero /usr/share/doc/*/copyright | wc -l'
R 'wc -l /usr/share/common-licenses/GPL-3 /usr/share/common-licenses/LGPL-3'
R 'grep -A2 "This version of the GNU Lesser" /usr/share/common-licenses/LGPL-3'
R 'grep -A13 "4. Combined Works." /usr/share/common-licenses/LGPL-3'
R 'grep -A15 "d) Do one of the following" /usr/share/common-licenses/LGPL-3'
R 'grep -A3 "GNU C Library is free software" /usr/share/doc/libc6/copyright'
R "grep -A8 '^1.10. \"Modifications\"' /usr/share/common-licenses/MPL-2.0"
R 'grep -A4 "^3.3. Distribution of a Larger Work" /usr/share/common-licenses/MPL-2.0'
R "grep -B7 '^License: MPL' /usr/share/doc/libffi8/copyright"
R "grep -hE '^License: GPL-[23]\+?\$' /usr/share/doc/*/copyright | sort | uniq -c"
R "grep -B1 -A3 'or any later version\" applies' /usr/share/common-licenses/GPL-3"

S "3. 持ち主がいないのは、パブリックドメインだけ（1.11.1 BSD / MIT / Apache / パブリックドメイン）"
R "grep -n '^License: Expat' /usr/share/doc/apt/copyright"
R 'sed -n 102,121p /usr/share/doc/apt/copyright'
R 'cat /usr/share/common-licenses/BSD'
R "grep -h '^License: BSD-[234]-[cC]lause\$' /usr/share/doc/*/copyright | sort | uniq -c"
R "grep -h -A2 'All advertising materials' /usr/share/doc/*/copyright | head -3"
R 'grep -n "^   [0-9]\. " /usr/share/common-licenses/Apache-2.0'
R 'sed -n 90,106p /usr/share/common-licenses/Apache-2.0'
R 'grep -A2 "(d) If the Work includes a" /usr/share/common-licenses/Apache-2.0'
R 'grep -A5 "You may add Your own copyright statement" /usr/share/common-licenses/Apache-2.0'
R 'sed -n 74,88p /usr/share/common-licenses/Apache-2.0'
R 'grep -ic patent /usr/share/common-licenses/BSD /usr/share/common-licenses/Apache-2.0 /usr/share/common-licenses/MPL-2.0 /usr/share/common-licenses/GPL-3'
R 'grep -A5 "^5.2. If You initiate litigation" /usr/share/common-licenses/MPL-2.0'
R 'sed -n 102,121p /usr/share/doc/apt/copyright | grep -ic patent'
R "grep -B2 -A2 '^License: configure' /usr/share/doc/sensible-utils/copyright"
R "grep -A2 '^Files: \*\$' /usr/share/doc/libselinux1/copyright"
R "grep -A11 '^License: public-domain' /usr/share/doc/libselinux1/copyright"
R "grep -n 'is in the public domain' /usr/share/doc/liblzma5/copyright | head -3"
R "grep -B5 -A1 'do whatever you want with this file' /usr/share/doc/liblzma5/copyright | head -7"
R 'grep -A3 "^Certain owners wish" /usr/share/common-licenses/CC0-1.0'
R 'grep -A6 "^3. Public License Fallback" /usr/share/common-licenses/CC0-1.0'
R "grep -A4 '^License: Beerware' /usr/share/doc/libmd0/copyright"
R "grep -B1 -h '^ Permission is hereby granted, free of charge' /usr/share/doc/*/copyright | grep '^License:' | sort | uniq -c | sort -rn"
R "grep -n -e '^License: MIT/X11\$' -e '^License: X11\$' -e 'Except as contained' /usr/share/doc/ncurses-bin/copyright"
R 'sed -n 63,67p /usr/share/doc/ncurses-bin/copyright'
R "grep -c 'Except as contained' /usr/share/doc/apt/copyright /usr/share/doc/util-linux/copyright"
R "ldd /bin/ls | awk '{print \$1}'"
R 'dpkg -S libselinux.so.1 libc.so.6 libpcre2-8.so.0'
R "grep -m1 -H '^License:' /usr/share/doc/coreutils/copyright /usr/share/doc/libselinux1/copyright /usr/share/doc/libpcre2-8-0/copyright"

S "4. 報告先は、ソフトの中に書いてある（1.11.2 コミュニティとエコシステム）"
R 'bash --help | tail -4'
R 'grep URL /etc/os-release'
R "dpkg -s bash | grep -E '^(Version|Maintainer|Original-Maintainer|Homepage):'"
R "grep '^Upstream-Contact' /usr/share/doc/bash/copyright"
R "dpkg-query -W -f='\${Maintainer}\n' | sort | uniq -c | sort -rn"
R "dpkg-query -W -f='\${Original-Maintainer}\n' | sort | uniq -c | sort -rn | head -6"
R "grep -h '^Upstream-Contact:' /usr/share/doc/*/copyright | sort | uniq -c | sort -rn"
R "grep -l '^Upstream-Contact:' /usr/share/doc/*/copyright | wc -l"
R "grep -h -A3 '^Source:' /usr/share/doc/*/copyright | grep -oE 'https?://[^/ ]+' | sort | uniq -c | sort -rn | head -8"
R 'grep --help | tail -3'
R 'sed --help | tail -1'
R 'ls --help | tail -3'
R 'bashbug --help'
R 'echo y | EDITOR=cat bashbug'
R "dpkg -s liblzma5 | grep -E '^(Version|Maintainer|Original-Maintainer):'"
R "zcat /usr/share/doc/liblzma5/changelog.Debian.gz | grep -A5 'really5.4.5-1) unstable'"
R 'zcat /usr/share/doc/bash/changelog.Debian.gz | head -3'
