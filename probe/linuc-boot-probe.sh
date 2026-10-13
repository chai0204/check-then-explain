#!/bin/bash
# LinuC 主題1.01（linuc-boot）理論編 第1〜10章の端末表示の出どころ。ホストで実行する。
#
#   bash probe/linuc-boot-probe.sh            # 新しいコンテナで第0章から最後まで
#   FROM=5 bash probe/linuc-boot-probe.sh     # 既にあるコンテナで第5章から（調整用。最終の記録は通しで取る）
#
# 読者と同じ起動オプション（--hostname host --stop-timeout 30、名前付きボリューム2つ）で外側のコンテナを作り、
# 読者が第1章から順に打つのと同じ順序で打つ。状態（鍵・known_hosts・NVRAM・既定のターゲット）は章をまたいで持ち越す。
#
# 端末は読者と同じ条件にする（2026-10-13 の取り決め）:
#   - 外（lab@host）も練習機の中（student@linuc）も、ホストの tmux が開いた「対話の端末」で打つ。
#     外は docker exec -it … bash -l、練習機は その中で ssh linuc（TERM=xterm、~/.bashrc の alias が効く）。
#   - 画面に出た文字を tmux が描いたまま写す（制御文字は入らない）。端末の幅は 120 桁、コンソールは 80x24。
#   - プロンプトは本文に合わせて PS1='$ ' にしている（実物は lab@host:~$ / student@linuc:~$）。
#   - 1行打つたびにプロンプトが戻るのを待ってから次を打つ（先打ちで画面が混ざらないように）。
# ログは章ごとに logs/linuc-boot-NN-*.log へ書く（logs/linuc-boot-*.log が照合の対象）。
set -u
cd /home/shun/learning-labs || exit 1
IMG=${IMG:-lab-linuc-boot:1.0.0}
RUN=${RUN:-p1}
FROM=${FROM:-0}
ONLY=${ONLY:-}           # ONLY=4 → 第4章だけを、既にあるコンテナで取り直す（状態を変えない章の撮り直し用）
[ -n "$ONLY" ] && FROM=$ONLY
export C=linuc-boot-probe
. probe/linuc-boot-lib.sh

L() { printf 'logs/linuc-boot-%s.log' "$1"; }
want() { [ "$FROM" -le "$1" ] && { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }; }
start_log() { : > "$(L "$1")"; S "$(L "$1")" "$2"; }   # 章のログを空にして見出しを書く
ensure_up() { wait_agent 400; wait_system 200; }
guest_shell() {  # 端末 g を開いて練習機に入る（鍵で入れる前提。第2章以降）
  tm_close g; tm_open g 120 50; tm_type g "PS1='\$ '"; tm_wait_last g '^\$$' 10
  tm_login g; tm_fresh g
}
outer_shell() {  # 端末 a（外）を開き直す
  tm_close a; tm_open a 120 50; tm_type a "PS1='\$ '"; tm_wait_last a '^\$$' 10; tm_fresh a
}
console_attach() {  # 端末 con（80x24）で virsh console につなぐ
  tm_close con; tm_open con 80 24; tm_type con "PS1='\$ '"; tm_wait_last con '^\$$' 10; tm_fresh con
  tm_type con 'virsh console linuc'; tm_wait con 'Escape character' 15; sleep 1
}
console_detach() { tm_keys con C-]; tm_wait_last con '^\$$' 15; }

if [ "$FROM" -le 0 ]; then
  tmux -L linuc-boot kill-server 2>/dev/null
  docker rm -f -v "$C" >/dev/null 2>&1
  # RUN=anon は調整用（名無しのボリューム。docker rm -v で一緒に消える）。最終の記録は名前付き（読者と同じ形）で取る
  if [ "$RUN" = anon ]; then VOLS=(-v /home/lab/vm -v /home/lab/.lab)
  else VOLS=(-v "linuc-boot-$RUN-vm:/home/lab/vm" -v "linuc-boot-$RUN-state:/home/lab/.lab"); fi
  docker run -d --name "$C" --hostname host --stop-timeout 30 "${VOLS[@]}" "$IMG" >/dev/null || exit 1
  sleep 3

  # ===================================================================================
  start_log 00-env "0. 環境（検証環境ブロックの版の出どころ）と、入ったときの表示"
  tm_open a 120 50
  tm_record a "docker exec -it lab-linuc-boot bash -l で入ったときの表示"
  tm_type a "PS1='\$ '"; tm_wait_last a '^\$$' 10; tm_fresh a
  tm_run a 'lab env'
  tm_run a 'lab ls'
  tm_record a "lab env / lab ls（練習機はまだ電源が入っていない）"
fi

