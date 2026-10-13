#!/usr/bin/env bash
# 演習 03 の判定。観測型（~/work/03/linuc.qcow2 の中のスナップショットの表を qemu-img で読む。練習機を止めたかは、
# そのファイルを開いているプロセスがいるかを /proc で見る）。
#   savevm で取ったものは「動いている状態（メモリ・CPU）」の大きさ（vm-state-size）を持つ。
#   qemu-img snapshot -c で取ったものはディスクの中身だけで、この大きさは 0 になる。
#   savevm は動いている状態を、書き込める qcow2 のうち -drive で先に並べた1つにだけ入れる（UEFI の NVRAM を qcow2 にして
#   ディスクより先に並べると、そちらに入る）。ほかの qcow2 には、同じ名前・同じ時刻（date と vm-clock）で 0 の印だけが付く。
#   ディスクの側が 0 でも、~/work/03 の別の qcow2 に、同じ名前・同じ時刻で状態が入っていれば、同じ1回の savevm で取ったものとみなす
#   （時刻まで見るのは、別に取った無関係のスナップショットを拾わないため）。
#   ログインしたかどうかは、ファイルからは見分けられないので見ない。
set -uo pipefail
command -v qemu-img >/dev/null && command -v jq >/dev/null || { echo "前提不足: qemu-img か jq が見つかりません"; exit 2; }
BASE=/var/lib/lab-vm/linuc-guest.qcow2
W=$HOME/work/03
f=$W/linuc.qcow2
TAG=loggedin

echo "判定 : 観測型（~/work/03/linuc.qcow2 のスナップショットの表を qemu-img info で読み、開いているプロセスを /proc で探した）"
if [ ! -f "$f" ]; then
  echo "観測 : ~/work/03/linuc.qcow2 が無い"
  exit 1
fi
info=$(qemu-img info -U --output=json "$f" 2>&1) || { echo "観測 : qemu-img info が読めない: $info"; exit 1; }
back=$(jq -r '."full-backing-filename" // ."backing-filename" // ""' <<<"$info")
nsnap=$(jq '[.snapshots // [] | .[]] | length' <<<"$info")
vss=$(jq -r --arg t "$TAG" '[.snapshots // [] | .[] | select(.name == $t)][0]."vm-state-size" // "none"' <<<"$info")
# そのスナップショットを取った時刻（日時と、練習機の時計）。1回の savevm は、全部の qcow2 に同じ値を書く
stamp() { jq -r --arg t "$TAG" '[.snapshots // [] | .[] | select(.name == $t)][0] | if . == null then "" else "\(."date-sec") \(."date-nsec") \(."vm-clock-sec") \(."vm-clock-nsec")" end'; }
fstamp=$(stamp <<<"$info")
# ~/work/03 の中で、このファイルを開いているプロセス
users=$(for d in /proc/[0-9]*; do
          for fd in "$d"/fd/*; do [ "$(readlink "$fd" 2>/dev/null)" = "$f" ] && { echo "${d#/proc/}"; break; }; done
        done 2>/dev/null | paste -sd' ')
# 状態がほかの qcow2 に入っていないか（savevm は書き込める qcow2 の1つにだけ状態を入れる）
elsewhere=""; else_vss=0; mismatch=""
if [ "$vss" != none ] && [ "$vss" -le 0 ]; then
  for g in "$W"/*.qcow2; do
    [ "$g" = "$f" ] && continue
    gi=$(qemu-img info -U --output=json "$g" 2>/dev/null) || continue
    v=$(jq -r --arg t "$TAG" '[.snapshots // [] | .[] | select(.name == $t)][0]."vm-state-size" // 0' <<<"$gi")
    [ "${v:-0}" -gt 0 ] || continue
    if [ "$(stamp <<<"$gi")" = "$fstamp" ]; then
      elsewhere=$g; else_vss=$v; break
    fi
    mismatch=$g
  done
fi

echo "観測 : 土台（backing file）→ ${back:-なし}"
echo "       スナップショット → ${nsnap} 個"
jq -r '.snapshots // [] | .[] | "         \(.name)  動いている状態 \(."vm-state-size") バイト"' <<<"$info"
[ -n "$elsewhere" ] && echo "       ${elsewhere/#$HOME/\~} の $TAG → 動いている状態 $else_vss バイト（linuc.qcow2 の $TAG と同じ時刻）"
[ -z "$elsewhere" ] && [ -n "$mismatch" ] && echo "       ${mismatch/#$HOME/\~} にも $TAG があるが、linuc.qcow2 の $TAG とは取った時刻が違う（別に取ったもの）"
echo "       ~/work/03/linuc.qcow2 を開いているプロセス → ${users:-いない}"

ng=0
[ "$back" = "$BASE" ] || { echo "       → 土台が $BASE ではない（差分ディスクになっていない）"; ng=1; }
if [ "$vss" = none ]; then
  echo "       → $TAG という名前のスナップショットが無い"; ng=1
elif [ "$vss" -le 0 ] && [ -z "$elsewhere" ]; then
  echo "       → $TAG はディスクの中身だけで、動いている状態（メモリ）が入っていない"; ng=1
fi
[ -z "$users" ] || { echo "       → まだ QEMU が開いている（練習機を止めてから判定する）"; ng=1; }
[ "$ng" = 0 ] || exit 1

if [ -n "$elsewhere" ]; then
  echo "       $TAG の動いている状態は ${elsewhere/#$HOME/\~} に $((else_vss / 1024 / 1024)) MiB 入っている（savevm は状態を、-drive で先に並べた書き込める qcow2 の1つにだけ入れる）"
else
  echo "       $TAG は動いている状態を $((vss / 1024 / 1024)) MiB 持っている（メモリの中身が qcow2 の中に入った）"
fi
echo "       → loadvm $TAG で、保存した瞬間の続きに戻れる（ログインしてから保存していれば、ログインした直後に）"
exit 0
