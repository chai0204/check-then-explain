#!/usr/bin/env bash
# 演習06 の判定。観測型（authorized_keys の中身と、sshd が鍵を無視しない権限かを実際に見る）。
set -uo pipefail
ak=/home/deploy/.ssh/authorized_keys
info=$(lab-guest "
  stat -c '%a %U' /home/deploy        2>/dev/null
  stat -c '%a %U' /home/deploy/.ssh   2>/dev/null
  stat -c '%a %U' $ak                 2>/dev/null
  echo '===KEYS==='
  grep -cE '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-)' $ak 2>/dev/null
"); rc=$?
[ "$rc" -eq 125 ] && { echo "前提不足: 練習機が応答しません（外の端末で vm start / vm status）"; exit 2; }

home=$(printf '%s\n' "$info" | sed -n '1p')
dssh=$(printf '%s\n' "$info" | sed -n '2p')
akst=$(printf '%s\n' "$info" | sed -n '3p')
nkey=$(printf '%s\n' "$info" | sed -n '/===KEYS===/,$p' | sed '1d' | head -1)

echo "判定 : 観測型（authorized_keys の鍵数と、ホーム・.ssh・鍵ファイルの権限を見た）"
echo "観測 : /home/deploy      = ${home:-無い}"
echo "       /home/deploy/.ssh = ${dssh:-無い}"
echo "       authorized_keys   = ${akst:-無い}（公開鍵 ${nkey:-0} 本）"

ng=0
[ "${nkey:-0}" -ge 1 ] 2>/dev/null || { echo "       → authorized_keys に鍵が無い"; ng=1; }
# sshd の StrictModes: ホーム・.ssh・鍵が group/other に書けると鍵を無視する
hmode=${home%% *}; smode=${dssh%% *}; kmode=${akst%% *}; kuser=${akst##* }
[ -n "$hmode" ] && [ $(( 8#${hmode} & 022 )) -ne 0 ] && { echo "       → ホームが group/other に書ける（sshd は鍵を無視する）"; ng=1; }
[ -n "$smode" ] && [ $(( 8#${smode} & 077 )) -ne 0 ] && { echo "       → .ssh が本人以外に開いている（700 にする）"; ng=1; }
[ -n "$kmode" ] && [ $(( 8#${kmode} & 077 )) -ne 0 ] && { echo "       → authorized_keys が本人以外に開いている（600 にする）"; ng=1; }
[ -n "$kuser" ] && [ "$kuser" != deploy ] && { echo "       → authorized_keys の持ち主が deploy でない（$kuser）"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       鍵が登録され、権限も StrictModes に適合（sshd はこの鍵を使う）"
exit 0
