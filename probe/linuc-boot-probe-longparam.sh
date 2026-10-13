#!/bin/bash
# linuc-boot 第6章の補足記録: GRUB の編集画面（シリアル 80 桁）で、長いカーネル引数（systemd.unit=rescue.target）を足したときの記録。
#   以前の探索で、折り返しのところで引数が崩れたことがあったので撮った。2026-10-13 の本番では崩れずに rescue.target に入った。
#   本体の probe（linuc-boot-probe.sh）が終わった後のコンテナ（linuc-boot-probe）で走らせる。ホストで実行する。
#     bash probe/linuc-boot-probe-longparam.sh      → logs/linuc-boot-06b-longparam.log
#   linux の行の2段目は 56 文字で、残りは 20 桁ほど。systemd.unit=rescue.target（27 文字）は折り返して表示される。
set -u
cd /home/shun/learning-labs || exit 1
export C=linuc-boot-probe
. probe/linuc-boot-lib.sh
LOG=logs/linuc-boot-06b-longparam.log
: > "$LOG"
S "$LOG" "第6章の補足 長いカーネル引数を足したとき（GRUB の編集画面・80 桁で折り返す）"
ensure() { wait_agent 400; wait_system 200; }
tm_close con; tm_open con 80 24; tm_type con "PS1='\$ '"; tm_wait_last con '^\$$' 10; tm_fresh con
tm_type con 'virsh console linuc'; tm_wait con 'Escape character' 15; sleep 1
tm_close a; tm_open a 120 50; tm_type a "PS1='\$ '"; tm_wait_last a '^\$$' 10; tm_fresh a
ensure
tm_run a 'virsh reboot linuc'
grub_wait_menu 1200
grub_stop
grub_e; sleep 1
grub_add 'systemd.unit=rescue.target'
tm_shot con "linux の行末に systemd.unit=rescue.target を足した（折り返す）"
tm_keys con C-x
tm_wait_last con 'login:$|continue\):$' 400
sleep 2
tm_shot con "起動した結果"
# rescue.target に入ったら（2026-10-13 の本番の記録はこちら）: Enter で root のシェル → 引数を確かめる → exit で既定のターゲットへ
if tm_screen con | grep -q 'rescue mode'; then
  tm_keys con Enter; sleep 3
  tm_type con 'cat /proc/cmdline; systemctl is-active rescue.target'; tm_wait_last con '#$' 30; sleep 1
  tm_shot con "Enter を押した後（rescue.target の root のシェル）"
  tm_type con 'exit'
  tm_wait_last con 'login:$' 400
  sleep 2
fi
ensure
tm_keys con C-]; sleep 1
"${TM[@]}" kill-server 2>/dev/null
echo "longparam done"
