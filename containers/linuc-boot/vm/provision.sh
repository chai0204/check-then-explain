#!/bin/bash
# linuc-boot（主題1.01）の初回の準備。練習機の中で root として1回だけ走る。
#   外側の vm が lab-guest（qemu-guest-agent 経由）で流す。起動のしかた（virsh start / vm start）に依らず、
#   練習機が最初に応答したときに走る。vm reset --yes で工場出荷時に戻すと、次の起動でもう一度走る。
set -euo pipefail

# ---- 1) ssh: 鍵は読者が作る（第2章・演習02） ---------------------------------
#   クラウドイメージは /etc/ssh/sshd_config.d/60-cloudimg-settings.conf で PasswordAuthentication no にしている。
#   sshd は同じ項目を「最初に読んだ値」で決めるので、それより前に読まれる名前（10-）で yes を置く。
#   student の authorized_keys は空にする（土台が入れていた「外から入る鍵」を外す）。
cat > /etc/ssh/sshd_config.d/10-lab-password.conf <<'EOF'
# linuc-boot: 鍵を登録する前の最初の1回（ssh-copy-id）はパスワードで入るため、パスワード認証を許す。
# sshd は同じ項目を最初に読んだ値で決める。60-cloudimg-settings.conf の "no" より先に読ませるため 10- にしている。
PasswordAuthentication yes
EOF
chmod 644 /etc/ssh/sshd_config.d/10-lab-password.conf
install -d -o student -g student -m 700 /home/student/.ssh
: > /home/student/.ssh/authorized_keys
chown student:student /home/student/.ssh/authorized_keys
chmod 600 /home/student/.ssh/authorized_keys
systemctl try-reload-or-restart ssh.service

# ---- 2) 第5・6章・演習03: GRUB を「カーネル引数を足す練習」ができる形にする -----
#   a) メニューを 10 秒出す。土台は 3 秒（毎回待たされないように）。このコースはメニューで e を押して
#      カーネル引数を足すのが本題で、virsh console の画面を見てから矢印キーを押すまでに 3 秒では足りない。
#   b) GRUB_FORCE_PARTUUID を空にして、普通の「カーネル＋initrd」のエントリに戻す。
#      Ubuntu のクラウドイメージは 40-force-partuuid.cfg で「initrd を使わない起動」を試すエントリを作り、
#      編集画面に linux 行が2つ（失敗した次の回用と、普段用）並ぶ。普段用は 17 行目にあり、
#      シリアルの 80x24 では編集画面がスクロールして崩れ、足した語が別の行に入った（実測 2026-10-13）。
#      空にすると linux 行は1つになり、画面に収まる。起動の順番（カーネル → initrd → ルート）も試験の説明どおりになる。
#   grub.d の *.cfg は名前の順に読まれ、後のものが勝つので、土台の 99-lab.cfg より後ろの名前にする。
cat > /etc/default/grub.d/zz-linuc-boot.cfg <<'EOF'
# linuc-boot: GRUB のメニューでカーネル引数を足す練習のための設定（土台の 99-lab.cfg より後に読まれる）
#   メニューを 10 秒出す（土台は 3 秒）
GRUB_TIMEOUT=10
GRUB_RECORDFAIL_TIMEOUT=10
#   initrd を使わない起動の試み（クラウドイメージの 40-force-partuuid.cfg）をやめ、linux 行を1つにする
GRUB_FORCE_PARTUUID=
EOF
update-grub 2>&1 | tail -2

# ---- 3) 第8章・演習06: 合図（TERM）を無視して居座るプロセス -----------------
cat > /usr/local/bin/lab-hog <<'EOF'
#!/bin/bash
# linuc-boot 演習06 の相手。TERM・INT・HUP を無視して居座る（何もしない。CPU はほぼ使わない）。
trap '' TERM INT HUP
while :; do sleep 5; done
EOF
chmod 755 /usr/local/bin/lab-hog
cat > /etc/systemd/system/lab-hog.service <<'EOF'
# linuc-boot 演習06 の相手を、起動のたびに student の権限で動かす。
[Unit]
Description=linuc-boot exercise 06: a process that ignores SIGTERM

[Service]
User=student
ExecStart=/usr/local/bin/lab-hog
# systemctl stop で送る TERM も無視されるので、10 秒待って KILL に切り替わる
TimeoutStopSec=10s

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now lab-hog.service

# ---- 4) 第9章・演習07: 切断しても続けたい処理 ---------------------------------
cat > /usr/local/bin/lab-count <<'EOF'
#!/bin/bash
# linuc-boot 演習07 の題材。1秒ごとに数を1つ数えて出すだけ。止めるまで終わらない。
n=0
while :; do n=$((n + 1)); echo "$n"; sleep 1; done
EOF
chmod 755 /usr/local/bin/lab-count

# ---- 5) 判定の通り道（qemu-guest-agent）を、ターゲットの切り替えで止めない --------
#   qemu-guest-agent は udev（仮想のシリアルポートが見えたとき）が起動するだけで、どのターゲットにも属していない。
#   そのため systemctl isolate（rescue のシェルを exit したときの systemctl default も同じ）で止められ、
#   練習機は動いているのに lab check が「練習機が起動していません」と言った（実測 2026-10-13）。
#   multi-user.target に結びつけ、isolate で multi-user / graphical へ移っても止まらないようにする。
systemctl add-wants multi-user.target qemu-guest-agent.service

echo LINUC_BOOT_PROVISION_OK
