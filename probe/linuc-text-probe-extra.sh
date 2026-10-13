#!/bin/bash
# LinuC 主題1.03 の追加の記録（事実確認で直した箇所の裏付け。2026-10-13）。
# 1.0.0 を公開した後に足した記録。イメージ 1.0.1（lab/ の層だけを直したもの）で、probe と同じく取り直す。
#
# 走らせ方: bash probe/linuc-text-run.sh extra
#   章ごとに新しいコンテナで、読者と同じ起動オプション（--hostname linuc と2つのボリューム）で
#   bash -l -i /tmp/probe-extra.sh N を走らせ、logs/linuc-text-probe-extra.log にまとめる。
#   本文の雛形では、この記録から引くブロックを <pre><code>@@+ … @@</code></pre> と書く。
#
# 記録の約束は linuc-text-probe.sh と同じ（対話的なログインシェル、umask 022、pty の上の打鍵）。
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
S() { printf '\n\n========== %s ==========\n' "$*"; }
feed() { sleep 1.5; while IFS= read -r l; do printf '%s\n' "$l"; sleep 0.9; done; sleep 2; }
session() { feed | TERM=dumb script -qec "bash -i" /dev/null | tr -d '\r'; }
KEYS() {
  local show=$1 cmd=$2; shift 2
  printf '\n$ %s\n（打鍵: %s）\n' "$cmd" "$show"
  { sleep 1.2; for k in "$@"; do printf '%b' "$k"; sleep 0.5; done; sleep 1.2; } \
    | TERM=xterm script -qec "$cmd" /dev/null > /tmp/screen.raw 2>&1
  grep -ao 'E[0-9]\{2,3\}: [^[:cntrl:]]*' /tmp/screen.raw | sort -u
}
umask 022

ch=${1:-all}
want() { [ "$ch" = all ] || [ "$ch" = "$1" ]; }

if want 3; then
S "3. man の読み方（追加の記録）"
R 'cd ~/text'
R 'ls /usr/share/man/man3 | wc -l'
R 'ls /usr/share/man/man3 | head -3'
fi

if want 6; then
S "6. sed と整形（追加の記録）"
R 'cd ~/text'
R 'sed "s/^(port)=/\1: /" app.conf; echo "exit=$?"'
R 'sed "s/^\(port\)=/\1: /" app.conf | grep "^port:"'
R 'sed -E "s/^(port)=/\1: /" app.conf | grep "^port:"'
fi

if want 8; then
S "8. パイプと xargs と tee（追加の記録）"
R 'cd ~/text'
R 'seq 1 300000 | xargs echo | wc -l'
R 'printf "%s\n" "it'"'"'s.txt" | xargs echo; echo "exit=$?"'
R 'printf "%s\n" "it'"'"'s.txt" | xargs -d "\n" echo'
fi

if want 10; then
S "10. vi とエディタの切り替え（追加の記録）"
R 'cd ~/text'
R 'cp memo.txt ro3.txt; chmod 444 ro3.txt'
R 'ls -i ro3.txt'
KEYS 'dd :w!⏎ :q⏎' 'vim ro3.txt' 'dd' ':w!\r' ':q\r'
R 'ls -i ro3.txt'
R 'stat -c "%A %s %n" ro3.txt'
R 'cp memo.txt ro4.txt; chmod 444 ro4.txt; ln ro4.txt ro4-link.txt'
R 'ls -i ro4.txt ro4-link.txt'
KEYS 'dd :w!⏎ :q⏎' 'vim ro4.txt' 'dd' ':w!\r' ':q\r'
R 'ls -i ro4.txt ro4-link.txt'
R 'stat -c "%A %s %n" ro4.txt ro4-link.txt'
R 'VISUAL=nano EDITOR=vi sensible-editor --version < /dev/null | head -1'
R 'sudo grep -n -E "env_reset|EDITOR" /etc/sudoers'
R 'export EDITOR=vi'
R 'sudo env | grep "^EDITOR="; echo "exit=$?"'
R 'sudo EDITOR=vi env | grep "^EDITOR="'
R 'unset EDITOR'
echo
echo '--- ここから下は、端末（pty）の上で対話シェルを動かし、1行ずつ打鍵した記録 ---'
session <<'KEYIN'
 export PROMPT_COMMAND='PS1="\$ "'
echo "[$EDITOR]"; ls ~/.selected_editor
sensible-editor --version
2
cat ~/.selected_editor
sensible-editor --version < /dev/null | head -1
rm ~/.selected_editor
sensible-editor --version < /dev/null | head -1
exit
KEYIN
echo '--- 対話の記録ここまで ---'
fi
