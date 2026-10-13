#!/usr/bin/env bash
# LinuC 主題1.07（ネットワークの基礎）の本文の記録。外側のコンテナの中で lab として走らせる。
#
#   docker run -d --name linuc-network-probe --hostname host \
#     -v linuc-network-probe-vm:/home/lab/vm -v linuc-network-probe-state:/home/lab/.lab \
#     --stop-timeout 30 lab-linuc-network:1.0.1     （読者と同じ起動オプション。KVM なし）
#   （練習機の初回の準備 ~/vm/.provisioned ができるまで待つ）
#   docker cp probe/linuc-network-probe.sh linuc-network-probe:/tmp/probe.sh
#   docker exec -u lab -w /home/lab linuc-network-probe bash /tmp/probe.sh > logs/linuc-network-probe.log 2>&1
#
# 記録の "$ " 行は読者が打つ形で書く。練習機の中で打つものは ssh linuc を付けない（G）。外で打つものは H。
# 章の順に、読者と同じ道筋で状態を変えていく（第2章で付けたアドレスが第3章の ifup を失敗させる、など）。
set -u
# 練習機の中（student@linuc）で打つもの。読者は ssh linuc で入った端末で打つので、擬似端末（80桁）で実行し、
# 色のエスケープと行末の \r だけを落として記録する（ss は端末かどうかで桁の間隔が変わる。実測 2026-10-13）。
# 読者と同じく対話のシェル（bash -i）で打つ。違いが出るのは bash 自身のメッセージ（command not found の書式、
# & で裏に回したジョブの [1] 1234 / [1]+ Done の行）。~/.bashrc の alias（ls / grep の色）は色だけなので落とす。
G() {
  printf '\n$ %s\n' "$*"
  local q; q=$(printf '%q' "$*")
  TERM=xterm ssh -tt -n -o LogLevel=QUIET linuc "stty cols 80 rows 50 2>/dev/null; export SYSTEMD_PAGER=cat PAGER=cat; bash -ic $q" 2>&1 \
    | tr -d '\r' | sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/\x1b\][^\x07]*\x07//g'
}
H() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }          # 外（lab@host）で打つもの
Q() { ssh -n linuc "$*" >/dev/null 2>&1; }                # 記録しない待ち合わせ（読者が次を打つまでの数秒の代わり）
section() { printf '\n\n########## %s ##########\n' "$*"; }
settle6() { Q 'for i in $(seq 1 40); do ip -6 addr show dev lab0 scope global | grep -q "fd00:10::" && ! ip -6 addr show dev lab0 | grep -q tentative && ip -6 route show default | grep -q lab0 && exit 0; sleep 1; done'; }
wait_guest() {
  sleep 15
  for _ in $(seq 1 120); do ssh -n -o ConnectTimeout=3 linuc true >/dev/null 2>&1 && return 0; sleep 2; done
  echo "（練習機が戻らない）"; return 1
}

section "0. 環境"
H lab env
H vm status
H 'qemu-system-x86_64 --version | head -1'
H 'virsh domstate linuc'
G 'cat /etc/os-release | head -4'
G 'uname -r'
G 'dpkg-query -W iproute2 ifupdown network-manager net-tools iputils-ping iputils-tracepath traceroute netcat-openbsd ncat bind9-dnsutils dnsmasq-base ipcalc systemd'
H 'bash -lic true'

section "1. アドレスとマスク（01-address）"
G 'ip -4 addr show'
G 'ipcalc 192.168.10.2/24'
G 'ipcalc -b 192.168.10.2 255.255.255.0'
G 'ipcalc 192.168.10.0/24 /25'
G 'ipcalc -b 192.168.10.0/24 /26 | tail -3'
G 'ipcalc -b 192.168.10.130/25'
G 'ip route get 192.168.10.200'
G 'ip route get 192.168.11.1'
G 'ipcalc -b 10.0.2.15/24'
G 'ipcalc -b 172.16.20.10/24'
G 'ipcalc -b 172.32.0.1/16'
G 'ipcalc -b 203.0.113.10/24'
G 'ipcalc -b 127.0.0.1/8'