# =====================================================================================
if want 1; then
  start_log 01-virsh "第1章 virsh が触れるのは、電源とボタンだけ（1.01.2）"
  [ "$FROM" -eq 1 ] && outer_shell
  tm_fresh a
  tm_run a 'virsh list'
  tm_run a 'virsh list --all'
  tm_run a 'virsh dominfo linuc'
  tm_run a "virsh dumpxml linuc | grep -E '<domain|<memory|<vcpu|<os|<loader|<nvram|<source file|<target dev|<serial|<console'"
  tm_run a 'ls -l ~/vm'
  tm_run a "qemu-img info ~/vm/linuc.qcow2 | grep -E '^(image|file format|virtual size|backing file):'"
  tm_record a "定義はあるが、電源が入っていない"

  # 端末 con で電源を入れ、そのまま画面（シリアルコンソール）を見る
  tm_close con; tm_open con 80 24; tm_type con "PS1='\$ '"; tm_wait_last con '^\$$' 10; tm_fresh con
  tm_type con 'virsh start linuc --console'
  sleep 1.5
  tm_fresh a
  tm_run a 'virsh domstate linuc'
  tm_run a "virsh qemu-agent-command linuc '{\"execute\":\"guest-ping\"}'"
  tm_record a "電源を入れた直後（もう1つの端末で）"
  tm_wait_last con 'login:$' 400
  sleep 2
  tm_record con "初めての起動（virsh start linuc --console）"
  tm_fresh a
  tm_run a "virsh qemu-agent-command linuc '{\"execute\":\"guest-ping\"}'"
  tm_record a "login: が出た後"

  # コンソールでログインする（物理的な画面とキーボードの代わり）
  "${TM[@]}" clear-history -t con
  tm_type con 'student'; tm_wait_last con 'Password:$' 30
  tm_type con 'student'; tm_wait_last con 'student@linuc:~\$$' 60
  tm_type con 'tty'; sleep 2
  tm_type con 'who'; sleep 2
  tm_keys con C-d; tm_wait_last con 'login:$' 30
  sleep 1
  tm_record con "コンソールでログインして、Ctrl+D で出る"
  console_detach

  # 起動し終わってから virsh shutdown
  wait_provisioned 300; ensure_up
  tm_fresh a
  t0=$(date +%s%3N)
  tm_run a 'virsh shutdown linuc'
  tm_run a 'virsh domstate linuc'
  wait_off 180; t1=$(date +%s%3N)
  tm_run a 'virsh domstate linuc --reason'
  tm_record a "virsh shutdown（起動し終わってから）"
  note "virsh shutdown を打ってから shut off になるまで、約 $(( (t1 - t0) / 1000 )) 秒（1秒ごとに状態を見た）"

  # ふつうこう考える: GRUB のメニューが出ている間に virsh shutdown を送る
  tm_fresh con
  tm_type con 'virsh start linuc --console'
  grub_wait_menu 1200
  tm_shot con "GRUB のメニュー（数え下げ中）"
  tm_fresh a
  tm_run a 'virsh shutdown linuc'
  tm_run a 'virsh domstate linuc'
  tm_record a "GRUB の間に virsh shutdown を送った"
  # 起動はそのまま進むか、止まるか。どちらでも記録する（探索で4回試し、4回とも止まらなかった）
  for i in $(seq 1 1600); do
    tm_last con | grep -qE 'login:$' && break
    [ "$(vm_state)" = "shut off" ] && break
    sleep 0.25
  done
  sleep 20
  note "ログインの案内が出てから 20 秒待った後の状態: $(vm_state)"
  tm_record con "GRUB の間に shutdown を送った後のコンソール"
  tm_fresh a
  tm_run a 'virsh domstate linuc --reason'
  tm_record a "ログインの案内が出た後"
  console_detach
  [ "$(vm_state)" = running ] || { h 'virsh start linuc' >/dev/null; }
  ensure_up

  # virsh destroy（電源を抜く）
  tm_fresh a
  tm_run a 'virsh destroy linuc'
  tm_run a 'virsh domstate linuc --reason'
  tm_record a "virsh destroy"

  # 自動起動の印
  tm_fresh a
  tm_run a 'virsh autostart linuc'
  tm_run a 'virsh dominfo linuc | grep Autostart'
  tm_run a 'ls -l ~/.config/libvirt/qemu/autostart/'
  tm_run a 'virsh start linuc'
  tm_record a "自動起動の印と、もう一度電源を入れる"

  # コンソールの取り合い（端末を閉じてしまった）
  tm_close b; tm_open b 120 40; tm_type b "PS1='\$ '"; tm_wait_last b '^\$$' 10
  tm_type b 'virsh console linuc'; tm_wait b 'Escape character' 15; sleep 2
  tm_close b                      # Ctrl+] を押さずに端末の窓を閉じた
  sleep 2
  tm_fresh con
  tm_run con 'virsh console linuc' 20
  tm_type con 'virsh console --force linuc'; tm_wait con 'Escape character' 15; sleep 2
  console_detach
  tm_record con "コンソールの取り合い"
  ensure_up
