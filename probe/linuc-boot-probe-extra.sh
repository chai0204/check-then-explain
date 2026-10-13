#!/bin/bash
# linuc-boot の補足記録。LinuC 公式例題（linuc.org/study/samples）の監査で、本文に記録の無かった書き方を撮る。
#   本体の probe（linuc-boot-probe.sh）が終わった後のコンテナ（linuc-boot-probe）で走らせる。ホストで実行する。
#     bash probe/linuc-boot-probe-extra.sh
#       → logs/linuc-boot-02b-extra.log（ssh の -i・-p・-l）
#         logs/linuc-boot-08b-extra.log（ps の -f・f・-A・e、kill の書き方、killall と長い名前）
#         logs/linuc-boot-09b-extra.log（fg 2 と fg %1）
#         logs/linuc-boot-07b-destroy.log（電源を抜いた次の起動と、再起動の記録。最後に練習機を destroy・reboot する）
set -u
cd /home/shun/learning-labs || exit 1
export C=linuc-boot-probe
. probe/linuc-boot-lib.sh
L() { printf 'logs/linuc-boot-%s.log' "$1"; }
start_log() { : > "$(L "$1")"; S "$(L "$1")" "$2"; }
wait_agent 400; wait_system 200
tm_close a; tm_open a 120 50; tm_type a "PS1='\$ '"; tm_wait_last a '^\$$' 10; tm_fresh a
tm_close g; tm_open g 120 50; tm_type g "PS1='\$ '"; tm_wait_last g '^\$$' 10; tm_login g; tm_fresh g

# ---- 第2章: ~/.ssh/config の Host linuc がしていることを、オプションで書く ---------------
start_log 02b-extra "第2章の補足 ssh の -i・-p・-l（[8202]）"
tm_run a 'cat ~/.ssh/config'
tm_run a 'ssh -i ~/.ssh/id_rsa -p 2222 -l student 127.0.0.1 hostname'
tm_run a 'ssh -i ~/.ssh/id_rsa -p 2222 student@127.0.0.1 hostname'
tm_run a "ssh -v -i ~/.ssh/id_rsa -p 2222 -l student 127.0.0.1 true 2>&1 | grep -E 'Connecting to|Offering public key|Authenticated to'"
tm_run a 'ssh -l student 127.0.0.1 hostname'
tm_record a "ssh の -i・-p・-l"

# ---- 第8章 ----------------------------------------------------------------------------------
start_log 08b-extra "第8章の補足 ps の書き方・kill の書き方・killall と長い名前（[5483][3273]）"
tm_run g 'ps -f'
tm_run g 'ps f'
tm_run g 'ps -A | wc -l; ps -e | wc -l'
tm_run g 'ps e -o args= -p $$ | cut -c1-100'
tm_record g "ps -f と ps f（と -A・e）"
tm_fresh g
tm_run g 'sleep 801 &'
tm_run g 'kill -s 15 $!'
tm_run g 'sleep 802 &'
tm_run g 'kill -SIGKILL $!'
tm_run g 'jobs'
tm_record g "kill -s 15 と kill -SIGKILL"
tm_fresh g
tm_run g 'cp /usr/bin/sleep /tmp/very-long-process-name'
tm_run g '/tmp/very-long-process-name 300 &'
tm_run g 'pgrep -l very-long-proce'
tm_run g 'killall very-long-proce; echo "終了コード $?"'
tm_run g 'killall very-long-process-name; echo "終了コード $?"'
tm_run g 'jobs'
tm_record g "killall と長い名前"

# ---- 第9章: ジョブの番号 -----------------------------------------------------------------
start_log 09b-extra "第9章の補足 ジョブの番号の書き方（[1334]）"
tm_fresh g
tm_run g 'sleep 701 &'
tm_run g 'sleep 702 &'
tm_run g 'jobs'
tm_type g 'fg 2'; sleep 1.5; tm_keys g C-c; tm_wait_last g '^\$$' 10
tm_type g 'fg %1'; sleep 1.5; tm_keys g C-c; tm_wait_last g '^\$$' 10
tm_run g 'jobs'
tm_run g 'sleep 703 &'
tm_run g 'kill %1'
tm_run g 'jobs'
tm_record g "fg 2 と fg %1"

# ---- 第7章: 電源を抜いた次の起動（本体の記録では fsck.log を sudo なしで読んで断られたので、撮り直す） --------
#   書いた直後に抜く。ext4 は書いた中身をしばらくメモリに持つので、抜くと残らない。続けて再起動の記録も撮る
start_log 07b-destroy "第7章の補足 電源を抜いた次の起動と、再起動の記録"
tm_fresh g
tm_run g 'echo "抜く前に書いた" > memo.txt; ls -l memo.txt'
W 3
tm_fresh a
before=$(tm_count g 'Connection to 127.0.0.1 closed')
tm_run a 'virsh destroy linuc'
tm_closed_wait g "$before"
tm_run a 'virsh start linuc'
tm_record g "端末1: 書いてすぐに電源を抜かれる"
tm_record a "外: 動いている練習機を destroy して、また起動する"
wait_agent 400; wait_system 200
tm_close g; tm_open g 120 50; tm_type g "PS1='\$ '"; tm_wait_last g '^\$$' 10; tm_login g; tm_fresh g
tm_run g 'sudo cat /run/initramfs/fsck.log'
tm_run g 'ls -l memo.txt; cat memo.txt'
tm_record g "電源を抜かれた次の起動"
tm_fresh g
tm_run g 'cat /proc/sys/kernel/random/boot_id'
tm_leave g 'sudo reboot'
tm_record g "sudo reboot"
wait_agent 400; wait_system 200
tm_close g; tm_open g 120 50; tm_type g "PS1='\$ '"; tm_wait_last g '^\$$' 10; tm_login g; tm_fresh g
tm_run g 'cat /proc/sys/kernel/random/boot_id'
tm_run g 'last -x reboot shutdown | head -8'
tm_record g "reboot の後"

tm_close g; tm_close a
echo "extra done"
