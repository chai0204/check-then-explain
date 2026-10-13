#!/bin/bash
# linuc-boot の全演習を、模範解答どおりに通す。ホストで実行する。目的は2つ。
#   1) 解く前（と、よくある途中の状態）で判定が ✗ を出し、観測した事実を言うこと（鳴らない検査は無いより悪い）
#   2) 模範解答どおりにやれば ✔ になること
#
#   bash probe/linuc-boot-solve-all.sh        → logs/linuc-boot-solve-all.log
#
# 読者と同じ起動オプションで新しいコンテナを作り、読者と同じ対話の端末（ホストの tmux）で打つ。
# 判定（lab check）も読者と同じく外の端末で打つ。
set -u
cd /home/shun/learning-labs || exit 1
IMG=${IMG:-lab-linuc-boot:1.0.1}
RUN=${RUN:-s1}
export C=linuc-boot-solve TMUX_SOCK=linuc-boot-solve   # probe と同時に走らせられるよう tmux を分ける
. probe/linuc-boot-lib.sh
LOG=logs/linuc-boot-solve-all.log
: > "$LOG"
X() { printf '\n\n########## %s ##########\n' "$*" >> "$LOG"; }
chk() { tm_run a "lab check $1; echo \"exit=\$?\"" 180; }

tmux -L "$TMUX_SOCK" kill-server 2>/dev/null
docker rm -f -v "$C" >/dev/null 2>&1
if [ "$RUN" = anon ]; then VOLS=(-v /home/lab/vm -v /home/lab/.lab)
else VOLS=(-v "linuc-boot-$RUN-vm:/home/lab/vm" -v "linuc-boot-$RUN-state:/home/lab/.lab"); fi
docker run -d --name "$C" --hostname host --stop-timeout 30 "${VOLS[@]}" "$IMG" >/dev/null || exit 1
sleep 3
tm_open a 120 50; tm_type a "PS1='\$ '"; tm_wait_last a '^\$$' 10; tm_fresh a

X "A. 何もしていない状態で lab check（01 は ✗、02〜07 は練習機が止まっているので ⚠ 前提不足のはず）"
tm_run a 'lab check; echo "exit=$?"' 300
tm_record a "A"

X "B. 演習01 — 練習機に電源を入れ、自動で起動するようにする"
tm_fresh a
chk 01
tm_run a 'virsh start linuc'
wait_agent 400; wait_provisioned 300; wait_system 200
note "（起動を待った）"
chk 01
tm_run a 'virsh autostart linuc'
chk 01
tm_record a "B"

X "C. 演習02 — RSA の鍵で、パスワードなしで入れるようにする"
tm_fresh a
chk 02
tm_type a 'ssh-keygen -t rsa'
tm_wait_last a 'save the key' 10; tm_keys a Enter
tm_wait_last a 'no passphrase\):$' 10; tm_keys a Enter
tm_wait_last a 'passphrase again:$' 10; tm_keys a Enter
tm_wait_last a '^\$$' 60
chk 02
tm_type a 'ssh-copy-id -i ~/.ssh/id_rsa.pub linuc'
tm_wait_last a 'fingerprint\])\?$' 120; tm_type a 'yes'
tm_wait_last a 'password:$' 60; tm_type a 'student'
tm_wait_last a '^\$$' 60
chk 02
tm_record a "C"

X "D. 演習03 — 次の1回だけ、CUI のターゲットで起動する（GRUB でカーネル引数を足す）"
tm_fresh a
chk 03
tm_close con; tm_open con 80 24; tm_type con "PS1='\$ '"; tm_wait_last con '^\$$' 10; tm_fresh con
tm_type con 'virsh console linuc'; tm_wait con 'Escape character' 15; sleep 1
tm_run a 'ssh linuc sudo reboot' 60
grub_wait_menu 1200
grub_stop
grub_e; sleep 1
grub_add '3'
tm_shot con "演習03: linux の行末に 3 を足した"
tm_keys con C-x
tm_wait_last con 'login:$' 400
tm_keys con C-]; tm_wait_last con '^\$$' 15
wait_agent 400; wait_system 200
note "（起動を待った）"
chk 03
tm_run a 'ssh linuc cat /proc/cmdline'
tm_record a "D"

