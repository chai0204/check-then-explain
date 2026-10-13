#!/bin/bash
# LinuC 主題1.06 の檻を、母艦（docker を打つ側）から見た記録。実践編の入口に書く注意の出どころ。
#   - docker run で入った端末と、docker exec で後から開いた端末では umask が違う（0022 と 0000）
#     → 第4章の ls -l の権限表示が本文とずれる。2つ目の端末を開く読者がいるので入口に書く。
# 実行: 母艦で bash probe/linuc-shell-host.sh > logs/linuc-shell-host.log 2>&1
#       （公開名の代わりにローカルのイメージ lab-linuc-shell:1.0.0 を使う。中身は同じもの）
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
IMG=lab-linuc-shell:1.0.0
docker rm -f linuc-shell-host >/dev/null 2>&1
R "docker run --rm --hostname linuc $IMG bash -lc 'umask; touch /tmp/f; ls -l /tmp/f'"
docker run -d --name linuc-shell-host --hostname linuc "$IMG" sleep infinity >/dev/null
R "docker exec linuc-shell-host bash -lc 'umask; touch /tmp/f; ls -l /tmp/f'"
R "docker exec linuc-shell-host lab env | grep umask"
docker rm -f linuc-shell-host >/dev/null
