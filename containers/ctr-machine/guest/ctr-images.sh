#!/usr/bin/env bash
# 練習機のイメージ置き場に、記事で使うイメージを取り込み、ダイジェストを照合する。
#
#   bash ctr-images.sh docker   … root で。docker（dockerd → containerd）の置き場所
#   bash ctr-images.sh podman   … student で。rootless の podman の置き場所（~/.local/share/containers/storage）
#
# タグで取って、そのタグが指していた中身のダイジェストを下の値と照らす。違えば止める（タグは後から動きうるため）。
# ダイジェストで取らないのは、docker がダイジェスト付きで取ったイメージにタグを付けないから（タグなしの <none> になる。
# 実測 2026-10-13、docker 29.1.3）。読者の手元では alpine:3.24.2 という名前で見えてほしい。
set -euo pipefail
IMAGES=(
  "docker.io/library/alpine:3.24.2@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6"
  "docker.io/library/busybox:1.38.0@sha256:fd7dc98638c8e305f4dc34e979f1c0fdfdcaeb0fbf8fcff77ae834b6da3d7e6e"
)
for spec in "${IMAGES[@]}"; do
  ref=${spec%@*}
  want=${spec#*@}
  case "${1:?docker か podman}" in
    docker)
      docker pull -q "$ref"
      got=$(docker image inspect "$ref" --format '{{index .RepoDigests 0}}')
      got=${got#*@} ;;
    podman)
      podman pull -q "$ref" >/dev/null
      got=$(podman image inspect "$ref" --format '{{.Digest}}') ;;
    *) echo "使い方: ctr-images.sh docker|podman" >&2; exit 2 ;;
  esac
  [ "$got" = "$want" ] || { echo "✗ $ref のダイジェストが違う: $got（期待 $want）"; exit 1; }
  echo "✔ $ref = $want"
done
echo CTR_IMAGES_OK
