#!/bin/bash
# 母艦側で取る記録（本文の第2章と入口の「2つ目の端末を開かない」の根拠）。
# docker run で起動した最初のシェルと、docker exec で後から入ったシェルの umask を比べる。
# 実行: bash probe/linuc-files-host.sh > logs/linuc-files-host.log 2>&1
set -u
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
IMG=lab-linuc-files:1.0.1
R "docker version --format '{{.Server.Version}}'"
R "docker run --rm --hostname linuc $IMG bash -lc 'umask; touch /tmp/x; ls -l /tmp/x'"
R "docker run -d --name linuc-files-host --hostname linuc $IMG sleep infinity >/dev/null"
R "docker exec linuc-files-host bash -lc 'umask; touch /tmp/x; ls -l /tmp/x'"
R "docker exec -u lab linuc-files-host bash -c umask"
R "docker rm -f linuc-files-host >/dev/null"
