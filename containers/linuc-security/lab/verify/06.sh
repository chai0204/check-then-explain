#!/usr/bin/env bash
# 演習06 の判定。観測型（authorized_keys の中身と、sshd が鍵を無視しない権限かを実際に見る）。
# 練習機から返す値は「名前=値」の形にする。ディレクトリが無いときに行の位置がずれて
# 別の値を読む（1.0.0 で .ssh が無いと dssh に区切りの文字列が入った）のを防ぐ。
set -uo pipefail
ak=/home/deploy/.ssh/authorized_keys
info=$(lab-guest "
  st() { stat -c '%a %U' \"\$1\" 2>/dev/null || echo '-'; }
  echo \"HOME=\$(st /home/deploy)\"
  echo \"SSH=\$(st /home/deploy/.ssh)\"
  echo \"AK=\$(st $ak)\"
  echo \"KEYS=\$(grep -cE '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-)' $ak 2>/dev/null || echo 0)\"
"); rc=$?
[ "$rc" -eq 125 ] && { echo "前提不足: 練習機が応答しません（外の端末で vm start / vm status）"; exit 2; }

val() { printf '%s\n' "$info" | sed -n "s/^$1=//p" | head -1; }
home=$(val HOME); dssh=$(val SSH); akst=$(val AK); nkey=$(val KEYS)
case "$nkey" in ''|*[!0-9]*) nkey=0 ;; esac

show() { [ "$1" = "-" ] || [ -z "$1" ] && echo "無い" || echo "$1"; }
echo "判定 : 観測型（authorized_keys の鍵数と、ホーム・.ssh・鍵ファイルの権限を見た）"
echo "観測 : /home/deploy      = $(show "$home")"
echo "       /home/deploy/.ssh = $(show "$dssh")"
echo "       authorized_keys   = $(show "$akst")（公開鍵 ${nkey} 本）"

# モードが8進の数字として読めるときだけ計算する（無いときは「無い」として扱う）
isoct() { printf '%s' "$1" | grep -qE '^[0-7]{3,4}$'; }
ng=0
[ "$nkey" -ge 1 ] || { echo "       → authorized_keys に公開鍵が無い"; ng=1; }
hmode=${home%% *}; smode=${dssh%% *}; kmode=${akst%% *}; kuser=${akst##* }
# sshd の StrictModes: ホーム・.ssh・鍵が本人以外に書けると、その鍵を使わない
if isoct "$hmode" && [ $(( 8#${hmode} & 022 )) -ne 0 ]; then echo "       → ホームが group か other に書ける"; ng=1; fi
if isoct "$smode" && [ $(( 8#${smode} & 077 )) -ne 0 ]; then echo "       → .ssh が本人以外にも開いている"; ng=1; fi
if isoct "$kmode" && [ $(( 8#${kmode} & 077 )) -ne 0 ]; then echo "       → authorized_keys が本人以外にも開いている"; ng=1; fi
if [ "$akst" != "-" ] && [ -n "$kuser" ] && [ "$kuser" != deploy ]; then echo "       → authorized_keys の持ち主が deploy でない（$kuser）"; ng=1; fi
[ "$ng" = 0 ] || exit 1

echo "       鍵が登録され、ホーム・.ssh・鍵の権限が StrictModes の条件を満たす"
exit 0
