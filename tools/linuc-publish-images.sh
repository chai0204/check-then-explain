#!/usr/bin/env bash
# LinuC のコースのイメージを GHCR に push し、本文の __DIGEST__ を実際のダイジェストに置き換える。
#
#   bash tools/linuc-publish-images.sh            push して置き換える
#   bash tools/linuc-publish-images.sh --dry-run  何をするかだけ出す
#
# 公開名は1つのパッケージ ghcr.io/chai0204/lab-linuc にタグで分ける（<tag>-1.0.0）。
# GHCR の可視性はパッケージ単位で、API で切り替えられない（publish.md §6）。コースごとに
# パッケージを分けると、オーナーが Web UI で切り替える回数がコースの数だけ増えるため（2026-10-13）。
#
# 置き換えるのは public/<slug>/ の中の「ghcr.io/chai0204/lab-linuc:<tag>-1.0.0@sha256:__DIGEST__」だけ。
# ダイジェストは push の出力からではなく、レジストリに問い合わせて確かめる（push 後に実物を見る）。
set -euo pipefail
cd "$(dirname "$0")/.."
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
REPO=ghcr.io/chai0204/lab-linuc

# slug  ローカルイメージ  公開タグ
PAIRS=(
  "linuc-files     lab-linuc-files:1.0.0         files"
  "linuc-text      lab-linuc-text:1.0.0          text"
  "linuc-shell     lab-linuc-shell:1.0.0         shell"
  "linuc-packages  lab-linuc-packages-deb:1.0.0  packages-deb"
  "linuc-packages  lab-linuc-packages-rpm:1.0.0  packages-rpm"
  "linuc-boot      lab-linuc-boot:1.0.0          boot"
  "linuc-disks     lab-linuc-disks:1.0.0         disks"
  "linuc-network   lab-linuc-network:1.0.0       network"
  "linuc-admin     lab-linuc-admin:1.0.0         admin"
  "linuc-security  lab-linuc-security:1.0.0      security"
)

for line in "${PAIRS[@]}"; do
  read -r slug local tag <<<"$line"
  [ -d "public/$slug" ] || { echo "· $slug: まだ無い"; continue; }
  docker image inspect "$local" >/dev/null 2>&1 || { echo "✗ $slug: ローカルイメージ $local が無い"; exit 1; }
  ref="$REPO:$tag-1.0.0"
  if [ "$DRY" = 1 ]; then echo "push $local → $ref"; continue; fi
  docker tag "$local" "$ref"
  docker push -q "$ref" >/dev/null
  dg=$(docker buildx imagetools inspect "$ref" --format '{{json .Manifest}}' | jq -r '.digest')
  [[ "$dg" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "✗ $ref のダイジェストが取れない: $dg"; exit 1; }
  n=$(grep -rl "$ref@sha256:__DIGEST__" "public/$slug" | wc -l)
  grep -rl "$ref@sha256:__DIGEST__" "public/$slug" | xargs -r sed -i "s#$ref@sha256:__DIGEST__#$ref@$dg#g"
  echo "✔ $ref@$dg（$n ファイルを置き換え）"
done
left=$(grep -rl '__DIGEST__' public | wc -l)
echo "残りの __DIGEST__: $left ファイル"
