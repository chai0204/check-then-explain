#!/bin/bash
# LinuC 主題1.04 RPM 系の檻の追加記録（2026-10-13。公式例題 linuc.org/study/samples の監査を受けて足したもの）。
# 記録は lab-linuc-packages-rpm:1.0.1 で取る。本文に足した端末表示はここから引く。
# 節ごとに檻を起動し直して打つ（probe/linuc-packages-run.sh exam）。
#   bash /tmp/probe.sh e-installed|e-autoremove|e-update
set -u
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
S() { printf '\n\n========== %s ==========\n' "$*"; }

case "${1:-}" in
  e-installed)
    S "e-installed. 入っている全部を出すのは list installed と info installed。info も installed / available / updates を付けられる（例題 3678）"
    R 'yum list installed | head -4'
    R 'yum info installed | head -14'
    R 'yum list updates'
    R 'yum info updates'
    # 例題の誤答の選択肢: installed というサブコマンドは無い。search installed は語で探すだけ
    R 'yum installed; echo "exit=$?"'
    R 'yum search installed | head -4'
    ;;
  e-autoremove)
    S "e-autoremove. dnf の autoremove は、名前を付けるとそれを依存ごと消す（例題 5580）"
    R 'sudo yum install -y labapp'
    R 'sudo yum autoremove -y labapp'
    R 'rpm -q labapp liblab; echo "exit=$?"'
    ;;
  e-update)
    S "e-update. dnf の update は upgrade の別名（例題 5580）"
    R 'yum update --help | head -1'
    R 'yum upgrade --help | head -1'
    ;;
  *) echo "使い方: bash probe.sh e-installed|e-autoremove|e-update" >&2; exit 2 ;;
esac