section "2. NIC を手で設定する（02-interface）"
G 'ip link show'
G 'sudo ip netns exec sw ip link show p-linuc'
G "ifconfig | grep '^[a-z]'"
G "ifconfig -a | grep '^[a-z]'"
G 'ip addr show enp0s17'
G 'ifconfig enp0s17'
G 'sudo ip link set enp0s17 up'
Q 'sleep 3'
G 'ip addr show enp0s17'
G 'sudo ip addr add 10.0.3.50/24 dev enp0s17'
G 'ip -4 addr show enp0s17'
G 'ping -c 2 10.0.3.2'
G 'ip neigh show dev enp0s17'
G 'sudo ip addr add 10.0.3.51/24 dev enp0s17'
G 'ip -4 addr show enp0s17'
G 'ifconfig enp0s17'
G 'sudo ip addr add 10.0.3.52/24 dev enp0s17 label enp0s17:1'
G "ifconfig | grep '^[a-z]'"
G 'ifconfig enp0s17:1'
G 'sudo ifconfig enp0s17 10.0.3.60 netmask 255.255.255.0'
G 'ip -4 addr show enp0s17'
G 'sysctl net.ipv4.conf.enp0s17.promote_secondaries'
G 'sudo ifconfig enp0s17 10.0.3.50 netmask 255.255.255.0'
G 'ip -4 addr show enp0s17'
G 'ip addr enp0s17'
G 'ip a show enp0s17'
G 'ip -s link show enp0s17'
G 'sudo ip link set enp0s17 down'
G 'ip addr show enp0s17'
G 'sysctl net.ipv6.conf.enp0s17.keep_addr_on_down'
G 'ip route'
G 'sudo ip link set enp0s17 up'
Q 'sleep 3'
G 'ip -6 addr show enp0s17'
G 'ip route'
G 'ping -c 1 10.0.3.2'

section "3. 設定の持ち主（03-owner）"
G 'cat /etc/network/interfaces'
G 'ifquery --list'
G 'sudo ifup enp0s17'
G "printf 'auto enp0s17\niface enp0s17 inet static\n    address 10.0.3.50/24\n' | sudo tee /etc/network/interfaces.d/enp0s17"
G 'ifquery --list'
G 'ifquery enp0s17'
G 'sudo ifup enp0s17'
G 'ifquery --state'
G 'sudo ifdown enp0s17'
G 'ip -4 addr show enp0s17'
G 'sudo ip addr flush dev enp0s17'
G 'sudo ifup enp0s17'
G 'ifquery --state'
G 'ip -4 addr show enp0s17'
G 'sudo ifdown enp0s17'
G 'ip addr show enp0s17'
G 'sudo ifup enp0s17'
Q 'sleep 2'
G 'ping -c 1 10.0.3.2'
G 'nmcli device status'
G 'cat /etc/NetworkManager/conf.d/90-lab.conf'
G 'nmcli connection show'
G 'sudo nmcli connection add type ethernet ifname enp0s18 con-name lab-dhcp'
G 'nmcli -f NAME,TYPE,DEVICE connection show'
G 'sudo nmcli connection up lab-dhcp'
G 'nmcli device status'
G 'ip -4 addr show enp0s18'
G 'nmcli -f IP4 device show enp0s18'
G 'ls /etc/netplan/'
G 'sudo nmcli connection modify lab-dhcp ipv4.method manual ipv4.addresses 10.0.4.50/24'
G 'ip -4 addr show enp0s18'
G 'sudo nmcli connection up lab-dhcp'
G 'ip -4 addr show enp0s18'
G "sudo nmcli connection modify lab-dhcp ipv4.method auto ipv4.addresses ''"
G 'sudo nmcli connection up lab-dhcp'
G 'ip -4 addr show enp0s18'
G 'nmcli -g ipv4.method,connection.autoconnect connection show lab-dhcp'
G 'nmcli --help'
G 'nmcli general help'
G 'nmcli general status'
G 'nmcli general hostname'
G 'nmcli general monitor'
G 'nmcli networking'
G 'networkctl'
G 'sudo cat /etc/netplan/01-lab-mgmt.yaml'
G 'sudo nmcli device connect enp0s17'
G 'sudo cat /etc/netplan/01-lab-mgmt.yaml'