fi

# =====================================================================================
if want 2; then
  start_log 02-ssh "第2章 入れるかどうかは、受け取る側のファイルが決める（1.01.1）"
  [ "$FROM" -eq 2 ] && outer_shell
  tm_fresh a
  tm_run a 'ls -la ~/.ssh'
  tm_run a 'cat ~/.ssh/config'
  tm_type a 'ssh linuc'
  tm_wait_last a 'fingerprint\])\?$' 120; tm_type a 'yes'
  tm_wait_last a 'password:$' 30; tm_type a 'student'
  tm_wait_last a 'student@linuc:~\$$' 60
  tm_leave a 'exit'
  tm_run a 'cut -c1-60 ~/.ssh/known_hosts'
  tm_run a "ssh-keygen -F '[127.0.0.1]:2222' | cut -c1-60"
  tm_run a 'ssh-keygen -F linuc; echo "終了コード $?"'
  tm_record a "初めての ssh（ホスト鍵の確認とパスワード）"

  # ふつうこう考える: ssh-keygen は id_rsa を作る
  tm_fresh a
  tm_type a 'ssh-keygen'
  tm_wait_last a 'save the key' 10; tm_keys a Enter
  tm_wait_last a 'no passphrase\):$' 10; tm_keys a Enter
  tm_wait_last a 'passphrase again:$' 10; tm_keys a Enter
  tm_wait_last a '^\$$' 30
  tm_run a 'ls -l ~/.ssh'
  tm_record a "ssh-keygen（何も付けずに）"
  tm_fresh a
  tm_type a 'ssh-keygen -t rsa'
  tm_wait_last a 'save the key' 10; tm_keys a Enter
  tm_wait_last a 'no passphrase\):$' 10; tm_keys a Enter
  tm_wait_last a 'passphrase again:$' 10; tm_keys a Enter
  tm_wait_last a '^\$$' 60
  tm_run a 'ls -l ~/.ssh'
  tm_run a 'ssh-keygen -lf ~/.ssh/id_rsa.pub'
  tm_run a 'ssh-keygen -lf ~/.ssh/id_ed25519.pub'
  tm_record a "ssh-keygen -t rsa"

  # 公開鍵を渡す
  tm_fresh a
  tm_type a 'ssh-copy-id -i ~/.ssh/id_rsa.pub linuc'
  tm_wait_last a 'password:$' 60; tm_type a 'student'
  tm_wait_last a '^\$$' 60
  tm_login a
  tm_run a 'ls -la ~/.ssh'
  tm_run a 'cut -c1-60 ~/.ssh/authorized_keys'
  tm_leave a 'exit'
  tm_run a "ssh -v linuc true 2>&1 | grep -E 'identity file /home/lab/.ssh/id_[a-z0-9_]+ type|Offering|Authenticated'"
  tm_record a "鍵を登録して、パスワードなしで入る"

  # 受け取る側が鍵を断る（authorized_keys の権限）
  #   group に書ける（664）だけなら、グループの中身が本人だけなので sshd は通す（OpenSSH の判断。実測）。
  #   other に書ける（666）と断り、パスワードを聞いてくる。
  tm_fresh a
  tm_run a "ssh linuc 'id; chmod 664 ~/.ssh/authorized_keys; ls -l ~/.ssh/authorized_keys'"
  tm_run a "ssh linuc 'echo 鍵で入れた; getent group student'"
  tm_run a "ssh linuc 'chmod 666 ~/.ssh/authorized_keys; ls -l ~/.ssh/authorized_keys'"
  tm_type a 'ssh linuc'
  tm_wait_last a 'password:$' 60; tm_type a 'student'
  tm_wait_last a 'student@linuc:~\$$' 60; tm_type a "PS1='\$ '"; tm_wait_last a '^\$$' 10
  tm_run a "sudo journalctl -u ssh --no-pager -n 30 | grep -E 'refused|Accepted'"
  tm_run a 'chmod 600 ~/.ssh/authorized_keys'
  tm_leave a 'exit'
  tm_run a "ssh linuc 'ls -l ~/.ssh/authorized_keys'"
  tm_record a "authorized_keys が他人に書けると、鍵は使われない"

  # 抜け方: logout / exit / Ctrl+D
  tm_fresh a
  tm_login a
  tm_run a 'shopt login_shell'
  tm_type a 'bash'; tm_wait_last a 'student@linuc:~\$$' 15
  tm_type a 'shopt login_shell'; sleep 1; tm_wait_last a 'student@linuc:~\$$' 15
  tm_type a 'logout'; sleep 1; tm_wait_last a 'student@linuc:~\$$' 15
  tm_type a 'exit'; tm_wait_last a '^\$$' 15
  tm_leave_keys a C-d
  tm_run a "ssh linuc 'hostname; shopt login_shell'"
  tm_record a "logout・exit・Ctrl+D"
