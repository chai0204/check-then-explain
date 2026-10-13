#!/usr/bin/env bash
# 起動前の準備（vm が定義・起動の前に、外側で lab として呼ぶ。環境変数 VMDIR）。
#
# 練習機の差分（$VMDIR/linuc.qcow2）の参照先を、docker・podman 入りのディスク（ctr-guest.qcow2）に載せ替える。
#
#   vm は差分を作るとき、参照先を土台 /var/lib/lab-vm/linuc-guest.qcow2 に決め打ちしている。
#   この檻では、その上に docker・podman を入れた差分 ctr-guest.qcow2 があるので、読者の差分はその上に重ねたい:
#       読者の差分 linuc.qcow2 → ctr-guest.qcow2（docker・podman・イメージ）→ linuc-guest.qcow2（練習機の土台）
#   作った直後の差分（中身がまだ1つも書かれていない）だけを、中身を写さずに参照先だけ書き換える（rebase -u）。
#   中身が空なので、練習機から見えるディスクは ctr-guest.qcow2 そのものになる。
#   一度でも書かれた差分は触らない（書かれた後に参照先を変えると、見える中身が壊れる）。
#   vm reset --yes は差分を消して作り直すので、そのときもここでもう一度載せ替わる。
set -euo pipefail
D="$VMDIR/linuc.qcow2"
OLD=/var/lib/lab-vm/linuc-guest.qcow2
NEW=/var/lib/lab-vm/ctr-guest.qcow2
[ -f "$D" ] || exit 0
# -U: 練習機が動いている間（ロックされている）でも読むだけなら読める
cur=$(qemu-img info -U --output=json "$D" | jq -r '."backing-filename" // ""')
[ "$cur" = "$OLD" ] || exit 0
written=$(qemu-img map -U --output=json "$D" | jq '[.[] | select(.depth == 0 and .data == true)] | length')
if [ "$written" != 0 ]; then
  echo "pre-start: $D は土台の上で既に使われているので、載せ替えません" >&2
  exit 0
fi
qemu-img rebase -u -F qcow2 -b "$NEW" "$D"
