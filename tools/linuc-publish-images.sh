#!/usr/bin/env bash
# 記事のイメージを GHCR に push し、本文の __DIGEST__ を実際のダイジェストに置き換える（LinuC のコースと道具の記事）。
#
#   bash tools/linuc-publish-images.sh [slug ...]            push して置き換える（slug を指定すればそれだけ）
#   bash tools/linuc-publish-images.sh --dry-run [slug ...]  何をするかだけ出す
#
# 公開名は1つのパッケージ ghcr.io/chai0204/lab-linuc にタグで分ける（<tag>-1.0.0）。
# GHCR の可視性はパッケージ単位で、API で切り替えられない（publish.md §6）。コースごとに
# パッケージを分けると、オーナーが Web UI で切り替える回数がコースの数だけ増えるため（2026-10-13）。
#
# 道具の記事（kvm・qemu・docker・podman …）は、もう1つのパッケージ ghcr.io/chai0204/lab にタグで分ける（<slug>-1.0.0）。
#
# 置き換えるのは public/<slug>/ と、章のひな形 probe/<slug>-tpl/（あれば）の中の「<公開名>@sha256:__DIGEST__」だけ。
# ひな形も置き換えるのは、記録から章を作り直したときにダイジェストが __DIGEST__ に戻らないようにするため。
# ダイジェストは push の出力からではなく、レジストリに問い合わせて確かめる（push 後に実物を見る）。
# 最後に tools/ghcr-anon-check.mjs で、読者と同じ条件（ログインなし）で取れるかを確かめる。
# 新しいパッケージは非公開で作られるので、オーナーが公開に切り替えるまではそこで止まる（2026-10-14 追加）。
set -euo pipefail
cd "$(dirname "$0")/.."
DRY=0; [ "${1:-}" = "--dry-run" ] && { DRY=1; shift; }
# 残りの引数でコース（slug）を絞る。指定が無ければ全部。制作中のコースを誤って push しないため。
ONLY=" $* "
REPO=ghcr.io/chai0204/lab-linuc
TOOLS=ghcr.io/chai0204/lab

