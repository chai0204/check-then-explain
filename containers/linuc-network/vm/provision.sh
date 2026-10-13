#!/usr/bin/env bash
# 練習機の中で root として、初回の起動時に1回だけ走る（外の vm が qemu-guest-agent 経由で流す）。
# 主題1.07（ネットワークの基礎）の「社内 LAN」と、NIC ごとの持ち主を用意する。
#
#   練習機 linuc ── lab0 ──┐
#                         [sw]   スイッチ（ブリッジ）  192.168.10.0/24  fd00:10::/64
#   router  eth0 ─────────┤      192.168.10.1   fd00:10::1   ルータ（社内の正しい出口）
#   oldgw   eth0 ─────────┘      192.168.10.254              撤去予定の旧ルータ（どこにもつながっていない）
#   router  eth1 ── server eth0                                172.16.20.0/24  fd00:20::/64
#                   server  172.16.20.10  fd00:20::10   DNS（dnsmasq: lab.example）と HTTP（80/tcp）
#
# NIC の持ち主（どの道具が設定するか）:
#   enp0s16  netplan → systemd-networkd  管理用。デフォルトルートと DNS は受け取らない
#   enp0s17  ifupdown                    /etc/network/interfaces に、まだ何も書いていない（演習で書く）
#   enp0s18  NetworkManager              接続の定義がまだ無い（演習で nmcli で作る）
#   lab0     ifupdown                    書いてある。gateway が旧ルータのまま（演習で直す）
#
# 名前空間（sw / router / oldgw / server）は「別の機械」の代わり。どれも練習機の中にあるので、
# 経路も DNS も相手のサーバも、読者の家や会社のネットワーク、オフラインかどうかに左右されない。
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
install -d -m 0755 /etc/lab-net /usr/local/lib/lab-net

# ---- 1) 社内 LAN を作るスクリプト ---------------------------------------------
cat > /usr/local/sbin/lab-net <<'EOF'
#!/usr/bin/env bash
# lab-net start|stop — 練習機の中に「社内 LAN」を作る／壊す。lab-net.service が起動のたびに start を呼ぶ。
#
#   練習機 linuc ── lab0 ──┐
#                         [sw]   スイッチ（ブリッジ）  192.168.10.0/24  fd00:10::/64
#   router  eth0 ─────────┤      192.168.10.1   fd00:10::1   ルータ
#   oldgw   eth0 ─────────┘      192.168.10.254              旧ルータ（どこにもつながっていない）
#   router  eth1 ── server eth0                                172.16.20.0/24  fd00:20::/64
#                   server  172.16.20.10  fd00:20::10   DNS（53）と HTTP（80）
#
# 名前空間（network namespace）は「別の機械」の代わり。それぞれが自分の NIC・経路表・ARP 表・待ち受けを持つ。
#   ip netns list                            名前空間の一覧
#   sudo ip netns exec router ip route       router の中で ip route を打つ（router の経路表が出る）
#
# lab0（練習機の側）のアドレスとゲートウェイは、ここでは付けない。/etc/network/interfaces に書いてあり、
# ifupdown（networking.service の ifup -a）が付ける。
set -eu
nsx() { ip netns exec "$@"; }

stop() {
  ip link del lab0 2>/dev/null || true
  for n in server oldgw router sw; do ip netns del "$n" 2>/dev/null || true; done
}