section "4. 経路（04-route）"
G 'ping -c 3 172.16.20.10'
G 'ping6 -c 2 fd00:20::10'
G 'ip route'
G 'route -n'
G 'netstat -rn'
G 'ip route get 172.16.20.10'
G 'ip route get 10.0.2.2'
G 'traceroute -n 172.16.20.10'
G 'sudo ip route del default'
G 'ip route'
G 'ping -c 1 172.16.20.10'
G 'sudo ip route add default via 192.168.10.1'
G 'ip route show default'
G 'ping -c 2 172.16.20.10'
G 'route -n'
G 'sudo ip route add default via 192.168.10.254'
G 'sudo route add default gw 192.168.10.254'
G 'ip route show default'
G 'ip route get 172.16.20.10'
G 'ping -c 1 172.16.20.10'
G 'sudo route del default gw 192.168.10.254'
G 'ip route show default'
G 'sudo route add -host 203.0.113.5 gw 192.168.10.254'
G 'route -n'
G 'ip route get 203.0.113.5'
G 'ping -c 1 203.0.113.5'
G 'sudo route del -host 203.0.113.5 gw 192.168.10.254'
G 'ip -r route'
G 'sudo ifdown lab0'
G 'sudo ifup lab0'
settle6
G 'ip route show default'
G 'ping -c 1 172.16.20.10'
G "sudo sed -i 's/gateway 192.168.10.254/gateway 192.168.10.1/' /etc/network/interfaces"
G 'ifquery lab0'
G 'sudo ifdown lab0'
G 'sudo ifup lab0'
settle6
G 'ip route show default'
G 'ping -c 2 172.16.20.10'
G 'ip -6 route show default'

section "5. 経路をたどる（05-trace）"
G 'traceroute -n 172.16.20.10'
G 'traceroute 172.16.20.10'
G 'sudo tcpdump -l -n -t -i lab0 -c 4 "udp or icmp" 2>/dev/null & sleep 2; traceroute -n -q 1 -N 1 172.16.20.10; wait'
G 'ping -c 1 -t 1 172.16.20.10'
G 'ping -c 1 -t 2 172.16.20.10'
G 'traceroute -I -n 172.16.20.10'
G 'sysctl net.ipv4.ping_group_range'
G 'getcap /usr/bin/ping'
G "sudo sysctl -w net.ipv4.ping_group_range='0 2147483647'"
G 'traceroute -I -n 172.16.20.10'
G "sudo sysctl -w net.ipv4.ping_group_range='1 0'"
G 'sudo traceroute -I -n 172.16.20.10'
G 'sudo traceroute -I -n -N 1 172.16.20.10'
G 'tracepath -n 172.16.20.10'
G 'tracepath 172.16.20.10'
G 'sudo ip netns exec router iptables -A OUTPUT -p icmp --icmp-type time-exceeded -j DROP'
G 'traceroute -n 172.16.20.10'
G 'tracepath -n 172.16.20.10'
G 'ping -c 1 172.16.20.10'
G 'sudo ip netns exec router iptables -D OUTPUT -p icmp --icmp-type time-exceeded -j DROP'
G 'traceroute -n 172.16.20.10'
G 'ip netns list'
G 'sudo ip netns exec router ip route'

section "6. IPv6（06-ipv6）"
G 'ifquery lab0'
G 'ip -6 addr show lab0'
G 'ip link show lab0'
G 'ip -6 addr show enp0s17'
G 'ip -6 route'
G 'ping6 -c 1 fe80::5054:ff:fe0a:1'
G 'ping6 -c 1 fe80::5054:ff:fe0a:1%lab0'
G 'ping -c 1 fe80::5054:ff:fe0a:1%lab0'
G 'ping6 -c 2 -w 3 ff02::1%lab0'
G 'ip -6 neigh show dev lab0'
G 'ping6 -c 2 fd00:20::10'
G 'traceroute6 -n fd00:20::10'
G 'tracepath -6 -n fd00:20::10'
G 'tracepath6 fd00:20::10'
G "python3 -c 'import ipaddress; print(ipaddress.ip_address(\"fd00:10::5054:ff:fe0a:2\").exploded)'"
G "grep ip6 /etc/hosts"
G 'ping6 -c 1 ip6-localhost'

