#!/usr/bin/env bash
# 練習機（ゲスト）の中で root として1回だけ走る。ここで入れたものが全員の練習機の初期状態になる。
#
# 方針: LinuC のシステム系5コース（1.01 / 1.05 / 1.07 / 1.08 / 1.10）が使うものを全部入れておき、
#       デーモンは止めておく。各コースは自分が教えるものだけを起動する（初回の provision.sh）。
#       入れておくのは、読者が演習中に apt で取りに行くと TCG では遅く、オフラインでは詰まるため。
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
SNAP=20260929T000000Z

cloud-init status --wait >/dev/null || true

# 再開用: START=3 なら 1〜2（apt の固定・全パッケージの入れ直し）を飛ばす。
# 1〜2 は snapshot サーバからの取得に 30 分以上かかる（実測 2026-10-13: 1 ファイル約 1.5〜2 秒）。
START=${START:-1}
if [ "$START" -le 2 ]; then

# ---- 1) apt をコンテナの檻と同じ時刻に固定する ------------------------------
cat > /etc/apt/sources.list.d/ubuntu.sources <<EOF
Types: deb
URIs: https://snapshot.ubuntu.com/ubuntu/$SNAP
Suites: noble noble-updates noble-security
Components: main universe
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
rm -f /etc/apt/sources.list
apt-get update
#   土台のクラウドイメージ（20260905）を snapshot の時刻（20260929）にそろえる
apt-get -y -o Dpkg::Options::=--force-confold full-upgrade

# ---- 2) man とドキュメントを戻す --------------------------------------------
#   minimal イメージは dpkg の path-exclude で man を捨てている。外してから入っている全パッケージを入れ直す。
#   （仮想マシンの中なので、コンテナと違って層が二重になる問題は無い）
rm -f /etc/dpkg/dpkg.cfg.d/excludes
dpkg-query -W -f='${binary:Package}\n' > /tmp/pkgs
xargs -a /tmp/pkgs apt-get install -y --reinstall --no-install-recommends -o Dpkg::Options::=--force-confold

fi  # START
apt-get update

# ---- 3) コースが使うもの ----------------------------------------------------
apt-get install -y --no-install-recommends -o Dpkg::Options::=--force-confold \
  qemu-guest-agent man-db manpages less vim nano bash-completion psmisc lsof tmux screen \
  file tree curl jq rsync \
  efibootmgr \
  gdisk parted lvm2 xfsprogs btrfs-progs dosfstools e2fsprogs usbutils pciutils \
  network-manager ifupdown net-tools traceroute iputils-tracepath iputils-ping \
  bind9-dnsutils bind9-host netcat-openbsd ncat nmap tcpdump ipcalc dnsmasq-base \
  cron at anacron locales \
  xinetd iptables firewalld gnupg pinentry-curses sudo
#   openbsd-inetd は入れない。xinetd と同じ inet-superserver を提供し、互いに Conflicts で同時に入らない
#   （実測 2026-10-13: `xinetd : Conflicts: inet-superserver`）。1.09 の chrony と ntpsec と同じ型。
mandb -q

# ---- 4) デーモンは止めておく（教えるコースが自分で起動する） -----------------
#   NetworkManager: 管理用の NIC（enp0s16）は netplan + systemd-networkd が持つ。NM が奪うと ssh が切れる
#   firewalld / xinetd / inetd: 起動すると待ち受けやパケットの扱いが変わる。セキュリティのコースが扱う
for u in NetworkManager.service NetworkManager-wait-online.service NetworkManager-dispatcher.service \
         firewalld.service xinetd.service inetd.service; do
  systemctl disable "$u" 2>/dev/null || true
done
#   読者の操作と関係なく状態が変わるものを止める（同じ画面が出なくなる）
systemctl mask apt-daily.timer apt-daily-upgrade.timer apt-daily.service apt-daily-upgrade.service
systemctl disable systemd-timesyncd.service 2>/dev/null || true
systemctl mask motd-news.timer 2>/dev/null || true

# ---- 5) ネットワーク: 管理用 NIC は名前で固定する ---------------------------
#   cloud-init が書いた netplan は MAC で照合している。名前で書き直し、cloud-init は以後止める。
rm -f /etc/netplan/50-cloud-init.yaml
cat > /etc/netplan/01-lab-mgmt.yaml <<'EOF'
# 管理用の NIC。外（コンテナ）からの ssh と、練習機の中からの lab はここを通る。
# この NIC を止めると ssh が切れる。そのときは外で vm console（シリアル）から入る。
network:
  version: 2
  ethernets:
    enp0s16:
      dhcp4: true
EOF
chmod 600 /etc/netplan/01-lab-mgmt.yaml
touch /etc/cloud/cloud-init.disabled

# ---- 6) GRUB をシリアルコンソールに 3 秒出す ---------------------------------
#   既定のクラウドイメージはメニューを隠して即起動する。1.01.3 でカーネル引数を足して
#   シングルユーザモードに入る練習をするため、virsh console からメニューが見えるようにする。
#   GRUB_RECORDFAIL_TIMEOUT: 前回の停止が異常だと Ubuntu は 30 秒待つ。コンテナごと止めた読者が毎回待たされないように 3 秒にする。
cat > /etc/default/grub.d/99-lab.cfg <<'EOF'
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=3
GRUB_RECORDFAIL_TIMEOUT=3
GRUB_TERMINAL="serial console"
GRUB_SERIAL_COMMAND="serial --unit=0 --speed=115200"
GRUB_CMDLINE_LINUX_DEFAULT="console=tty1 console=ttyS0,115200"
EOF
update-grub

# ---- 7) 名前・時刻・ログイン -------------------------------------------------
hostnamectl set-hostname linuc
grep -q '127.0.1.1' /etc/hosts && sed -i 's/^127\.0\.1\.1.*/127.0.1.1 linuc/' /etc/hosts || echo '127.0.1.1 linuc' >> /etc/hosts
timedatectl set-timezone Asia/Tokyo
#   コンソール（virsh console）から入れるようにパスワードを付ける。学習用の固定値で、外からは届かない
echo 'student:student' | chpasswd
#   ログイン時の案内を静的な1枚にする（動的な motd は日時や負荷を出し、毎回画面が変わる）
chmod -x /etc/update-motd.d/* 2>/dev/null || true
cat > /etc/motd <<'EOF'

  LinuC 練習機（Ubuntu 24.04 / 仮想マシン）
  - 採点は外のコンテナが持っています。この中でも lab check NN で答え合わせできます
  - 管理用の NIC（enp0s16）を止めると ssh が切れます。そのときは外で vm console

EOF

# ---- 8) 練習機の中の lab（外へ頼む中継） --------------------------------------
install -m 0755 /tmp/lab-build/files/lab /usr/local/bin/lab

# 片付けと停止は finalize.sh で行う。その前に外側（inside-builder.sh）が
# /var/cache/apt/archives の .deb を回収して、次のビルドで再利用する。
echo CUSTOMIZE_OK