start() {
  stop
  for n in sw router oldgw server; do
    ip netns add "$n"
    ip -n "$n" link set lo up
  done
  # 同じ画面を出すための設定:
  #   ICMP の返事を間引かない（traceroute の * が実行のたびに変わらないように）。間引きは2か所にある:
  #     icmp_ratelimit       … 名前空間ごと
  #     route.error_cost     … 「経路が無い」ときの Net Unreachable の間引き。カーネル全体で1つ（練習機の側でしか設定できない）。
  #                            既定（1秒に1回）のままだと、旧ルータ経由の ping が2回目から黙り、traceroute の * の位置が毎回変わった（実測 2026-10-13）
  #   スイッチと旧ルータは IPv6 を話さない（練習機から見える IPv6 の隣人を router だけにする）
  sysctl -qw net.ipv4.route.error_cost=0
  nsx sw     sysctl -qw net.ipv6.conf.all.disable_ipv6=1 net.ipv6.conf.default.disable_ipv6=1
  nsx oldgw  sysctl -qw net.ipv6.conf.all.disable_ipv6=1 net.ipv6.conf.default.disable_ipv6=1
  nsx router sysctl -qw net.ipv4.ip_forward=1 net.ipv6.conf.all.forwarding=1 \
                        net.ipv4.icmp_ratelimit=0 net.ipv6.icmp.ratelimit=0
  nsx oldgw  sysctl -qw net.ipv4.ip_forward=1 net.ipv4.icmp_ratelimit=0
  nsx server sysctl -qw net.ipv4.icmp_ratelimit=0 net.ipv6.icmp.ratelimit=0

  # スイッチ（ブリッジ）。STP と学習の待ち時間を切る（つないだ直後から通す）
  ip -n sw link add br0 type bridge stp_state 0 forward_delay 0 mcast_snooping 0
  ip -n sw link set br0 up

  # ケーブル（veth）。MAC は固定する。IPv6 のアドレスは MAC から作られるので、乱数にすると読者ごとに変わる
  ip link add lab0 address 52:54:00:0a:00:02 type veth peer name p-linuc address 52:54:00:ff:00:02 netns sw
  ip -n router link add eth0 address 52:54:00:0a:00:01 type veth peer name p-router address 52:54:00:ff:00:01 netns sw
  ip -n oldgw  link add eth0 address 52:54:00:0a:00:fe type veth peer name p-oldgw address 52:54:00:ff:00:fe netns sw
  ip -n router link add eth1 address 52:54:00:14:00:01 type veth peer name eth0 address 52:54:00:14:00:0a netns server
  for p in p-linuc p-router p-oldgw; do ip -n sw link set "$p" master br0 up; done
  # 練習機の lab0: 一時アドレス（プライバシー拡張）を作らせない。作ると乱数のアドレスが増えて画面が揃わない
  sysctl -qw net.ipv6.conf.lab0.use_tempaddr=0

  # router: 社内 LAN（eth0）とサーバの LAN（eth1）をつなぐ
  ip -n router addr add 192.168.10.1/24 dev eth0
  ip -n router addr add fd00:10::1/64 dev eth0 nodad
  ip -n router addr add 172.16.20.1/24 dev eth1
  ip -n router addr add fd00:20::1/64 dev eth1 nodad
  ip -n router link set eth0 up
  ip -n router link set eth1 up

  # oldgw: 撤去予定の旧ルータ。社内 LAN のアドレスしか持たず、先へ行く経路が1本も無い
  ip -n oldgw addr add 192.168.10.254/24 dev eth0
  ip -n oldgw link set eth0 up

  # server: DNS と HTTP のサーバ。出口は router
  ip -n server addr add 172.16.20.10/24 dev eth0
  ip -n server addr add fd00:20::10/64 dev eth0 nodad
  ip -n server link set eth0 up
  ip -n server route add default via 172.16.20.1
  ip -n server -6 route add default via fd00:20::1
}

case "${1:-}" in
  start) start ;;
  stop)  stop ;;
  *) echo "使い方: lab-net start|stop" >&2; exit 2 ;;
esac
EOF
chmod 0755 /usr/local/sbin/lab-net

# ---- 2) 名前空間の中で動くサーバの設定 ---------------------------------------
cat > /etc/lab-net/router.conf <<'EOF'
# router で動く dnsmasq。DNS は答えず（port=0）、社内 LAN（eth0）にルータ広告（RA）だけを出す。
# 練習機の lab0 はこれを受け取り、fd00:10::/64 のアドレスを自分で作る（SLAAC）。
port=0
interface=eth0
enable-ra
dhcp-range=::,constructor:eth0,ra-only
user=nobody
pid-file=/run/lab-net/router-dnsmasq.pid
dhcp-leasefile=/run/lab-net/router-dnsmasq.leases
EOF

cat > /etc/lab-net/server.conf <<'EOF'
# server で動く dnsmasq。lab.example の名前を答える DNS サーバ（練習用）。
# インターネットの名前は答えない（問い合わせ先の上流サーバを1つも持たない）。
listen-address=172.16.20.10,fd00:20::10
bind-interfaces
no-resolv
no-hosts
no-poll
local=/lab.example/
local-ttl=300
# 逆引き（PTR）は、同じアドレスを書いた最初の行の名前になる。172.16.20.10 → server.lab.example
host-record=server.lab.example,172.16.20.10,fd00:20::10
host-record=www.lab.example,172.16.20.10
host-record=ns.lab.example,172.16.20.10
host-record=router.lab.example,192.168.10.1,fd00:10::1
host-record=oldgw.lab.example,192.168.10.254
host-record=linuc.lab.example,192.168.10.2
host-record=mail.lab.example,172.16.20.25
mx-host=lab.example,mail.lab.example,10
cname=web.lab.example,www.lab.example
# 判定（lab check）が使う。この下のどんな名前にも 172.16.20.10 を返す
address=/check.lab.example/172.16.20.10
user=nobody
pid-file=/run/lab-net/server-dnsmasq.pid
EOF

