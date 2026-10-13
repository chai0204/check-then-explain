#!/usr/bin/env bash
# 演習 06 の判定。観測型（~/work/06/vars.fd を開いている QEMU を /proc で探し、その QEMU が ~/work/06/linuc.qcow2 を開いて
# 127.0.0.1:2222 を待っているかを見て、ssh で入って UEFI で起動したかを見て、vars.fd の中にブートの項目が書き込まれたかを読む）。
set -uo pipefail
command -v ss >/dev/null && command -v qemu-img >/dev/null && command -v jq >/dev/null || { echo "前提不足: ss・qemu-img・jq のどれかが見つかりません（檻のイメージを確かめてください）"; exit 2; }
W=$HOME/work/06
vars=$W/vars.fd
TEMPLATE=/usr/share/OVMF/OVMF_VARS_4M.fd

echo "判定 : 観測型（vars.fd を開いている QEMU を探してディスクと待ち受けを見て、ssh で入って /sys/firmware/efi と efibootmgr を見て、vars.fd を読んだ）"
if [ ! -f "$vars" ]; then
  echo "観測 : ~/work/06/vars.fd が無い"
  exit 1
fi
pid=""
for p in $(pgrep -x qemu-system-x86); do
  for fd in /proc/"$p"/fd/*; do
    [ "$(readlink "$fd" 2>/dev/null)" = "$vars" ] && { pid=$p; break 2; }
  done
done
disk=""; back=""; lpid=""
if [ -n "$pid" ]; then
  # その QEMU が開いているディスク（土台と NVRAM を除く）と、127.0.0.1:2222 で待っているプロセス
  disk=$(for fd in /proc/"$pid"/fd/*; do readlink "$fd"; done 2>/dev/null | grep -E '\.qcow2$|\.raw$|\.img$' | grep -v '^/var/lib/lab-vm/' | sort -u | head -3 | paste -sd' ')
  lpid=$(ss -Htlnp 'sport = :2222' 2>/dev/null | sed -n 's/.*pid=\([0-9]*\).*/\1/p' | head -1)
fi
if [ -f "$W/linuc.qcow2" ]; then
  back=$(qemu-img info -U --output=json "$W/linuc.qcow2" 2>/dev/null | jq -r '."full-backing-filename" // ."backing-filename" // ""')
fi
if [ -n "$pid" ]; then
  echo "観測 : ~/work/06/vars.fd を開いている QEMU → PID $pid"
  echo "       その QEMU が開いているディスク → ${disk:-（見つからない）}"
  echo "       127.0.0.1:2222 で待っているプロセス → ${lpid:-いない}$([ -n "$lpid" ] && [ "$lpid" = "$pid" ] && echo "（同じ QEMU）")"
else
  echo "観測 : ~/work/06/vars.fd を開いている QEMU → いない"
fi
echo "       ~/work/06/linuc.qcow2 の土台（backing file）→ ${back:-なし}"
same=no
cmp -s "$vars" "$TEMPLATE" && same=yes
nboot=$(tr -d '\000' < "$vars" | grep -ac 'shimx64.efi')
echo "       vars.fd とひな形（$TEMPLATE）→ $([ "$same" = yes ] && echo 同じ（まだ何も書き込まれていない） || echo 違う（書き込まれた）)"
echo "       vars.fd の中の \\EFI\\ubuntu\\shimx64.efi を指す項目 → $nboot 個"

out=$(ssh -o BatchMode=yes -o ConnectTimeout=5 linuc 'if [ -d /sys/firmware/efi ]; then echo fw=UEFI; else echo fw=BIOS; fi; efibootmgr 2>&1 | grep -E "^(BootCurrent|Boot[0-9A-F]{4}\*? Ubuntu)"' 2>&1); rc=$?
if [ $rc -ne 0 ] && ! grep -q '^fw=' <<<"$out"; then
  echo "       ssh linuc → 入れない（$(tail -1 <<<"$out" | tr -d '\r')）"
else
  echo "       ssh linuc → 入れた。練習機のファームウェア → $(sed -n 's/^fw=//p' <<<"$out")"
  grep -E '^(BootCurrent|Boot)' <<<"$out" | sed 's/^/         efibootmgr: /'
fi

ng=0
[ -n "$pid" ] || { echo "       → vars.fd を NVRAM として開いて動いている QEMU がいない"; ng=1; }
if [ -n "$pid" ]; then
  grep -q "^$W/linuc.qcow2\$" <<<"$(tr ' ' '\n' <<<"$disk")" || { echo "       → その QEMU は ~/work/06/linuc.qcow2 から起動していない"; ng=1; }
  [ "$lpid" = "$pid" ] || { echo "       → 127.0.0.1:2222 で待っているのが、vars.fd を開いた QEMU ではない（ssh linuc は別の練習機に入る）"; ng=1; }
fi
[ "$back" = /var/lib/lab-vm/linuc-guest.qcow2 ] || { echo "       → ~/work/06/linuc.qcow2 が土台の上の差分ディスクになっていない"; ng=1; }
grep -q '^fw=UEFI' <<<"$out" || { echo "       → ssh で入った練習機が UEFI で起動していない（入れないか、BIOS で起動している）"; ng=1; }
[ "$same" = no ] && [ "$nboot" -ge 1 ] || { echo "       → vars.fd にブートの項目（Ubuntu）が書き込まれていない"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       練習機は UEFI で起動し、そのときの「Ubuntu」のブートの項目が vars.fd に書き込まれている"
echo "       → NVRAM はファイル。次に同じ vars.fd で起動すると、その項目から起動する"
exit 0
