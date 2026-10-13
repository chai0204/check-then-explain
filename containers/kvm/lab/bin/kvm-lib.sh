# 判定（verify）が共通で使う観測の道具。外側（lab@host）で lab として動く。verify から source する。
#
# 練習機の様子は2つの場所から観測する。
#   外: QEMU のプロセスが開いているファイル（/proc/PID/fd）。KVM を使う QEMU は、カーネルの中に作った
#       仮想マシンを anon_inode:kvm-vm というファイルとして持っている。TCG の QEMU は持っていない。
#   中: ssh linuc で練習機の OS に尋ねる（systemd-detect-virt・/proc/cpuinfo・journal）。
VM=$HOME/vm

qpid() {   # 動いている QEMU の PID（qemu-linuc の記録、無ければ名前で探す）
  local p; p=$(cat "$VM/qemu.pid" 2>/dev/null)
  if [ -n "$p" ] && [ "$(cat "/proc/$p/comm" 2>/dev/null)" = qemu-system-x86 ]; then echo "$p"; return 0; fi
  pgrep -n -x qemu-system-x86
}
uses_kvm() { readlink "/proc/$1/fd/"* 2>/dev/null | grep -qx 'anon_inode:kvm-vm'; }
g() { ssh -o BatchMode=yes -o ConnectTimeout=5 linuc "$@" 2>/dev/null; }   # 練習機の中で（student として）

host_has_kvm() {   # docker が動いているカーネルに KVM があり、CPU が仮想化支援の印を出しているか
  [ -d /sys/module/kvm ] && grep -q -w -E 'vmx|svm' /proc/cpuinfo
}
kvm_err() {   # この檻の lab が /dev/kvm を読み書きで開けないときの理由（開ければ空）
  local e; e=$( { exec 3<>/dev/kvm; } 2>&1 ) && return 0
  printf '%s' "${e##*: }"
}

# KVM が要る演習の前提。この檻で /dev/kvm を開けなければ、前提不足（exit 2）で理由を出して終わる
need_kvm() {
  if [ ! -e /dev/kvm ]; then
    if host_has_kvm; then
      echo "前提不足: この檻には /dev/kvm がありません（--device /dev/kvm を付けずに起動しています。演習02）"
    else
      echo "前提不足: docker が動いているカーネルに KVM が見当たりません（/sys/module/kvm が無いか、CPU が vmx・svm を名乗っていない）。"
      echo "          この演習は、本文の記録で読んでください"
    fi
    exit 2
  fi
  local e; e=$(kvm_err)
  [ -z "$e" ] || { echo "前提不足: この檻の lab は /dev/kvm を開けません（$e。演習02）"; exit 2; }
}

# 練習機が動いていて、中の OS が ssh に応答するか。動いていなければ未達（1）、応答しなければ前提不足（2）
need_running() {
  QP=$(qpid) || { echo "観測 : 練習機（QEMU のプロセス）が動いていない"; exit 1; }
  g true || { echo "前提不足: 練習機の ssh が応答しません（起動の途中なら、少し待ってからもう一度）"; exit 2; }
}

guest_cpu() {   # 練習機の中の CPU の名乗り: 「メーカー / モデル名 / 仮想化支援の印」
  g "lscpu | sed -n 's/^Vendor ID: *//p'; lscpu | sed -n 's/^Model name: *//p'; grep -o -w -m1 -E 'vmx|svm' /proc/cpuinfo | head -1" \
    | paste -sd'|' | awk -F'|' '{ printf "%s / %s / 仮想化支援の印 %s", $1, $2, ($3 == "" ? "なし" : $3) }'
}
# CPU の名乗り「メーカー|family|model|stepping|モデル名」（/proc/cpuinfo の最初の CPU から）。
# モデル名は -cpu …,model-id= で付け替えられるので、型番（family・model・stepping）も一緒に比べる
ident_of() {
  awk -F'\t*: ' '/^vendor_id/ {v=$2} /^cpu family/ {f=$2} /^model\t/ {m=$2} /^model name/ {n=$2} /^stepping/ {s=$2}
                 /^$/ {exit} END {printf "%s|%s|%s|%s|%s\n", v, f, m, s, n}'
}
host_ident()  { ident_of </proc/cpuinfo; }
guest_ident() { g cat /proc/cpuinfo | ident_of; }
ident_show()  { awk -F'|' '{ printf "%s / %s（family %s・model %s・stepping %s）", $1, $5, $2, $3, $4 }'; }
host_nested() {   # あなたの PC の KVM が入れ子の仮想化を許しているか（Intel は Y / N、AMD は 1 / 0。分からなければ空）
  cat /sys/module/kvm_intel/parameters/nested /sys/module/kvm_amd/parameters/nested 2>/dev/null | head -1
}

guest_kvm() {   # 練習機の中の /dev/kvm（入れ子の仮想化の入口）
  g 'if [ -e /dev/kvm ]; then echo "ある（$(lsmod | grep -o -m1 -E "^kvm_(intel|amd)")）"; else echo "無い"; fi'
}