section "7. プロトコルとポート（07-ports）"
G "grep -wE '^(ssh|smtp|domain|http|ntp|https)' /etc/services"
G "grep -E '^(pop3|imap2|snmp|snmp-trap|ldap|syslog)[[:space:]]' /etc/services"
G 'ss -tuln'
G 'sudo ss -tulnp'
G 'sudo netstat -tulnp'
G 'netstat -tn'
G 'netstat -tan'
G 'timeout 2 netstat -tcp; echo $?'
G "ncat -lk 9000 & sleep 1; ss -tlnp | grep -E 'State|8080|9000'; kill %1; wait"
G 'curl -s http://127.0.0.1:8080/'
G 'nc -zv 127.0.0.1 8080'
G 'nc -zv 192.168.10.2 8080'
G 'sudo ip netns exec router nc -zv 192.168.10.2 8080'
G 'sudo ip netns exec router nc -zv 192.168.10.2 22'
G 'cat /etc/default/lab-board'
G 'systemctl cat lab-board | grep ExecStart'
G 'sudo ip netns exec server ss -tulnp'
G 'nc -zv 172.16.20.10 80'
G 'nc -zv 172.16.20.10 25'
G 'nc -zv 172.16.20.10 443'
G "printf 'GET / HTTP/1.0\r\n\r\n' | nc 172.16.20.10 80"
G 'nc -zuv 172.16.20.10 53'
G 'nc -zuv 172.16.20.10 123; echo $?'
G 'ncat -zuv 172.16.20.10 123'
G 'ncat -zv 172.16.20.10 25'
G 'sudo tcpdump -l -n -t -i lab0 -c 2 "tcp port 25" 2>/dev/null & sleep 2; nc -zv 172.16.20.10 25; wait'
G 'sudo tcpdump -l -n -t -i lab0 -c 2 "port 123 or icmp" 2>/dev/null & sleep 2; nc -zuv 172.16.20.10 123; wait'
G 'sudo tcpdump -l -n -t -i lab0 -c 3 "tcp port 80" 2>/dev/null & sleep 2; nc -zv 172.16.20.10 80; wait'
G "sudo sed -i 's/^LISTEN_ADDRESS=.*/LISTEN_ADDRESS=0.0.0.0/' /etc/default/lab-board"
G 'sudo systemctl restart lab-board'
Q 'sleep 2'
G 'ss -tln'
G 'nc -zv 192.168.10.2 8080'
G 'sudo ip netns exec router curl -s http://192.168.10.2:8080/'

section "8. DNS（08-dns）"
G 'ls -l /etc/resolv.conf'
G 'cat /etc/resolv.conf'
G 'resolvectl status'
G 'host server.lab.example'
G 'getent hosts server.lab.example; echo $?'
G 'dig @172.16.20.10 server.lab.example'
G 'host server.lab.example 172.16.20.10'
G "echo 'nameserver 172.16.20.10' | sudo tee -a /etc/resolv.conf"
G 'host server.lab.example'
G 'sudo systemctl restart systemd-resolved'
G "grep -v '^#' /etc/resolv.conf"
G 'host server.lab.example'
G 'sudo resolvectl dns lab0 172.16.20.10'
G 'sudo resolvectl domain lab0 lab.example'
G 'resolvectl status lab0'
G "grep -v '^#' /etc/resolv.conf"
G 'host server'
G 'host www.lab.example'
G 'sudo resolvectl revert lab0'
G 'host server'
G 'sudo unlink /etc/resolv.conf'
G "printf 'nameserver 172.16.20.10\nsearch lab.example\n' | sudo tee /etc/resolv.conf"
G 'ls -l /etc/resolv.conf'
G 'dig server.lab.example'
G 'dig +short server.lab.example'
G 'host server'
G 'dig +short server'
G 'dig +short +search server'
G "printf 'nameserver 172.16.20.10\nsearch lab.example\nsearch nosuch.lab.example\n' | sudo tee /etc/resolv.conf"
G 'host server'
G "printf 'nameserver 172.16.20.10\nsearch nosuch.lab.example lab.example\n' | sudo tee /etc/resolv.conf"
G 'host server'
G "printf 'nameserver 172.16.20.10\nsearch lab.example\n' | sudo tee /etc/resolv.conf"
G 'host www.lab.example'
G 'dig +short -x 172.16.20.10'
G 'host 172.16.20.10'
G 'dig +short MX lab.example'
G 'host -t MX lab.example'
G 'dig +short AAAA server.lab.example'
G 'dig +noall +answer web.lab.example'
G 'host nosuch.lab.example'
G 'host example.com'
G 'dig server.lab.example | grep SERVER'
G 'dig +tcp server.lab.example | grep SERVER'
G 'dig +vc server.lab.example | grep SERVER'
G 'dig --tcp server.lab.example'
G 'dig +t server.lab.example'
G 'dig -t MX +short lab.example'
G 'dig -p 53 +short @172.16.20.10 server.lab.example'
G 'traceroute 172.16.20.10'
G 'sudo systemctl restart systemd-resolved'
G 'cat /etc/resolv.conf'
G 'getent hosts ns.lab.example'