fi

# =====================================================================================
if want 3; then
  start_log 03-container "第3章 コンテナの中のカーネルは、ホストのもの（1.01.2）"
  [ "$FROM" -eq 3 ] && outer_shell
  tm_fresh a
  for c in 'uname -r' 'uname -v' 'grep PRETTY_NAME /etc/os-release' 'ps -p 1 -o pid,comm' 'nproc' 'free -m | head -2' \
           "lscpu | grep -E '^(Model name|Virtualization|Hypervisor vendor):'" \
           "grep -o -w -E 'vmx|svm' /proc/cpuinfo | sort | uniq -c"; do
    tm_run a "$c"
  done
  tm_run a 'ls -l /dev/kvm'
  tm_run a "virsh capabilities | grep -o \"<domain type='[a-z]*'\" | sort | uniq -c"
  tm_run a 'virsh version | grep -i hypervisor'
  tm_run a 'ps -o pid,user,etime,comm -C qemu-system-x86_64'
  tm_record a "外（コンテナ lab@host）"
  guest_shell
  for c in 'uname -r' 'uname -v' 'grep PRETTY_NAME /etc/os-release' 'ps -p 1 -o pid,comm' 'nproc' 'free -m | head -2' \
           "lscpu | grep -E '^(Model name|Virtualization|Hypervisor vendor):'" \
           "grep -o -w -E 'vmx|svm' /proc/cpuinfo | sort | uniq -c" 'systemd-detect-virt'; do
    tm_run g "$c"
  done
  tm_run g 'last -x reboot shutdown | head -4'
  tm_record g "練習機の中（student@linuc）"
  tm_leave g 'exit'

  # docker stop / start（ホストの端末で読者が打つもの。記録はここに注記として残す）
  tm_close g; tm_close a; tm_close con
  t0=$(date +%s%3N); docker stop "$C" >/dev/null 2>&1; t1=$(date +%s%3N)
  note "ホストで docker stop linuc-boot-probe（読者は docker stop lab-linuc-boot）: $(( (t1 - t0) / 1000 )).$(( (t1 - t0) % 1000 / 100 )) 秒・終了コード $(docker inspect -f '{{.State.ExitCode}}' "$C")"
  docker start "$C" >/dev/null 2>&1; t2=$(date +%s)
  note "ホストで docker start linuc-boot-probe（読者は docker start lab-linuc-boot）"
  outer_shell
  sleep 2
  tm_run a 'virsh list'
  tm_record a "docker start の直後（自動起動の印がある）"
  ensure_up
  note "docker start から練習機の応答まで $(( $(date +%s) - t2 )) 秒"
  guest_shell
  tm_run g 'last -x reboot shutdown | head -4'
  tm_run g 'journalctl --list-boots --no-pager | tail -3'
  tm_run g 'journalctl -b -1 -n 4 --no-pager'
  tm_run g "journalctl -b -k --no-pager | grep -c 'recovery complete'"
  tm_record g "docker stop / start の後の練習機の中"
fi

# =====================================================================================
if want 4; then
  start_log 04-install "第4章 GUI が無くても、既定は graphical.target（1.01.1）"
  [ "$FROM" -eq 4 ] && { outer_shell; guest_shell; }
  tm_fresh g
  for c in 'systemctl get-default' 'runlevel' 'who -r' \
           'systemctl list-units --type=target --state=active --no-legend --no-pager | grep -E "graphical|multi-user"' \
           'systemctl status display-manager.service' 'ls /usr/share/xsessions /usr/bin/Xorg' \
           'ls -l /usr/lib/systemd/system/default.target /etc/systemd/system/default.target'; do
    tm_run g "$c"
  done
  tm_record g "GUI と CUI（ターゲット）"
  tm_fresh g
  for c in 'timedatectl | grep -E "Local time|Time zone"' 'ls -l /etc/localtime' 'localectl status' \
           'sudo passwd -S root' 'sudo passwd -S student' \
           'sudo grep -E "^(root|student):" /etc/shadow | cut -d: -f1,2 | cut -c1-16' 'id' \
           'dpkg-query -W | wc -l' "dpkg-query -W -f='\${db:Status-Abbrev} \${Package}\n' 'ubuntu-*'" \
           'lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS /dev/vda'; do
    tm_run g "$c"
  done
  tm_record g "タイムゾーン・パスワード・パッケージ・ディスク"
fi

