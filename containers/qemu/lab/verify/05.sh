#!/usr/bin/env bash
# 演習 05 の判定。観測型（127.0.0.1:2222 で待っているプロセスを ss で探し、そのプロセスが開いているディスクを
# /proc で見て、そのディスクが土台の上の差分かを qemu-img で読み、実際に ssh で入って練習機の中の NIC を読む）。
set -uo pipefail
command -v ss >/dev/null && command -v qemu-img >/dev/null && command -v jq >/dev/null || { echo "前提不足: ss・qemu-img・jq のどれかが見つかりません（檻のイメージを確かめてください）"; exit 2; }
W=$HOME/work/05

echo "判定 : 観測型（127.0.0.1:2222 の待ち受けを ss で探し、そのプロセスのディスクを /proc と qemu-img で見て、ssh で入った）"
line=$(ss -Htlnp 'sport = :2222' 2>/dev/null | head -1)
if [ -z "$line" ]; then
  echo "観測 : 127.0.0.1:2222 で待ち受けているプロセスが無い"
  exit 1
fi
pid=$(sed -n 's/.*pid=\([0-9]*\).*/\1/p' <<<"$line")
comm=$(sed -n 's/.*(("\([^"]*\)".*/\1/p' <<<"$line")
args=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
disk=$(for fd in /proc/"$pid"/fd/*; do readlink "$fd"; done 2>/dev/null | grep -E '\.qcow2$|\.raw$|\.img$' | grep -v '^/var/lib/lab-vm/' | sort -u | head -3 | paste -sd' ')
back=""
if [ -f "$W/linuc.qcow2" ]; then
  back=$(qemu-img info -U --output=json "$W/linuc.qcow2" 2>/dev/null | jq -r '."full-backing-filename" // ."backing-filename" // ""')
fi
echo "観測 : 127.0.0.1:2222 で待っている → ${comm:-?}（PID ${pid:-?}）"
echo "       そのプロセスが開いているディスク → ${disk:-（見つからない）}"
echo "       ~/work/05/linuc.qcow2 の土台（backing file）→ ${back:-なし}"
libvirt=no
grep -q -- '-name guest=linuc' <<<"$args" && libvirt=yes
[ "$libvirt" = yes ] && echo "       そのプロセスの引数 → libvirt が組み立てたもの（-name guest=linuc）"

out=$(ssh -o BatchMode=yes -o ConnectTimeout=5 linuc 'ip -br -4 addr show enp0s16; echo "conn=$SSH_CONNECTION"' 2>&1); rc=$?
if [ $rc -ne 0 ]; then
  echo "       ssh linuc → 入れない（$(tail -1 <<<"$out" | tr -d '\r')）"
else
  echo "       ssh linuc → 入れた"
  echo "         練習機の NIC（ip -br -4 addr show enp0s16）→ $(grep -v '^conn=' <<<"$out" | head -1 | tr -s ' ')"
  echo "         練習機から見た接続元 → $(sed -n 's/^conn=\([^ ]*\).*/\1/p' <<<"$out")"
fi

ng=0
case "$comm" in qemu-system*) ;; *) echo "       → 待っているのが QEMU ではない"; ng=1 ;; esac
[ "$libvirt" = no ] || { echo "       → libvirt（vm / virsh）が起動した練習機。自分の qemu-system-x86_64 で起動していない"; ng=1; }
grep -q "^$W/linuc.qcow2\$" <<<"$(tr ' ' '\n' <<<"$disk")" || { echo "       → ~/work/05/linuc.qcow2 から起動していない"; ng=1; }
[ "$back" = /var/lib/lab-vm/linuc-guest.qcow2 ] || { echo "       → ~/work/05/linuc.qcow2 が土台 /var/lib/lab-vm/linuc-guest.qcow2 の上の差分ディスクになっていない（写しか、別の土台）"; ng=1; }
if [ $rc -ne 0 ]; then
  echo "       → ssh で入れない（起動の途中なら、30〜60 秒待ってからもう一度）"; ng=1
elif ! grep -q '10\.0\.2\.15/24' <<<"$out"; then
  echo "       → 練習機の enp0s16 に 10.0.2.15 が付いていない"; ng=1
fi
[ "$ng" = 0 ] || exit 1

echo "       外の 127.0.0.1:2222 を待っているのは QEMU のプロセスで、届いた接続を練習機の 22 番へ渡している"
echo "       → 練習機の NIC は enp0s16 という名前で見え、QEMU の中の DHCP から 10.0.2.15 をもらっている"
exit 0
