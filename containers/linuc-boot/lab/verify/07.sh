#!/usr/bin/env bash
# 演習 07 の判定。観測型（lab-count のプロセスを練習機の中で探し、親をたどり、HUP の扱いをカーネルの記録で見る）。
#   生き残れるかは「SIGHUP を無視しているか（/proc/PID/status の SigIgn の最下位ビット）」か
#   「tmux / screen の中にいるか（親をたどる）」で決まる。ssh のセッションの子のままなら、まだ確かめられない。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値（system）に引きずられないよう固定する

lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機の中から応答がありません（電源が切れている・起動の途中・systemd を通らない起動（init=/bin/bash など）のどれか）。virsh domstate linuc と virsh console linuc で状態を見てください"; exit 2; }

# 練習機の中で走らせる調査。1行に1プロセス: PID|状態|HUPを無視|tmux/screenの中|sshの子|親のたどり
inspect='
for p in $( { pgrep -u student -x lab-count; pgrep -u student -f "^(/usr/bin/|/bin/)?(ba)?sh (/usr/local/bin/)?lab-count"; } | sort -un ); do
  st=$(ps -o stat= -p "$p" | tr -d " "); [ -n "$st" ] || continue
  ign=$(awk "/^SigIgn/{print \$2}" /proc/$p/status)
  hup=$(( 0x$ign & 1 ))
  q=$p; mux=0; ssh=0; chain=$(ps -o comm= -p "$p")
  while :; do
    q=$(ps -o ppid= -p "$q" | tr -d " "); { [ -n "$q" ] && [ "$q" -ge 1 ]; } || break
    a=$(ps -o args= -p "$q"); c=$(ps -o comm= -p "$q")
    case "$c" in tmux*|screen|SCREEN) mux=1 ;; esac
    case "$a" in "sshd: student"*) ssh=1 ;; SCREEN*) mux=1 ;; esac
    chain="$chain ← $c"
    [ "$q" = 1 ] && break
  done
  echo "$p|$st|$hup|$mux|$ssh|$chain"
done'
rows=$(lab-guest "$inspect" 2>/dev/null)

echo "判定 : 観測型（lab-count のプロセスを探し、親をたどり、SIGHUP を無視しているかを /proc で見た）"
if [ -z "$rows" ]; then
  echo "観測 : student の lab-count が1つも動いていない"
  exit 1
fi
ok=0
while IFS='|' read -r pid st hup mux ssh chain; do
  echo "観測 : PID $pid（状態 $st）  親をたどると: $chain"
  echo "       SIGHUP を無視 → $([ "$hup" = 1 ] && echo している || echo していない)" \
       " / tmux・screen の中 → $([ "$mux" = 1 ] && echo いる || echo いない)" \
       " / ssh のセッションの子 → $([ "$ssh" = 1 ] && echo まだそう || echo もう違う)"
  case "$st" in T*) echo "       → 一時停止している（T）"; continue ;; esac
  if [ "$hup" != 1 ] && [ "$mux" != 1 ]; then
    if [ "$ssh" = 1 ]; then echo "       → 回線が切れたら SIGHUP が届き、止まる側にいる"
    else echo "       → いまは動いているが、SIGHUP を受けたら止まる（tmux・screen の中でもない）"; fi
    continue
  fi
  if [ "$ssh" = 1 ]; then
    echo "       → 生き残る準備はできているが、まだ ssh のセッションの子（切断した後の姿をまだ確かめていない）"
    continue
  fi
  ok=1
done <<<"$rows"
[ "$ok" = 1 ] || exit 1

echo "       ssh のセッションが終わった後も、SIGHUP に耐える形で動き続けている"
exit 0