# =====================================================================================
if want 5; then
  start_log 05-boot "第5章 ファームウェアが読めるのは、FAT の中の1ファイルだけ（1.01.3 / 1.01.1）"
  [ "$FROM" -eq 5 ] && { outer_shell; guest_shell; }
  console_attach
  tm_fresh a
  tm_run a 'virsh reboot linuc'
  tm_record a "再起動の合図を送る"
  grub_wait_menu 1200
  tm_shot con "GRUB のメニュー（数え下げ中）"
  tm_wait_last con 'login:$' 400
  sleep 2
  tm_record con "電源から login: まで（virsh reboot）"
  ensure_up
  guest_shell
  for c in 'ls /sys/firmware/efi' 'sudo efibootmgr' 'lsblk -o NAME,FSTYPE,LABEL,UUID,MOUNTPOINTS /dev/vda' \
           'sudo fdisk -l /dev/vda' 'findmnt -n -o TARGET,FSTYPE,OPTIONS /boot/efi' \
           'ls /boot/efi' 'sudo ls -l /boot/efi/EFI/ubuntu' 'sudo cat /boot/efi/EFI/ubuntu/grub.cfg' 'ls -l /boot' 'cat /proc/cmdline' \
           "grep -E '^GRUB_(TIMEOUT|CMDLINE_LINUX_DEFAULT|TERMINAL|FORCE_PARTUUID)=' /etc/default/grub /etc/default/grub.d/*.cfg" \
           "sudo grep -m2 -E '^\s+(linux|initrd)\s' /boot/grub/grub.cfg" 'systemd-analyze'; do
    tm_run g "$c"
  done
  tm_record g "ブートの中継を、練習機の中から見る"

  # ファームウェアの設定画面（BootNext で1回だけ UiApp から起動する）
  tm_fresh g
  tm_run g 'sudo efibootmgr -n 0000'
  tm_record g "次の1回だけ、ファームウェアの設定画面から起動する"
  tm_leave g 'sudo reboot'
  for i in $(seq 1 1200); do tm_screen con | grep -q 'Boot Maintenance Manager' && break; sleep 0.2; done
  sleep 3
  tm_shot con "ファームウェアの設定画面（最初の画面）"
  tm_keys con Down; sleep 1.5; tm_keys con Down; sleep 1.5
  tm_keys con Enter; sleep 4
  tm_shot con "Boot Manager（1回だけ起動するものを選ぶ）"
  tm_keys con Escape; sleep 3
  tm_keys con Down; sleep 1.5; tm_keys con Enter; sleep 4
  tm_shot con "Boot Maintenance Manager"
  tm_keys con Enter; sleep 4
  tm_keys con Down; sleep 1; tm_keys con Down; sleep 1; tm_keys con Down; sleep 1
  tm_keys con Enter; sleep 4
  tm_shot con "Change Boot Order"
  tm_keys con Escape; sleep 3; tm_keys con Escape; sleep 3; tm_keys con Escape; sleep 3
  tm_shot con "最初の画面に戻った"
  tm_keys con Up; sleep 1.5
  tm_keys con Enter; sleep 4
  tm_shot con "Boot Manager をもう一度"
  tm_keys con Enter
  tm_wait_last con 'login:$' 400
  sleep 2
  tm_record con "設定画面の一部始終"
  ensure_up
  guest_shell
  tm_run g 'sudo efibootmgr'
  tm_record g "設定画面から起動した後"

  # BootOrder を書き換えて再起動すると
  tm_fresh g
  tm_run g 'sudo efibootmgr -o 0001,0002,0000'
  tm_record g "ブート順を書き換える"
  "${TM[@]}" clear-history -t con
  tm_leave g 'sudo reboot'
  tm_wait_last con 'login:$' 600
  sleep 2
  tm_record con "ブート順を書き換えた後の起動"
  ensure_up
  guest_shell
  tm_run g 'sudo efibootmgr'
  tm_run g 'sudo ls -l /boot/efi/EFI/BOOT'
  tm_run g 'sudo iconv -f UTF-16 -t UTF-8 /boot/efi/EFI/ubuntu/BOOTX64.CSV'
  tm_record g "起動した後のブート順"
fi