cat > /usr/local/lib/lab-net/www-reply <<'EOF'
#!/usr/bin/env bash
# server の 80/tcp が返す固定の応答。ncat --sh-exec が接続ごとに起動する。
# 要求の見出し（空行まで）を読んでから返す。読まずに閉じると相手に RST が届くことがある。
while IFS= read -r -t 3 line; do line=${line%$'\r'}; [ -z "$line" ] && break; done
body='hello from www.lab.example (172.16.20.10, 80/tcp)'
printf 'HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s\n' "$((${#body} + 1))" "$body"
EOF

cat > /usr/local/lib/lab-net/board-reply <<'EOF'
#!/usr/bin/env bash
# 練習機の 8080/tcp（lab-board）が返す固定の応答。ncat --sh-exec が接続ごとに起動する。
while IFS= read -r -t 3 line; do line=${line%$'\r'}; [ -z "$line" ] && break; done
body='lab-board: no news today'
printf 'HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s\n' "$((${#body} + 1))" "$body"
EOF
chmod 0755 /usr/local/lib/lab-net/www-reply /usr/local/lib/lab-net/board-reply

cat > /etc/default/lab-board <<'EOF'
# lab-board.service（社内掲示板）が読む設定。変えたら: sudo systemctl restart lab-board
# 待ち受けるアドレス
LISTEN_ADDRESS=127.0.0.1
EOF

# ---- 3) systemd のユニット -----------------------------------------------------
cat > /etc/systemd/system/lab-net.service <<'EOF'
[Unit]
Description=社内 LAN（network namespace: sw / router / oldgw / server）を作る
Documentation=https://check-then-explain.junxiaosong508-de2.workers.dev/linuc-network/
DefaultDependencies=no
After=local-fs.target systemd-sysctl.service
Before=network-pre.target networking.service shutdown.target
Wants=network-pre.target
Conflicts=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
RuntimeDirectory=lab-net
RuntimeDirectoryPreserve=yes
ExecStart=/usr/local/sbin/lab-net start
ExecStop=/usr/local/sbin/lab-net stop

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/lab-ra.service <<'EOF'
[Unit]
Description=router のルータ広告（dnsmasq。社内 LAN に fd00:10::/64 を配る）
Requires=lab-net.service
After=lab-net.service

[Service]
ExecStart=/usr/bin/ip netns exec router /usr/sbin/dnsmasq --keep-in-foreground --conf-file=/etc/lab-net/router.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/lab-dns.service <<'EOF'
[Unit]
Description=server の DNS サーバ（dnsmasq。lab.example を答える）
Requires=lab-net.service
After=lab-net.service

[Service]
ExecStart=/usr/bin/ip netns exec server /usr/sbin/dnsmasq --keep-in-foreground --conf-file=/etc/lab-net/server.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/lab-web.service <<'EOF'
[Unit]
Description=server の HTTP サーバ（ncat。80/tcp）
Requires=lab-net.service
After=lab-net.service

[Service]
ExecStart=/usr/bin/ip netns exec server /usr/bin/ncat --keep-open --listen 80 --sh-exec /usr/local/lib/lab-net/www-reply
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/lab-board.service <<'EOF'
[Unit]
Description=社内掲示板（練習機の上の小さな HTTP サーバ。8080/tcp）
After=network.target

[Service]
EnvironmentFile=/etc/default/lab-board
ExecStart=/usr/bin/ncat --keep-open --listen ${LISTEN_ADDRESS} 8080 --sh-exec /usr/local/lib/lab-net/board-reply
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# ---- 4) ifupdown: lab0 だけ書いておく（gateway は旧ルータのまま） ---------------
cat > /etc/network/interfaces <<'EOF'
# interfaces(5) — ifupdown の設定ファイル。ifup / ifdown はこのファイルを読む。
#
# この練習機では、NIC ごとに設定する道具（持ち主）が違う:
#   enp0s16  管理用。netplan（/etc/netplan/）→ systemd-networkd が持つ。触らない
#   enp0s17  練習用。ifupdown が持つ（このファイルに書く）
#   enp0s18  練習用。NetworkManager が持つ（nmcli で設定する）
#   lab0     社内 LAN。ifupdown が持つ（下に書いてある）