# slug  ローカルイメージ  公開名（リポジトリ:タグ）
# 主題1.09 だけは最初に公開した別パッケージ（lab-linuc-services、public 済み）に版を足す。
PAIRS=(
  "linuc-services  lab-linuc-services:1.0.1      ghcr.io/chai0204/lab-linuc-services:1.0.1"
  "linuc-services  lab-linuc-services:1.0.2      ghcr.io/chai0204/lab-linuc-services:1.0.2"
  "linuc-files     lab-linuc-files:1.0.1         $REPO:files-1.0.1"
  "linuc-text      lab-linuc-text:1.0.1          $REPO:text-1.0.1"
  "linuc-shell     lab-linuc-shell:1.0.1         $REPO:shell-1.0.1"
  "linuc-shell     lab-linuc-shell:1.0.2         $REPO:shell-1.0.2"
  "linuc-files     lab-linuc-files:1.0.0         $REPO:files-1.0.0"
  "linuc-text      lab-linuc-text:1.0.0          $REPO:text-1.0.0"
  "linuc-shell     lab-linuc-shell:1.0.0         $REPO:shell-1.0.0"
  "linuc-packages  lab-linuc-packages-deb:1.0.0  $REPO:packages-deb-1.0.0"
  "linuc-packages  lab-linuc-packages-rpm:1.0.0  $REPO:packages-rpm-1.0.0"
  "linuc-packages  lab-linuc-packages-deb:1.0.1  $REPO:packages-deb-1.0.1"
  "linuc-packages  lab-linuc-packages-rpm:1.0.1  $REPO:packages-rpm-1.0.1"
  "linuc-boot      lab-linuc-boot:1.0.0          $REPO:boot-1.0.0"
  "linuc-boot      lab-linuc-boot:1.0.1          $REPO:boot-1.0.1"
  "linuc-disks     lab-linuc-disks:1.0.0         $REPO:disks-1.0.0"
  "linuc-network   lab-linuc-network:1.0.0       $REPO:network-1.0.0"
  "linuc-admin     lab-linuc-admin:1.0.0         $REPO:admin-1.0.0"
  "linuc-security  lab-linuc-security:1.0.0      $REPO:security-1.0.0"
  "linuc-disks     lab-linuc-disks:1.0.1         $REPO:disks-1.0.1"
  "linuc-network   lab-linuc-network:1.0.1       $REPO:network-1.0.1"
  "linuc-admin     lab-linuc-admin:1.0.1         $REPO:admin-1.0.1"
  "linuc-security  lab-linuc-security:1.0.1      $REPO:security-1.0.1"
  "kvm             lab-kvm:1.0.0                 $TOOLS:kvm-1.0.0"
  "qemu            lab-qemu:1.0.0                $TOOLS:qemu-1.0.0"
  "docker          lab-docker:1.0.0              $TOOLS:docker-1.0.0"
  "podman          lab-podman:1.0.0              $TOOLS:podman-1.0.0"
  # 2026-10-20: 全イメージの最上段に最新の lab（課題文の見出し・lab show）を重ねた版
  "linuc-services  lab-linuc-services:1.0.3      ghcr.io/chai0204/lab-linuc-services:1.0.3"
  "linuc-files     lab-linuc-files:1.0.2         $REPO:files-1.0.2"
  "linuc-text      lab-linuc-text:1.0.2          $REPO:text-1.0.2"
  "linuc-shell     lab-linuc-shell:1.0.3         $REPO:shell-1.0.3"
  "linuc-shell     lab-linuc-shell:1.0.4         $REPO:shell-1.0.4"
  "linuc-boot      lab-linuc-boot:1.0.2          $REPO:boot-1.0.2"
  "linuc-network   lab-linuc-network:1.0.2       $REPO:network-1.0.2"
  "linuc-admin     lab-linuc-admin:1.0.2         $REPO:admin-1.0.2"
  "linuc-security  lab-linuc-security:1.0.2      $REPO:security-1.0.2"
  "kvm             lab-kvm:1.0.1                 $TOOLS:kvm-1.0.1"
  "qemu            lab-qemu:1.0.1                $TOOLS:qemu-1.0.1"
  "docker          lab-docker:1.0.1              $TOOLS:docker-1.0.1"
  "podman          lab-podman:1.0.1              $TOOLS:podman-1.0.1"
  # sqlite と wasm は、シリーズで最初に公開した別パッケージ（lab-sqlite・lab-wasm）に版を足す
  "sqlite          lab-sqlite:1.0.1              ghcr.io/chai0204/lab-sqlite:1.0.1"
  "wasm            lab-wasm:1.0.1                ghcr.io/chai0204/lab-wasm:1.0.1"
  # 2026-10-20: 初学者が順を追えるように作り直した 1.04 と 1.05
  "linuc-packages  lab-linuc-packages-deb:1.1.0  $REPO:packages-deb-1.1.0"
  "linuc-packages  lab-linuc-packages-rpm:1.1.0  $REPO:packages-rpm-1.1.0"
  "linuc-packages  lab-linuc-packages-deb:1.1.1  $REPO:packages-deb-1.1.1"
  "linuc-packages  lab-linuc-packages-rpm:1.1.1  $REPO:packages-rpm-1.1.1"
  "linuc-disks     lab-linuc-disks:1.1.0         $REPO:disks-1.1.0"
)

for line in "${PAIRS[@]}"; do
  read -r slug local ref <<<"$line"
  [ "$ONLY" = "  " ] || [[ "$ONLY" == *" $slug "* ]] || continue
  [ -d "public/$slug" ] || { echo "· $slug: まだ無い"; continue; }
  grep -rq "$ref@sha256:__DIGEST__" "public/$slug" || { echo "· $ref: 本文に __DIGEST__ の参照が無い（済みか未着手）"; continue; }
  docker image inspect "$local" >/dev/null 2>&1 || { echo "✗ $slug: ローカルイメージ $local が無い"; exit 1; }
  if [ "$DRY" = 1 ]; then echo "push $local → $ref"; continue; fi
  docker tag "$local" "$ref"
  docker push -q "$ref" >/dev/null
  dg=$(docker buildx imagetools inspect "$ref" --format '{{json .Manifest}}' | jq -r '.digest')
  [[ "$dg" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "✗ $ref のダイジェストが取れない: $dg"; exit 1; }
  dirs=("public/$slug"); [ -d "probe/$slug-tpl" ] && dirs+=("probe/$slug-tpl")
  n=$(grep -rl "$ref@sha256:__DIGEST__" "${dirs[@]}" | wc -l)
  grep -rl "$ref@sha256:__DIGEST__" "${dirs[@]}" | xargs -r sed -i "s#$ref@sha256:__DIGEST__#$ref@$dg#g"
  echo "✔ $ref@$dg（$n ファイルを置き換え）"
done
# 全部置き換え済みだと grep は 1 を返す。pipefail で黙って止まらないようにする
left=$( (grep -rl '__DIGEST__' public || true) | wc -l)
echo "残りの __DIGEST__: $left ファイル"
if [ "$DRY" = 0 ]; then
  have=(); for s in "$@"; do if [ -d "public/$s" ]; then have+=("$s"); fi; done
  if [ $# -eq 0 ] || [ ${#have[@]} -gt 0 ]; then node tools/ghcr-anon-check.mjs "${have[@]}"; fi
fi