X "E. 演習04 — 既定のターゲットを変えて、再起動後も CUI にする"
tm_fresh a
tm_run a 'ssh linuc sudo systemctl set-default graphical.target'
note "（演習03 の起動は multi-user なので、普通に起動し直して graphical に戻しておく）"
tm_run a 'ssh linuc sudo reboot' 60
wait_agent 400; wait_system 200
chk 04
tm_run a 'ssh linuc sudo systemctl set-default multi-user.target'
note "（既定を変えただけ。まだ再起動していない）"
chk 04
tm_run a 'ssh linuc sudo reboot' 60
wait_agent 400; wait_system 200
note "（起動を待った）"
chk 04
tm_run a 'ssh linuc runlevel'
tm_record a "E"

X "F. 演習05 — 停止を予約し、ログイン中の人に知らせる"
tm_fresh a
chk 05
tm_run a "ssh linuc 'sudo shutdown -r +30 \"再起動の予定\"'"
note "（電源を切るのではなく再起動の予約を入れてしまった）"
chk 05
tm_run a 'ssh linuc sudo shutdown -c'
tm_run a "ssh linuc 'sudo shutdown -h +30 \"メンテナンスのため停止します\"'"
chk 05
tm_run a 'ssh linuc sudo shutdown -c'
tm_record a "F"

X "G. 演習06 — TERM を無視するプロセスを止める"
tm_fresh a
chk 06
tm_run a "ssh linuc 'kill \$(pgrep -x lab-hog)'"
note "（TERM を送っただけ）"
chk 06
tm_run a "ssh linuc 'kill -KILL \$(pgrep -x lab-hog)'"
chk 06
tm_record a "G"

X "H. 演習07 — 切断しても止まらない処理を残す"
tm_fresh a
chk 07
tm_close b; tm_open b 120 40; tm_type b "PS1='\$ '"; tm_wait_last b '^\$$' 10; tm_fresh b
tm_login b
tm_run b 'lab-count > /dev/null &'
note "（& で動かし、ssh はつないだまま）"
chk 07
tm_cut b
sleep 2
note "（~. で切断した）"
chk 07
tm_login b
tm_type b 'nohup lab-count &'; sleep 2.5; tm_keys b Enter; tm_wait_last b '^\$$' 10
tm_cut b
sleep 2
chk 07
tm_record b "H: 端末2（練習機の中で lab-count を動かした側）"
tm_record a "H"

X "J. レスキュー／緊急モードの間と、戻った後に、判定が動くか（判定の通り道 qemu-guest-agent。コースの provision で multi-user.target に結びつけた）"
boot_with() {  # boot_with 足す語 — 練習機を再起動し、GRUB で linux の行に語を足して起動する
  tm_run a 'ssh linuc sudo reboot' 60
  grub_wait_menu 1200; grub_stop; grub_e; sleep 1; grub_add "$1"
  tm_keys con C-x
}
tm_close con; tm_open con 80 24; tm_type con "PS1='\$ '"; tm_wait_last con '^\$$' 10; tm_fresh con
tm_type con 'virsh console linuc'; tm_wait con 'Escape character' 15; sleep 1
tm_fresh a
boot_with single
tm_wait con 'You are in rescue mode' 400; sleep 5
note "（single で起動し、レスキューの案内で止まっている間。udev が qemu-guest-agent を起こすので、判定は ✗ か ✔ になるはず）"
chk 03
tm_keys con Enter; sleep 3
tm_type con 'exit'
tm_wait_last con 'login:$' 400
wait_agent 120 || note "（エージェントが 120 秒たっても応答しない）"
note "（レスキューのシェルを exit で抜け、既定のターゲットまで起動した後。判定は ✗ か ✔ で、⚠ ではないはず）"
chk 03
boot_with emergency
tm_wait con 'You are in emergency mode' 400; sleep 5
note "（emergency で起動し、緊急モードの案内で止まっている間。ここでもエージェントは udev が起こすので、判定は ✗ のはず）"
chk 03
note "（緊急モードの案内は、この練習機のシリアルコンソールでは Enter を受け付けなかった（2026-10-13 の別の回で実測）。外から電源を入れ直して戻す）"
tm_keys con C-]; tm_wait_last con '^\$$' 15
tm_run a 'virsh destroy linuc'
tm_run a 'virsh start linuc'
wait_agent 400; wait_system 200
note "（電源を入れ直し、普通に起動した後）"
chk 03
tm_record a "J"
tm_record con "J: 練習機のコンソール"

X "I. 全部終えた後"
tm_fresh a
tm_run a 'lab ls'
tm_run a 'lab'
tm_record a "I"

tmux -L "$TMUX_SOCK" kill-server 2>/dev/null
docker rm -f -v "$C" >/dev/null 2>&1
echo "solve-all done"
