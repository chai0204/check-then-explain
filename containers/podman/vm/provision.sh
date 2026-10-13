#!/bin/bash
# podman の記事の初回の準備。練習機の中で root として1回だけ走る（外側の vm が lab-guest で流す）。
#   起動のしかたに依らず、練習機が最初に応答したときに走る。vm reset --yes で戻すと、次の起動でもう一度走る。
set -euo pipefail

# ---- docker を止めておく ------------------------------------------------------
#   練習機のディスクは docker の記事と共有で、docker（dockerd・containerd）も入っている。
#   この記事は「デーモンがいない」ことを確かめるので、docker のデーモンは起動しないようにしておく
#   （第7章で、docker の CLI を podman に向けて使うときも、docker のデーモンは要らない）。
#   docker.socket も止める。ソケットが待ち受けていると、docker コマンドを打っただけで dockerd が起動する。
systemctl disable --now docker.service docker.socket containerd.service

echo PODMAN_PROVISION_OK
