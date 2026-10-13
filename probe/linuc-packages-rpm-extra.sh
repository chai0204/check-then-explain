#!/bin/bash
# LinuC 主題1.04 RPM 系の檻の追加記録（2026-10-13 の事実確認を受けて足したもの）。
# 記録は lab-linuc-packages-rpm:1.0.1 で取る（1.0.0 で取り始め、模範解答を直した 1.0.1 で取り直した）。
# 本文に足した端末表示はここから引く。節ごとに檻を起動し直して打つ（probe/linuc-packages-run.sh extra）。
#   bash /tmp/probe.sh x-qp|x-repoquery|x-rpmsave
set -u
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
S() { printf '\n\n========== %s ==========\n' "$*"; }

case "${1:-}" in
  x-qp)
    S "x-qp. -qp はファイルの中を読むだけ。.rpm で終わる引数は rpm 4.16 ではファイルとして読まれる"
    R 'rpm -q labhello'
    R "rpm -qpi /srv/lab-rpm/labhello-1.0-1.noarch.rpm | grep -E '^(Name|Version|Install Date)'"
    R "rpm -qi labhello | grep -E '^(Name|Version|Install Date)'"
    R 'rpm -q labtool; echo "exit=$?"'
    R 'rpm -ql labtool; echo "exit=$?"'
    R 'rpm -qpl /srv/lab-rpm/labtool-1.0-1.noarch.rpm'
    R 'rpm -ql /srv/lab-rpm/labtool-1.0-1.noarch.rpm; echo "exit=$?"'
    R 'rpm --version'
    ;;
  x-repoquery)
    S "x-repoquery. 入っていないパッケージの中身を目録から引く"
    R 'rpm -q labtool; echo "exit=$?"'
    R 'yum repoquery -l labtool'
    R 'ls -l /usr/bin/repoquery'
    R 'repoquery -l labtool'
    R 'yum repoquery -l labapp liblab'
    ;;
  x-rpmsave)
    S "x-rpmsave. 書き換えていない設定ファイルは、消すと一緒に消える"
    R 'sudo yum install -y labapp'
    R 'rpm -V labapp; echo "exit=$?"'
    R 'sudo rpm -e labapp; echo "exit=$?"'
    R 'ls -l /etc/labapp.conf*; echo "exit=$?"'
    ;;
  *) echo "使い方: bash probe.sh x-qp|x-repoquery|x-rpmsave" >&2; exit 2 ;;
esac