section "9. 名前の表の順番（09-names）"
G 'dig +short www.lab.example'
G 'ping -c 1 www.lab.example'
G 'curl -s -m 3 http://www.lab.example/; echo $?'
G "grep '^hosts' /etc/nsswitch.conf"
G 'getent ahosts www.lab.example'
G 'cat /etc/hosts'
G "sudo sed -i '/www.lab.example/d' /etc/hosts"
G 'getent ahosts www.lab.example'
G 'ping -c 1 www.lab.example'
G 'curl -s http://www.lab.example/'
G "echo '172.16.20.88 ns.lab.example' | sudo tee -a /etc/hosts"
G 'getent ahosts ns.lab.example'
G "sudo sed -i 's/^hosts:.*/hosts:          dns files/' /etc/nsswitch.conf"
G "grep '^hosts' /etc/nsswitch.conf"
G 'getent ahosts ns.lab.example'
G "sudo sed -i 's/^hosts:.*/hosts:          files dns/' /etc/nsswitch.conf"
G "sudo sed -i '/172.16.20.88/d' /etc/hosts"
G 'getent hosts server.lab.example'
G 'getent ahosts server.lab.example'
G "echo '172.16.20.77 server.lab.example' | sudo tee -a /etc/hosts"
G 'getent hosts server.lab.example'
G 'getent ahosts server.lab.example'
G 'ping -c 1 server.lab.example'
G "sudo sed -i '/172.16.20.77/d' /etc/hosts"
G 'hostname'
G 'cat /etc/hostname'
G 'grep 127.0.1.1 /etc/hosts'
G 'hostname -I'
G 'hostname -s'
G 'hostname -i'
G 'hostname -f'
G 'sudo hostname web01'
G 'hostname'
G 'cat /etc/hostname'
G 'sudo true'
G 'hostname -f'
G 'sudo systemctl reboot'
wait_guest
settle6
G 'hostname'
G 'sudo true'
G 'ip route show default'
G 'ifquery --state'
G 'nmcli device status'
G 'cat /etc/resolv.conf'
G 'ss -tln | grep 8080'
G 'sudo hostnamectl set-hostname web01'
G 'cat /etc/hostname'
G 'hostnamectl hostname'
G 'sudo true'
G 'sudo hostnamectl set-hostname linuc'
G 'sudo true'
G 'cat /etc/hostname'
G 'sudo nmcli general hostname web03'
G 'cat /etc/hostname'
G 'sudo nmcli general hostname linuc'
G 'cat /etc/hostname'
G 'sudo hostname -b web02'
G 'hostname'
G 'sudo hostname -F /etc/hostname'
G 'hostname'

section "付録. ifupdown の dhcp（最後に試す: dhcpcd が enp0s17 の IPv6 の設定を書き換えて戻さないため）"
G 'sysctl net.ipv6.conf.enp0s17.addr_gen_mode net.ipv4.conf.enp0s17.promote_secondaries'
G 'sudo ifdown enp0s17'
G "printf 'auto enp0s17\niface enp0s17 inet dhcp\n' | sudo tee /etc/network/interfaces.d/enp0s17"
G 'sudo ifup enp0s17'
G 'ip addr show enp0s17'
G 'ps -eo pid,args | grep [d]hcpcd'
G 'sudo ifdown enp0s17'
G "printf 'auto enp0s17\niface enp0s17 inet static\n    address 10.0.3.50/24\n' | sudo tee /etc/network/interfaces.d/enp0s17"
G 'sudo ifup enp0s17'
Q 'sleep 3'
G 'ip addr show enp0s17'
G 'sysctl net.ipv6.conf.enp0s17.addr_gen_mode net.ipv4.conf.enp0s17.promote_secondaries'