source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

# 社内 LAN
auto lab0
iface lab0 inet static
    address 192.168.10.2/24
    gateway 192.168.10.254

iface lab0 inet6 auto
    privext 0
EOF
install -d -m 0755 /etc/network/interfaces.d

# ---- 5) 起動と、lab0 への設定 ---------------------------------------------------
systemctl daemon-reload
systemctl enable lab-net.service lab-ra.service lab-dns.service lab-web.service lab-board.service
systemctl start lab-net.service
ifup lab0
systemctl start lab-ra.service lab-dns.service lab-web.service lab-board.service

# ---- 6) 管理用の NIC からデフォルトルートと DNS を受け取らない --------------------
#   受け取ると、練習機の通信が管理用の NIC（QEMU の slirp）を通って読者の家や会社のネットワークへ出て、
#   読者ごとに画面が変わる（名前が引けたり引けなかったり、ping が返ったり返らなかったり）。
#   ssh と練習機の中の lab は 10.0.2.2 と直接つながっている（同じネットワーク）ので、デフォルトルートが無くても通る。
cat > /etc/netplan/01-lab-mgmt.yaml <<'EOF'
# 管理用の NIC。外（コンテナ）からの ssh と、練習機の中からの lab はここを通る。
# この NIC を止めると ssh が切れる。そのときは外で vm console（シリアル）から入る。
#
# ネットワークのコースでは、DHCP からデフォルトルートと DNS を受け取らない（use-routes / use-dns）。
# 練習機の「外」は、中に作った社内 LAN（lab0）だけにしてある。
network:
  version: 2
  ethernets:
    enp0s16:
      dhcp4: true
      dhcp4-overrides:
        use-routes: false
        use-dns: false
EOF
chmod 600 /etc/netplan/01-lab-mgmt.yaml
netplan apply

# ---- 7) DNS: 外の DNS に頼らない（予備の DNS サーバも空にする） ------------------
install -d -m 0755 /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/90-lab.conf <<'EOF'
# 練習機の外（読者の家や会社）の DNS には頼らない。組み込みの予備（FallbackDNS）も空にする。
[Resolve]
FallbackDNS=
EOF
systemctl restart systemd-resolved.service

# ---- 8) NetworkManager: enp0s18 だけを持たせる ---------------------------------
cat > /etc/NetworkManager/conf.d/90-lab.conf <<'EOF'
# この練習機の NetworkManager は enp0s18 だけを持つ（nmcli の練習用）。
# enp0s16 は netplan（systemd-networkd）、enp0s17 と lab0 は ifupdown が持つ。
[main]
# 接続の定義が無い NIC に「有線接続 1」を勝手に作って DHCP を始めない（作るのは読者）
no-auto-default=*
# DHCP で受け取った DNS サーバを systemd-resolved に渡さない（第8章の画面を揃えるため）
dns=none

[keyfile]
unmanaged-devices=*,except:interface-name:enp0s18

[connection]
# IPv6 のアドレスを MAC から作る（0 = eui64）。既定の stable-privacy は練習機ごとに乱数の鍵を作り、画面が揃わない。
# 値は数字で書く。"eui64" と書くと読まれず、stable-privacy のままだった（NetworkManager 1.46・実測 2026-10-13）
ipv6.addr-gen-mode=0
EOF
systemctl enable NetworkManager.service
systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
systemctl start NetworkManager.service

# ---- 9) /etc/hosts: 前任者が残した古い行（www.lab.example の移転前のアドレス）を1行入れる -----
#   丸ごと書き直す（中身を本文と一致させるため）。DNS では www.lab.example は 172.16.20.10。
cat > /etc/hosts <<'EOF'
127.0.0.1 localhost
127.0.1.1 linuc
172.16.20.99 www.lab.example

# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF

# ---- 10) 落ち着くのを待って、状態を記録する（provision.log に残る） ---------------
for _ in $(seq 1 60); do
  ip -6 addr show dev lab0 scope global | grep -q 'fd00:10::' && break
  sleep 1
done
ip -br addr
ip route
ip -6 route
nmcli device status || true
ss -tulpn || true
cat /etc/hosts
echo PROVISION_OK
