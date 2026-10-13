#!/usr/bin/env bash
# 演習 02 の判定。観測型（パスワードでの認証を禁じた ssh を実際に打ち、id_rsa だけで入れるかを見る）。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値（system）に引きずられないよう固定する

lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機の中から応答がありません（電源が切れている・起動の途中・systemd を通らない起動（init=/bin/bash など）のどれか）。virsh domstate linuc と virsh console linuc で状態を見てください"; exit 2; }

k=$HOME/.ssh/id_rsa
echo "判定 : 観測型（パスワードを禁じた ssh を、~/.ssh/id_rsa だけを持たせて実際に打った）"
printf '観測 : 秘密鍵 ~/.ssh/id_rsa     → %s\n' "$([ -f "$k" ] && echo 有る || echo 無い)"
printf '       公開鍵 ~/.ssh/id_rsa.pub → %s\n' "$([ -f "$k.pub" ] && echo 有る || echo 無い)"
{ [ -f "$k" ] && [ -f "$k.pub" ]; } || exit 1

fp=$(ssh-keygen -lf "$k.pub" 2>/dev/null)
echo "       公開鍵の指紋             → ${fp:-読めない}"
body=$(awk '{print $2}' "$k.pub")
n=$(lab-guest "grep -c -F -- '$body' /home/student/.ssh/authorized_keys 2>/dev/null" 2>/dev/null)
echo "       練習機の /home/student/.ssh/authorized_keys にこの公開鍵 → ${n:-0} 行"
kh=$(ssh-keygen -F '[127.0.0.1]:2222' 2>/dev/null | grep -vc '^#')
echo "       ~/.ssh/known_hosts に練習機（[127.0.0.1]:2222）の鍵 → ${kh:-0} 件"

res=$(ssh -o BatchMode=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no \
          -o IdentitiesOnly=yes -i "$k" -o ConnectTimeout=15 linuc 'echo ok' 2>&1); src=$?
res=$(printf '%s' "$res" | tr -d '\r')   # ssh のエラー文は行末に CR が付き、表示の行頭を上書きする（実測）
echo "       ssh -i ~/.ssh/id_rsa（パスワード禁止）→ 終了コード $src（$(printf '%s' "$res" | tail -1)）"
[ "$src" -eq 0 ] && [ "$(printf '%s' "$res" | tail -1)" = ok ] || exit 1

echo "       パスワードを使わず、id_rsa の鍵だけで練習機の student に入れた"
exit 0