# =====================================================================================
if want 6; then
  start_log 06-target "第6章 シングルユーザモードは、パスワードを聞かずに root を渡す（1.01.3）"
  [ "$FROM" -eq 6 ] && { outer_shell; guest_shell; console_attach; }
  tm_fresh g
  for c in 'systemctl get-default' 'ls -l /usr/lib/systemd/system/runlevel?.target' \
           'systemctl list-units --type=target --state=active --no-legend --no-pager'; do
    tm_run g "$c"
  done
  # isolate の後の runlevel の記録（utmp）は、別のサービスが少し遅れて書く。人が次を打つまでの間を置く
  tm_run g 'sudo systemctl isolate multi-user.target' 180; W 5
  tm_run g 'systemctl is-active graphical.target multi-user.target'
  tm_run g 'runlevel'
  tm_run g 'sudo systemctl isolate graphical.target' 180; W 5
  tm_run g 'runlevel'
  for c in 'sudo systemctl set-default multi-user.target' 'ls -l /etc/systemd/system/default.target' \
           'systemctl get-default' 'systemctl is-active graphical.target' \
           'sudo systemctl set-default graphical.target' 'ls -l /etc/systemd/system/default.target'; do
    tm_run g "$c"
  done
  tm_record g "ターゲットを切り替える・既定を変える"

  # GRUB でカーネル引数を足す: rescue.target
  "${TM[@]}" clear-history -t con
  tm_leave g 'sudo reboot'
  grub_wait_menu 1200
  grub_stop
  tm_shot con "数え下げを止めた"
  grub_e; sleep 1
  tm_shot con "e を押した（起動に使うコマンドの編集画面）"
  grub_add 'single'
  tm_shot con "linux の行末に single を足した"
  tm_keys con C-x
  tm_wait_last con 'continue\):$' 400
  sleep 2
  tm_shot con "rescue.target で止まった"
  tm_keys con Enter; sleep 3
  tm_type con 'id; tty; systemctl is-active rescue.target'; tm_wait_last con '#$' 30
  sleep 1
  tm_shot con "Enter だけで root のシェル"
  tm_type con 'exit'
  tm_wait_last con 'login:$' 400
  sleep 2
  tm_record con "rescue.target の一部始終"
  ensure_up
  guest_shell
  tm_run g 'cat /proc/cmdline'
  tm_run g 'journalctl -b -u rescue.service --no-pager'
  tm_run g 'sudo grep -E "^root:" /etc/shadow | cut -d: -f1,2'
  tm_record g "rescue から抜けた後"

  # init=/bin/bash
  "${TM[@]}" clear-history -t con
  tm_leave g 'sudo reboot'
  grub_wait_menu 1200
  grub_stop
  grub_e; sleep 1
  grub_add 'init=/bin/bash'
  tm_shot con "linux の行末に init=/bin/bash を足した"
  tm_keys con C-x
  tm_wait_last con '#$' 400
  sleep 3
  tm_type con 'id; ps -p 1 -o pid,comm'; sleep 3
  tm_type con 'systemctl get-default'; sleep 3
  tm_type con 'systemctl is-system-running; echo "終了コード $?"'; sleep 3
  tm_type con 'findmnt -n -o TARGET,OPTIONS /'; sleep 3
  tm_shot con "init=/bin/bash のシェル"
  tm_type con 'exec /sbin/init'
  tm_wait_last con 'login:$' 400
  sleep 2
  tm_record con "init=/bin/bash の一部始終"
  ensure_up
fi

