#!/usr/bin/env bash
# 演習07 の判定。観測型（deploy として、暗号文を実際に復号してみる）。
set -uo pipefail
have=$(lab-guest -u deploy 'gpg -k >/dev/null 2>&1 && gpg --list-secret-keys 2>/dev/null | grep -c "^sec"'); rc=$?
[ "$rc" -eq 125 ] && { echo "前提不足: 練習機が応答しません（外の端末で vm start / vm status）"; exit 2; }

# deploy のホームにある *.gpg を1つ選び、秘密鍵で復号できるか試す（パスフレーズは空の前提）
dec=$(lab-guest -u deploy '
  f=$(ls -1 "$HOME"/*.gpg 2>/dev/null | head -1)
  [ -n "$f" ] || { echo "NOFILE"; exit 0; }
  echo "FILE=$f"
  gpg --batch --pinentry-mode loopback --passphrase "" --decrypt "$f" >/tmp/dec.$$ 2>/dev/null \
    && { echo "DECRYPT_OK"; head -c 200 /tmp/dec.$$; } || echo "DECRYPT_NG"
  rm -f /tmp/dec.$$
')

file=$(printf '%s\n' "$dec" | sed -n 's/^FILE=//p' | head -1)
ok=$(printf '%s\n' "$dec" | grep -c DECRYPT_OK)

echo "判定 : 観測型（deploy の秘密鍵で暗号文を実際に復号してみた）"
echo "観測 : 秘密鍵の本数 = ${have:-0}"
echo "       暗号文ファイル = ${file:-（見つからない）}"

ng=0
[ "${have:-0}" -ge 1 ] 2>/dev/null || { echo "       → deploy の鍵束に秘密鍵が無い"; ng=1; }
if [ "$ok" -ge 1 ]; then
  echo "       復号できた（公開鍵で暗号化 → 秘密鍵で復号の一往復が成立）"
else
  echo "       → 暗号文が無い、または deploy の秘密鍵で復号できない"
  ng=1
fi
[ "$ng" = 0 ] || exit 1
exit 0
