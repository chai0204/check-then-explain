#!/usr/bin/env bash
# LinuC 主題1.07 の演習7本を、新しい練習機で「解く前は ✗ → 模範解答どおりに操作すると ✔」の両方向で確かめる。
# 外側のコンテナの中で lab として走らせる（起動のしかたは probe/linuc-network-probe.sh と同じ）。
#   docker exec -u lab -w /home/lab linuc-network-solve bash /tmp/probe.sh > logs/linuc-network-solve-all.log 2>&1
# 途中の「直しかけ」でも ✗ になること（04: 経路表だけ直した / 06: リンク先に1行足しただけ）も記録する。
set -u
# 練習機の中（student@linuc）で打つもの。読者は ssh linuc で入った端末で打つので、擬似端末（80桁）で実行し、
# 色のエスケープと行末の \r だけを落として記録する（ss は端末かどうかで桁の間隔が変わる。実測 2026-10-13）。
G() {
  printf '\n$ %s\n' "$*"
  TERM=xterm ssh -tt -n -o LogLevel=QUIET linuc "stty cols 80 rows 50 2>/dev/null; export SYSTEMD_PAGER=cat PAGER=cat; $*" 2>&1 \
    | tr -d '\r' | sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/\x1b\][^\x07]*\x07//g'
}
H() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }          # 外で打つもの
Q() { ssh -n linuc "$*" >/dev/null 2>&1; }
section() { printf '\n\n########## %s ##########\n' "$*"; }
settle6() { Q 'for i in $(seq 1 40); do ip -6 addr show dev lab0 scope global | grep -q "fd00:10::" && ! ip -6 addr show dev lab0 | grep -q tentative && ip -6 route show default | grep -q lab0 && exit 0; sleep 1; done'; }

section "0. 環境と一覧"
H lab env
H lab ls
H lab start 01

section "演習 01"
H lab check 01
G 'sudo ip link set enp0s17 up'
G 'sudo ip addr add 10.0.3.50/24 dev enp0s17'
Q 'sleep 2'
H lab check 01
G 'lab check 01'

section "演習 02"
H lab check 02
G "printf 'auto enp0s17\niface enp0s17 inet static\n    address 10.0.3.50/24\n' | sudo tee /etc/network/interfaces.d/enp0s17"
G 'sudo ifup enp0s17'
H lab check 02
G 'sudo ip addr flush dev enp0s17'
G 'sudo ifup enp0s17'
Q 'sleep 2'
H lab check 02

section "演習 03"
H lab check 03
G 'sudo nmcli connection add type ethernet ifname enp0s18 con-name lab-dhcp'
G 'sudo nmcli connection up lab-dhcp'
H lab check 03

section "演習 04"
H lab check 04
G 'sudo route del default gw 192.168.10.254'
G 'sudo route add default gw 192.168.10.1'
G 'route -n'
H lab check 04
G "sudo sed -i 's/gateway 192.168.10.254/gateway 192.168.10.1/' /etc/network/interfaces"
G 'sudo ifdown lab0'
G 'sudo ifup lab0'
settle6
H lab check 04

section "演習 05"
H lab check 05
G "sudo sed -i 's/^LISTEN_ADDRESS=.*/LISTEN_ADDRESS=0.0.0.0/' /etc/default/lab-board"
G 'sudo systemctl restart lab-board'
Q 'sleep 2'
H lab check 05

section "演習 06"
H lab check 06
G "echo 'nameserver 172.16.20.10' | sudo tee -a /etc/resolv.conf"
G 'getent hosts ns.lab.example'
H lab check 06
G 'sudo unlink /etc/resolv.conf'
G "printf 'nameserver 172.16.20.10\nsearch lab.example\n' | sudo tee /etc/resolv.conf"
H lab check 06

section "演習 07"
H lab check 07
G 'getent ahosts www.lab.example'
G "sudo sed -i '/www.lab.example/d' /etc/hosts"
G 'getent ahosts www.lab.example'
H lab check 07

section "全体"
H lab ls
H lab check