# =====================================================================================
if want 7; then
  start_log 07-shutdown "第7章 halt では電源は切れない（1.01.1 / 1.01.3）"
  [ "$FROM" -eq 7 ] && { outer_shell; console_attach; }
  guest_shell
  tm_run g 'ls -l /usr/sbin/shutdown /usr/sbin/halt /usr/sbin/poweroff /usr/sbin/reboot'
  tm_record g "4つのコマンドの正体"
  # 端末 b: 練習機に入って待っている人
  tm_close b; tm_open b 120 40; tm_type b "PS1='\$ '"; tm_wait_last b '^\$$' 10
  tm_login b; tm_fresh b
  tm_fresh g
  tm_run g 'sudo shutdown -h +30 "メンテナンスのため停止します"'
  tm_run g 'cat /run/systemd/shutdown/scheduled'
  tm_run g 'busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager ScheduledShutdown'
  tm_run g 'ls -l /run/nologin'
  W 5
  tm_run g 'sudo shutdown -c'
  W 3
  tm_run g 'sudo shutdown'
  W 3
  tm_run g 'cat /run/nologin'
  tm_record g "端末1: 予約する人"
  tm_fresh a
  tm_run a 'ssh linuc hostname'
  tm_record a "予約が5分以内に迫っているとき、外から入ろうとする"
  tm_fresh g
  tm_run g 'sudo shutdown -c'
  W 3
  tm_run g 'wall "これは wall の試験です"'
  W 3
  tm_record g "端末1: 取り消して、wall を送る"
  tm_record b "端末2: 入って待っていた人の画面"
  tm_leave b 'exit'

  # halt
  "${TM[@]}" clear-history -t con
  tm_fresh g
  tm_leave g 'sudo halt'
  tm_wait con 'System halted' 120
  sleep 3
  tm_record g "端末1: sudo halt"
  tm_shot con "halt の後のコンソール"
  tm_fresh a
  tm_run a 'virsh domstate linuc --reason'
  W 10
  tm_run a 'virsh domstate linuc --reason'
  tm_run a 'virsh destroy linuc'
  tm_run a 'virsh domstate linuc --reason'
  tm_run a 'virsh start linuc'
  tm_record a "外から見た halt の後"
  ensure_up
  # poweroff（コンソールは destroy で切れたので、つなぎ直して最後の行を見る）
  console_attach
  guest_shell
  "${TM[@]}" clear-history -t con
  tm_leave g 'sudo poweroff'
  tm_wait con 'Power down' 120
  sleep 3
  tm_record g "端末1: sudo poweroff"
  tm_shot con "poweroff の後のコンソール"
  wait_off 120
  tm_fresh a
  tm_run a 'virsh domstate linuc --reason'
  tm_run a 'virsh start linuc'
  tm_record a "poweroff の後"
  ensure_up
  # 電源を抜くと（virsh destroy）、次の起動で何が起きるか
  #   書いた直後に抜く。ext4 は書いた中身をしばらく（commit=30 秒・遅延割り当て）メモリに持つので、抜くと残らない
  guest_shell
  tm_run g 'echo "抜く前に書いた" > memo.txt; ls -l memo.txt'
  W 3
  tm_fresh a
  before=$(tm_count g 'Connection to 127.0.0.1 closed')
  tm_run a 'virsh destroy linuc'
  tm_closed_wait g "$before"
  tm_run a 'virsh start linuc'
  tm_record g "端末1: 書いてすぐに電源を抜かれる"
  tm_record a "外: 動いている練習機を destroy して、また起動する"
  ensure_up
  guest_shell
  tm_run g 'sudo cat /run/initramfs/fsck.log'   # 2026-10-13 の本番の記録は sudo なしで断られたので、本文は 07b（probe-extra）の記録を使っている
  tm_run g 'ls -l memo.txt; cat memo.txt'
  tm_record g "電源を抜かれた次の起動"
  # reboot と起動の記録
  tm_fresh g
  tm_run g 'cat /proc/sys/kernel/random/boot_id'
  tm_leave g 'sudo reboot'
  tm_record g "sudo reboot"
  ensure_up
  guest_shell
  tm_run g 'cat /proc/sys/kernel/random/boot_id'
  tm_run g 'last -x reboot shutdown | head -8'
  tm_record g "reboot の後"
fi

# =====================================================================================
if want 8; then
  start_log 08-signal "第8章 kill は止めない。合図を送るだけ（1.01.4）"
  [ "$FROM" -eq 8 ] && { outer_shell; guest_shell; }
  tm_fresh g
  for c in 'uptime' 'cat /proc/loadavg' 'ps aux | head -4' 'ps -ef | head -4' 'pstree -p student' \
           'top -b -n 1 | head -12' 'pgrep -a lab-hog' 'pgrep -l -u student' \
           'ps -o pid,ppid,user,stat,etime,cmd -p $(pgrep -x lab-hog)'; do
    tm_run g "$c"
  done
  tm_record g "プロセスを見る"
  tm_fresh g
  for c in 'kill $(pgrep -x lab-hog)' 'ps -o pid,stat,comm -p $(pgrep -x lab-hog)' \
           'grep -E "^Sig(Ign|Cgt)" /proc/$(pgrep -x lab-hog)/status' 'kill -l' \
           'kill -KILL $(pgrep -x lab-hog)' 'pgrep -a lab-hog; echo "終了コード $?"' \
           'systemctl status lab-hog --no-pager | head -6'; do
    tm_run g "$c"
  done
  tm_record g "TERM を無視するプロセスに kill"
  tm_fresh g
  for c in 'sleep 601 &' 'sleep 602 &' 'sleep 603 &' 'jobs' "pgrep -a -f 'sleep 60'" "pkill -f 'sleep 601'" 'jobs' \
           'killall sleep' 'jobs'; do
    tm_run g "$c"
  done
  tm_record g "pkill と killall"
  tm_fresh g
  for c in 'cp /usr/bin/sleep /tmp/very-long-process-name' '/tmp/very-long-process-name 300 &' \
           'pgrep very-long-process-name; echo "終了コード $?"' 'pgrep -f very-long-process-name' \
           'ps -o pid,comm,args -p $!' 'pkill -f very-long-process-name'; do
    tm_run g "$c"
  done
  W 2
  tm_run g 'jobs'
  tm_record g "名前は 15 文字で切られる"
fi

