#!/bin/bash
# LinuC 主題1.04 Debian 系の檻の追加記録（2026-10-13。公式例題 linuc.org/study/samples の監査を受けて足したもの）。
# 記録は lab-linuc-packages-deb:1.0.1 で取る。本文に足した端末表示はここから引く。
# 節ごとに檻を起動し直して打つ（probe/linuc-packages-run.sh exam）。
#   bash /tmp/probe.sh e-showpkg
set -u
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
S() { printf '\n\n========== %s ==========\n' "$*"; }

case "${1:-}" in
  e-showpkg)
    S "e-showpkg. 依存を出すのは depends と showpkg。showpkg は版・逆向きの依存・依存をまとめて出す（例題 4932）"
    R "apt-cache show labapp | grep '^Depends'"
    R 'apt-cache depends labapp'
    R 'apt-cache showpkg labapp'
    R 'apt-cache rdepends liblab'
    R 'apt-cache showpkg liblab'
    # MANWIDTH=80 は折り返しの幅を固定するため（端末の幅で行の切れ目が変わらないように）
    # 見出しの行（showpkg pkg... で終わる行）から次の見出し stats まで。書式（SYNOPSIS）の行は拾わない
    R 'MANWIDTH=80 man apt-cache | sed -n "/^ *showpkg pkg\.\.\.$/,/^ *stats$/p"'
    ;;
  *) echo "使い方: bash probe.sh e-showpkg" >&2; exit 2 ;;
esac
