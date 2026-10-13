#!/bin/bash
# QEMU の記事: 本文の端末ブロックには出さないが、本文・入口ページ・演習の解答の文で述べていることを確かめた記録。
# （本文の文が引く数は、この記録のもの。第3章・第4章・第5章・第6章の注と、事実確認の指摘への答え）
#
# 走らせ方（入口ページの起動コマンドと同じ檻。名前とボリュームだけ probe 用）:
#   docker run --rm -d -t --name qemu-extra --hostname host -v /home/lab/work -v /home/lab/.lab lab-qemu:1.0.0
#   docker cp probe/qemu-probe-extra.sh qemu-extra:/tmp/extra.sh
#   docker exec qemu-extra bash -l /tmp/extra.sh > logs/qemu-probe-extra.log 2>&1
#   docker stop -t 3 qemu-extra
set -u
LAST=0
R() {
  local cmd="$1" first=1 line
  while IFS= read -r line; do
    if [ "$first" = 1 ]; then printf '\n$ %s\n' "$line"; first=0
    else printf '> %s\n' "$line"; fi
  done <<< "$cmd"
  (exit "$LAST"); eval "$cmd" 2>&1
  LAST=$?
}
S() { printf '\n\n========== %s ==========\n' "$*"; }
# 後ろで動かした QEMU が全部終わるまで待つ（記録には出さない待ち）
waitq() { while pgrep -x qemu-system-x86 > /dev/null; do sleep 0.3; done; }
mkdir -p ~/work/x && cd ~/work/x || exit 1
# socat -v の記録（送られた塊ごとに「> 時刻 length=…」の見出しが付く。CR は \r と書かれる）から、
# 各バイトが流れた時刻を戻し、最後の「login: 」と「\r と空白と \r」の時刻を出す（第17節で使う）
cat > /tmp/dumptime.pl <<'PL'
local $/; my $d = <>;
my @p = split /> (\d{4}\/\d\d\/\d\d \d\d:\d\d:\d\d)\.\d+\s+length=\d+ from=\d+ to=\d+\n/, $d;
my ($s, @m) = ("");
for (my $i = 1; $i < @p; $i += 2) { my $x = $p[$i+1] // ""; $x =~ s/\\r/\r/g; push @m, [length($s), $p[$i]]; $s .= $x; }
sub at { my ($pos, $t) = (shift, ""); for (@m) { last if $_->[0] > $pos; $t = $_->[1]; } $t }
my $l = rindex($s, "login: ");
printf "最後の「login: 」が流れた時刻: %s\n", at($l) if $l >= 0;
while ($s =~ /\r( {20,})\r/g) { printf "「\\r と空白 %d 個と \\r」が流れた時刻: %s\n", length($1), at($-[0]); }
PL

S "1. 入口ページの注: 演習 05 と 06 の練習機を同時に動かすと、2つ目の hostfwd（127.0.0.1:2222）が断られる"
R 'qemu-system-x86_64 -display none -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=n0 -qmp unix:first.sock,server=on,wait=off -daemonize'
R 'ss -tlnp'
R 'qemu-system-x86_64 -machine q35 -display none -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=n0,addr=0x10 -daemonize; echo "終了コード: $?"'
R 'pgrep -c -x qemu-system-x86'
R "printf '%s\n' '{\"execute\":\"qmp_capabilities\"}' '{\"execute\":\"quit\"}' | socat - UNIX-CONNECT:first.sock"
waitq

S "2. 第1章・第5章・第7章: -machine の値が、どの版のマシン型になるか（QMP の qom-get /machine type）"
R "qemu-system-x86_64 -machine help | grep -E '^(ubuntu|pc|ubuntu-q35|q35) '"
R 'for m in "" "-machine pc" "-machine q35" "-machine ubuntu"; do
  qemu-system-x86_64 $m -display none -S -qmp unix:m.sock,server=on,wait=off -daemonize
  printf "%-18s → " "${m:-（指定なし）}"
  printf "%s\n" "{\"execute\":\"qmp_capabilities\"}" "{\"execute\":\"qom-get\",\"arguments\":{\"path\":\"/machine\",\"property\":\"type\"}}" "{\"execute\":\"quit\"}" | socat -t 3 - UNIX-CONNECT:m.sock 2>/dev/null | grep -o "\"return\": \"[^\"]*\""
  while pgrep -x qemu-system-x86 > /dev/null; do sleep 0.2; done
done'

S "3. 第2章・演習01: -nographic と -daemonize（行き先を全部指定すれば通る）"
R 'qemu-system-x86_64 -nographic -daemonize; echo "終了コード: $?"'
R 'qemu-system-x86_64 -nographic -daemonize -serial file:serial.log -qmp unix:qmp.sock,server=on,wait=off; echo "終了コード: $?"'
R 'qemu-system-x86_64 -nographic -daemonize -serial file:serial.log -qmp unix:qmp.sock,server=on,wait=off -parallel none; echo "終了コード: $?"'
R "printf '%s\n' '{\"execute\":\"qmp_capabilities\"}' '{\"execute\":\"qom-get\",\"arguments\":{\"path\":\"/machine\",\"property\":\"graphics\"}}' '{\"execute\":\"quit\"}' | socat - UNIX-CONNECT:qmp.sock"
waitq

S "4. 第2章: -nographic のときの線のつながり方（端末が要るので script で疑似端末を作る。Ctrl-a c で切り替えて info chardev）"
R "{ sleep 3; printf '\\001c'; sleep 1; printf 'info chardev\\r'; sleep 1; printf 'quit\\r'; sleep 1; } | script -qec 'qemu-system-x86_64 -nographic' /dev/null | tr -d '\\r' | grep -a 'filename='"
waitq

S "5. 第2章: Ctrl-C（0x03）は、-serial stdio なら QEMU を止め、-serial mon:stdio なら仮想の PC に届く"
R "{ sleep 3; printf '\\003'; sleep 2; } | script -qec 'qemu-system-x86_64 -display none -serial stdio' /dev/null | tr -d '\\r'; echo \"QEMU のプロセス: \$(pgrep -c -x qemu-system-x86) 個\""
R "{ sleep 3; printf '\\003'; sleep 2; echo \"Ctrl-C の2秒後の QEMU のプロセス: \$(pgrep -c -x qemu-system-x86) 個\" >&2; printf '\\001x'; sleep 1; } | script -qec 'qemu-system-x86_64 -display none -serial mon:stdio' /dev/null | tr -d '\\r'"
waitq

S "6. 第2章: QMP のソケットのファイルが残るのは、-daemonize が作業ディレクトリを / に移すから"
R 'mkdir -p sock && cd sock && ls -A'
R 'qemu-system-x86_64 -display none -qmp unix:rel.sock,server=on,wait=off -daemonize; readlink /proc/$(pgrep -x qemu-system-x86)/cwd'
R "printf '%s\n' '{\"execute\":\"qmp_capabilities\"}' '{\"execute\":\"quit\"}' | socat -t 2 - UNIX-CONNECT:rel.sock > /dev/null 2>&1; while pgrep -x qemu-system-x86 > /dev/null; do sleep 0.2; done; ls *.sock"
R "qemu-system-x86_64 -display none -qmp unix:\$PWD/abs.sock,server=on,wait=off -daemonize; printf '%s\n' '{\"execute\":\"qmp_capabilities\"}' '{\"execute\":\"quit\"}' | socat -t 2 - UNIX-CONNECT:abs.sock > /dev/null 2>&1; while pgrep -x qemu-system-x86 > /dev/null; do sleep 0.2; done; ls *.sock"
R "qemu-system-x86_64 -display none -qmp unix:bg.sock,server=on,wait=off > /dev/null 2>&1 & until [ -S bg.sock ]; do sleep 0.2; done; printf '%s\n' '{\"execute\":\"qmp_capabilities\"}' '{\"execute\":\"quit\"}' | socat -t 2 - UNIX-CONNECT:bg.sock > /dev/null 2>&1; wait; ls *.sock"
R 'cd .. && rm -rf sock first.sock m.sock qmp.sock serial.log && ls -A'

S "7. 第3章: -snapshot の一時ファイルは、開いた直後に名前が消されている"
R 'qemu-img create -q -f qcow2 -b /var/lib/lab-vm/linuc-guest.qcow2 -F qcow2 snap.qcow2'
R 'qemu-system-x86_64 -display none -drive file=snap.qcow2,if=virtio -snapshot -qmp unix:s.sock,server=on,wait=off -daemonize'
R 'ls -A /var/tmp'
R 'for fd in /proc/$(pgrep -x qemu-system-x86)/fd/*; do readlink $fd; done | grep -E "qcow2|/var/tmp"'
R "printf '%s\n' '{\"execute\":\"qmp_capabilities\"}' '{\"execute\":\"quit\"}' | socat -t 2 - UNIX-CONNECT:s.sock > /dev/null 2>&1; while pgrep -x qemu-system-x86 > /dev/null; do sleep 0.2; done; rm -f snap.qcow2"

S "8. 第3章: 内部スナップショットを消すと、ふつうは disk size が減る。loadvm で戻った後は減らない"
R 'qemu-img create -q -f qcow2 -b /var/lib/lab-vm/linuc-guest.qcow2 -F qcow2 d.qcow2'
R 'hmp() { printf "%s\n" "{\"execute\":\"qmp_capabilities\"}" "{\"execute\":\"human-monitor-command\",\"arguments\":{\"command-line\":\"$1\"}}" | socat -t 600 - UNIX-CONNECT:q.sock > /dev/null 2>&1; }
boot() { : > ser.log; qemu-system-x86_64 -m 1536 -smp 2 -drive file=d.qcow2,if=virtio -display none -serial file:ser.log -qmp unix:q.sock,server=on,wait=off -daemonize; until grep -q "login:" ser.log; do sleep 1; done; }
halt() { printf "%s\n" "{\"execute\":\"qmp_capabilities\"}" "{\"execute\":\"quit\"}" | socat -t 3 - UNIX-CONNECT:q.sock > /dev/null 2>&1; while pgrep -x qemu-system-x86 > /dev/null; do sleep 0.3; done; }
size() { echo "ls -l $(stat -c %s d.qcow2) バイト / $(qemu-img info d.qcow2 | grep "^disk size")"; }
echo "（hmp・boot・halt・size を定義した）"'
R 'boot; hmp "savevm s1"; halt; size'
R 'qemu-img snapshot -d s1 d.qcow2; size'
R 'boot; hmp "savevm s2"; hmp "loadvm s2"; halt; size'
R 'qemu-img snapshot -d s2 d.qcow2; size'
R 'rm -f d.qcow2 ser.log'

S "9. 第6章: NVRAM を qcow2 で渡すと savevm は通る。第6章の並べ方（NVRAM が先）では、動いている状態は NVRAM の qcow2 のほうに入る"
R 'qemu-img create -q -f qcow2 -b /var/lib/lab-vm/linuc-guest.qcow2 -F qcow2 d.qcow2; qemu-img convert -O qcow2 /usr/share/OVMF/OVMF_VARS_4M.fd vars.qcow2'
R ': > ser.log; qemu-system-x86_64 -machine q35 -m 1536 -smp 2 -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd -drive if=pflash,format=qcow2,file=vars.qcow2 -drive file=d.qcow2,if=virtio -display none -serial file:ser.log -qmp unix:q.sock,server=on,wait=off -daemonize; until grep -q "login:" ser.log; do sleep 1; done; hmp "savevm s1"; halt'
R 'qemu-img snapshot -l vars.qcow2'
R 'qemu-img snapshot -l d.qcow2'
R 'rm -f d.qcow2 vars.qcow2 ser.log'

S "10. 第5章: 練習機の OS がまだネットワークを上げていないとき、hostfwd の入口は接続を受け取ったまま返事をしない（ディスクの無い PC で試す）"
R 'qemu-system-x86_64 -display none -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=n0 -qmp unix:h.sock,server=on,wait=off -daemonize'
R 'SECONDS=0; exec 3<>/dev/tcp/127.0.0.1/2222 && echo "つながった: ${SECONDS} 秒"; cat <&3; echo "切れた: ${SECONDS} 秒"; exec 3<&-'
R 'SECONDS=0; ssh -o ConnectTimeout=30 linuc true; echo "ssh の終了コード: $? / ${SECONDS} 秒"'
R "printf '%s\n' '{\"execute\":\"qmp_capabilities\"}' '{\"execute\":\"quit\"}' | socat -t 2 - UNIX-CONNECT:h.sock > /dev/null 2>&1; while pgrep -x qemu-system-x86 > /dev/null; do sleep 0.2; done"

S "11. 第5章: 練習機が起動していて待ち受けが無い番号は、すぐ切られる。127.0.0.1 以外から来た接続は、そのアドレスのまま見える"
R 'qemu-img create -q -f qcow2 -b /var/lib/lab-vm/linuc-guest.qcow2 -F qcow2 d.qcow2'
R 'qemu-system-x86_64 -machine q35 -m 1536 -smp 2 -drive file=d.qcow2,if=virtio -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=tcp:127.0.0.1:2223-:23,hostfwd=tcp::2224-:22 -device virtio-net-pci,netdev=n0,addr=0x10 -display none -serial file:ser.log -qmp unix:q.sock,server=on,wait=off -daemonize'
R 'until ssh -o ConnectTimeout=3 linuc true 2>/dev/null; do sleep 3; done; echo "ssh linuc に入れた"'
R 'SECONDS=0; exec 3<>/dev/tcp/127.0.0.1/2223 && echo "2223 につながった: ${SECONDS} 秒"; cat <&3; echo "切れた: ${SECONDS} 秒"; exec 3<&-'
R 'ip -br -4 addr show eth0'
R "ssh linuc 'echo \$SSH_CONNECTION'"
R "ssh -o HostName=\$(ip -br -4 addr show eth0 | awk '{print \$3}' | cut -d/ -f1) -o Port=2224 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR linuc 'echo \$SSH_CONNECTION'"
R 'halt; rm -f d.qcow2 ser.log'

S "12. 第4章・演習04: 5秒の -d in_asm の塊の数（5回）と、何度も翻訳された番地"
R "for i in 1 2 3 4 5; do timeout 5 qemu-system-x86_64 -display none -d in_asm -D tcg\$i.log 2>/dev/null; echo \"\$i 回目: IN: \$(grep -c '^IN:' tcg\$i.log) 個 / 番地の種類 \$(grep -A1 '^IN:' tcg\$i.log | grep '^0x' | sort -u | wc -l)\"; done"
R "grep -A1 '^IN:' tcg1.log | grep '^0x' | sort | uniq -c | sort -rn | head -3"
R 'rm -f tcg?.log'

S "13. 地形図: ライブマイグレーションは特権が要らない（同じ檻の中の QEMU から QEMU へ移す）"
R 'grep CapEff /proc/self/status'
R 'qemu-system-x86_64 -display none -qmp unix:dst.sock,server=on,wait=off -incoming tcp:127.0.0.1:4444 -daemonize; qemu-system-x86_64 -display none -qmp unix:src.sock,server=on,wait=off -daemonize'
R "printf '%s\n' '{\"execute\":\"qmp_capabilities\"}' '{\"execute\":\"migrate\",\"arguments\":{\"uri\":\"tcp:127.0.0.1:4444\"}}' | socat - UNIX-CONNECT:src.sock"
R "sleep 3; printf '%s\n' '{\"execute\":\"qmp_capabilities\"}' '{\"execute\":\"query-migrate\"}' | socat - UNIX-CONNECT:src.sock | tail -1 | jq -c '.return | {status, \"total-time\"}'"
R "for s in src dst; do printf '%s: ' \$s; printf '%s\n' '{\"execute\":\"qmp_capabilities\"}' '{\"execute\":\"query-status\"}' '{\"execute\":\"quit\"}' | socat -t 2 - UNIX-CONNECT:\$s.sock 2>/dev/null | grep -o '\"status\": \"[a-z-]*\"'; done; while pgrep -x qemu-system-x86 > /dev/null; do sleep 0.2; done"

S "14. 第7章・まとめ: 動いている QEMU に、QMP の device_add で部品を足せる"
R 'qemu-system-x86_64 -display none -qmp unix:da.sock,server=on,wait=off -daemonize'
R "printf '%s\n' '{\"execute\":\"qmp_capabilities\"}' '{\"execute\":\"device_add\",\"arguments\":{\"driver\":\"virtio-rng-pci\",\"id\":\"rng-added\"}}' '{\"execute\":\"qom-list\",\"arguments\":{\"path\":\"/machine/peripheral\"}}' '{\"execute\":\"quit\"}' | socat - UNIX-CONNECT:da.sock"
waitq

S "15. 第6章・演習06・用語辞書: OVMF の NVRAM のひな形と、Secure Boot 用の組"
R 'ls -l /usr/share/OVMF/'
R 'for f in /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS_4M.ms.fd; do printf "%s: Boot の名前（UTF-16LE）%s 個 / PK %s 個\n" $f $(grep -a -o -P "B\x00o\x00o\x00t\x00" $f | wc -l) $(grep -a -o -P "P\x00K\x00\x00\x00" $f | wc -l); done'
R 'jq -c "{targets, features, code: .mapping.executable.filename, vars: .mapping.\"nvram-template\".filename}" /usr/share/qemu/firmware/40-edk2-x86_64-secure-enrolled.json'
R 'export LIBVIRT_DEFAULT_URI=qemu:///session; mkdir -p ~/vm; sed "s|@VMDIR@|$HOME/vm|g" /etc/lab-vm/domain.xml.in > ~/vm/linuc.xml; virsh define ~/vm/linuc.xml > /dev/null; virsh dumpxml linuc | grep -E "machine=|<loader|<nvram"; virsh undefine --nvram linuc > /dev/null; rm -f ~/vm/linuc.xml'

S "16. 第3章・第6章・演習03: savevm の状態は、-drive で先に並べた書き込める qcow2 に入る（電源を入れて数秒で保存する）"
R 'order() { : > ser.log; qemu-system-x86_64 "$@" -display none -qmp unix:q.sock,server=on,wait=off -daemonize; sleep 5; hmp "savevm s1"; halt; }
show() { for f in "$@"; do printf "%-12s VM SIZE %s\n" $f "$(qemu-img snapshot -l $f | awk "NR==3{print \$3, \$4}")"; done; }
CODE="-drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd"
echo "（order・show を定義した）"'
R 'qemu-img create -q -f qcow2 -b /var/lib/lab-vm/linuc-guest.qcow2 -F qcow2 d.qcow2; qemu-img convert -O qcow2 /usr/share/OVMF/OVMF_VARS_4M.fd vars.qcow2'
R 'order -machine q35 -m 1536 $CODE -drive if=pflash,format=qcow2,file=vars.qcow2 -drive file=d.qcow2,if=virtio; show vars.qcow2 d.qcow2'
R 'rm -f d.qcow2 vars.qcow2; qemu-img create -q -f qcow2 -b /var/lib/lab-vm/linuc-guest.qcow2 -F qcow2 d.qcow2; qemu-img convert -O qcow2 /usr/share/OVMF/OVMF_VARS_4M.fd vars.qcow2'
R 'order -machine q35 -m 1536 -drive file=d.qcow2,if=virtio $CODE -drive if=pflash,format=qcow2,file=vars.qcow2; show vars.qcow2 d.qcow2'
R 'qemu-img create -q -f qcow2 a.qcow2 1G; qemu-img create -q -f qcow2 b.qcow2 1G'
R 'order -m 512 -drive file=b.qcow2,if=virtio -drive file=a.qcow2,if=virtio; show a.qcow2 b.qcow2'
R 'rm -f d.qcow2 vars.qcow2 a.qcow2 b.qcow2 ser.log'

S "17. 第3章の注: 練習機のコンソールのプロンプトが消えるとき（\\r と空白と \\r）と、systemd-fsckd の退場の時刻"
R 'qemu-img create -q -f qcow2 -b /var/lib/lab-vm/linuc-guest.qcow2 -F qcow2 d.qcow2'
R 'qemu-system-x86_64 -machine q35 -m 1536 -smp 2 -drive file=d.qcow2,if=virtio -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=n0,addr=0x10 -display none -chardev socket,id=s0,path=ser.sock,server=on,wait=on -serial chardev:s0 -qmp unix:q.sock,server=on,wait=off > /dev/null 2>&1 &
until [ -S ser.sock ]; do sleep 0.1; done
socat -v -u UNIX-CONNECT:ser.sock /dev/null 2> ser.dump &
until ssh -o ConnectTimeout=3 linuc true 2>/dev/null; do sleep 3; done; sleep 40; echo "ssh に入れてから 40 秒待った"'
R 'perl /tmp/dumptime.pl ser.dump'
R "ssh linuc 'journalctl -b -o short-iso-precise --no-pager -u systemd-fsckd.service; journalctl -b -o short-iso-precise --no-pager | grep -E \"systemd-fsck\\[\" | tail -2'"
R 'halt; wait; rm -f d.qcow2 ser.sock ser.dump'
R 'pgrep -c -x qemu-system-x86; ls -A ~/work/x'