# =====================================================================================
if want 9; then
  start_log 09-hup "第9章 exit では消えず、切断で消える（1.01.4）"
  [ "$FROM" -eq 9 ] && { outer_shell; guest_shell; }
  sess_b() { tm_close b; tm_open b 120 40; tm_type b "PS1='\$ '"; tm_wait_last b '^\$$' 10; tm_fresh b; }
  # ジョブ: Ctrl+Z / jobs / bg / fg
  sess_b
  tm_login b
  tm_type b 'sleep 300'; sleep 1.5; tm_keys b C-z; tm_wait_last b '^\$$' 10
  for c in 'jobs -l' 'ps -o pid,stat,cmd -p $(pgrep -f "sleep 300")' 'bg' 'jobs'; do tm_run b "$c"; done
  tm_type b 'fg'; sleep 1.5; tm_keys b C-c; tm_wait_last b '^\$$' 10
  tm_run b 'jobs'
  tm_leave b 'exit'
  tm_record b "フォアグラウンドとバックグラウンド"
  # & で動かして exit
  sess_b
  tm_login b
  for c in 'sleep 1001 &' 'jobs -l' 'shopt huponexit'; do tm_run b "$c"; done
  tm_leave b 'exit'
  tm_record b "& で動かして exit"
  tm_fresh g
  tm_run g "pgrep -a -f 'sleep 100'"
  tm_record g "別の端末から見る（exit の後）"
  # ふつうこう考える…の裏: & で動かして ~.（回線が切れたのと同じ）
  sess_b
  tm_login b
  tm_run b 'sleep 1002 &'
  tm_cut b
  tm_record b "& で動かして ~.（切断）"
  tm_fresh g
  tm_run g "pgrep -a -f 'sleep 100'"
  tm_record g "別の端末から見る（切断の後）"
  # nohup
  sess_b
  tm_login b
  tm_type b 'nohup sleep 1003 &'; sleep 2.5; tm_keys b Enter; tm_wait_last b '^\$$' 10
  tm_run b 'grep SigIgn /proc/$!/status'
  tm_cut b
  tm_record b "nohup で動かして ~."
  tm_fresh g
  tm_run g "pgrep -a -f 'sleep 100'"
  tm_run g 'cat ~/nohup.out; ls -l ~/nohup.out'
  tm_record g "別の端末から見る（nohup の後）"
  # tmux
  sess_b
  tm_login b
  tm_type b 'tmux new -s work'; sleep 3
  tm_type b 'lab-count'; sleep 3
  tm_keys b C-b; sleep 0.5; tm_keys b d; tm_wait_last b '^\$$' 10
  tm_cut b
  tm_record b "tmux の中で動かし、切り離してから ~."
  tm_fresh g
  tm_run g 'tmux ls'
  tm_run g 'pgrep -a lab-count'
  tm_record g "別の端末から見る（tmux）"
  sess_b
  tm_login b
  tm_type b 'tmux attach -t work'; sleep 3
  tm_shot b "tmux attach -t work（戻った）"
  tm_keys b C-c; sleep 1
  tm_type b 'exit'; tm_wait b 'exited' 10; sleep 1
  tm_leave b 'exit'
  tm_record b "tmux に戻って終わらせる"
  # screen
  sess_b
  tm_login b
  tm_type b 'screen -S job'; sleep 3
  tm_type b 'lab-count'; sleep 3
  tm_keys b C-a; sleep 0.5; tm_keys b d; tm_wait_last b '^\$$' 10
  tm_run b 'screen -ls'
  tm_cut b
  tm_record b "screen の中で動かし、切り離してから ~."
  tm_fresh g
  tm_run g 'screen -ls'
  tm_run g 'pgrep -a lab-count'
  tm_run g 'pkill lab-count; pkill -f "sleep 100"'
  tm_record g "別の端末から見る（screen）と後片付け"
fi

# =====================================================================================
if want 10; then
  start_log 10-x11 "第10章 X では、画面の側がサーバー（1.01.5）"
  [ "$FROM" -eq 10 ] && { outer_shell; guest_shell; }
  tm_fresh g
  for c in 'echo "DISPLAY=[$DISPLAY]"' 'command -v startx Xorg xauth xterm; echo "終了コード $?"' \
           'systemctl status display-manager.service' "sudo sshd -T | grep -i x11"; do
    tm_run g "$c"
  done
  tm_record g "練習機の中（X は入っていない）"
  tm_fresh a
  for c in 'echo "DISPLAY=[$DISPLAY]"' "ssh -X linuc 'echo DISPLAY=[\$DISPLAY]'" \
           "ssh -v -X linuc true 2>&1 | grep -iE 'x11|display'" \
           "DISPLAY=:0 ssh -X linuc 'echo DISPLAY=[\$DISPLAY]'" \
           "DISPLAY=:0 ssh -v -X linuc true 2>&1 | grep -iE 'x11|xauth'"; do
    tm_run a "$c"
  done
  tm_record a "外から ssh -X"

  start_log 00-env-end "0. 環境（練習機が動いているとき）"
  tm_fresh a
  tm_run a 'lab env'
  tm_record a "lab env（練習機が動いているとき）"
fi

tmux -L linuc-boot kill-server 2>/dev/null
echo "probe done"
