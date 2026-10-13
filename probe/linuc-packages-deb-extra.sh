#!/bin/bash
# LinuC 主題1.04 Debian 系の檻の追加記録（2026-10-13 の事実確認を受けて足したもの）。
# 記録は lab-linuc-packages-deb:1.0.1 で取る（1.0.0 で取り始め、模範解答を直した 1.0.1 で取り直した）。
# 本文に足した端末表示はここから引く。節ごとに檻を起動し直して打つ（probe/linuc-packages-run.sh extra）。
#   bash /tmp/probe.sh x-upgrade|x-autoremove|x-root|x-aptcmds|x-un|x-pending|x-depends|x-docs
set -u
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
S() { printf '\n\n========== %s ==========\n' "$*"; }

DEB_APP=/srv/lab-repo/pool/main/l/labapp/labapp_1.0_all.deb
DEB_H11=/srv/lab-repo/pool/main/l/labhello/labhello_1.1_all.deb

case "${1:-}" in
  x-upgrade)
    S "x-upgrade. apt upgrade と apt-get upgrade と full-upgrade の違い（man の記述）"
    # MANWIDTH=80 は折り返しの幅を固定するため（端末の幅で行の切れ目が変わらないように）
    R 'MANWIDTH=80 man apt | sed -n "/^ *upgrade (apt-get(8))/,/^ *full-upgrade/p"'
    R 'MANWIDTH=80 man apt-get | sed -n "/^ *upgrade$/,/^ *dist-upgrade/p"'
    R 'MANWIDTH=80 man apt | sed -n "/^ *full-upgrade (apt-get(8))/,/^ *install, reinstall/p"'
    ;;
  x-autoremove)
    S "x-autoremove. autoremove に名前を渡すと"
    R 'sudo apt install -y labapp'
    R 'apt-mark showauto | grep lab'
    R 'sudo apt autoremove -y labapp'
    R 'dpkg -l labapp'
    R 'ls -l /etc/labapp.conf'
    R 'dpkg -l liblab | tail -1'
    R "grep -c '^Package: liblab\$' /var/lib/dpkg/status"
    ;;
  x-root)
    S "x-root. 一般ユーザのまま打つと（root が要るもの・要らないもの）"
    R 'apt update; echo "exit=$?"'
    R 'apt-get update; echo "exit=$?"'
    R 'apt-file update; echo "exit=$?"'
    R 'apt-cache policy labhello | head -3'
    R 'dpkg -l labhello | tail -1'
    R 'cd ~/work && apt-get download labhello && ls *.deb'
    ;;
  x-aptcmds)
    S "x-aptcmds. apt にも depends・rdepends・policy・download・clean がある"
    R 'apt depends labapp'
    R 'apt rdepends liblab'
    R 'apt policy labhello'
    R 'cd ~/work && apt download liblab && ls *.deb'
    R 'sudo apt clean; echo "exit=$?"'
    R 'MANWIDTH=80 man apt | sed -n "/^ *showsrc, depends, rdepends, policy/,/(summarised in apt-get(8))/p"'
    ;;
  x-un)
    S "x-un. dpkg -l の un は、台帳に行があるという意味ではない"
    R "sudo dpkg -i $DEB_APP; echo \"exit=\$?\""
    R 'dpkg -l labapp liblab'
    R "grep -c '^Package: liblab\$' /var/lib/dpkg/status"
    R "dpkg -s labapp | grep -E '^(Status|Depends):'"
    ;;
  x-pending)
    S "x-pending. 依存が満たされた iU は、apt が次の操作のついでに設定する"
    R "sudo dpkg --unpack $DEB_H11"
    R 'dpkg -l labhello | tail -1'
    R 'sudo apt install -y liblab'
    R 'dpkg -l labhello | tail -1'
    R 'labhello'
    ;;
  x-depends)
    S "x-depends. apt-cache depends が出すのは Depends: だけではない"
    R 'apt-cache depends apt'
    ;;
  x-docs)
    S "x-docs. apt-file update と debconf-show の * の意味（man の記述）"
    R 'MANWIDTH=80 man apt-file | sed -n "/^ *update$/,/on whether a tty is available/p"'
    R 'MANWIDTH=80 man debconf-show | sed -n "/The most common use/,/with an/p"'
    ;;
  *) echo "使い方: bash probe.sh x-upgrade|x-autoremove|x-root|x-aptcmds|x-un|x-pending|x-depends|x-docs" >&2; exit 2 ;;
esac
