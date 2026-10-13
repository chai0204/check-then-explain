#!/usr/bin/env bash
# 演習 03 の判定。観測型（実際に dave として入ってみる）。
#   1) 外から dave の鍵で ssh してみる
#   2) 練習機の中で root から su - dave してみる（PAM のアカウント検査とログインシェルを通る）
#   3) dave の行・ホーム・ファイル・鍵が残っているかを見る
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外の端末で vm start）"; exit 2; }
G() { lab-guest "$@" 2>/dev/null; }

# 対照: student なら入れること（入れないなら sshd かネットワークの問題で、この演習の判定ができない）
if ! ssh -o BatchMode=yes -o ConnectTimeout=20 linuc true >/dev/null 2>&1; then
  echo "前提不足: student でも ssh で入れません（sshd か管理用の NIC が止まっていませんか）"
  exit 2
fi
pw=$(G 'getent passwd dave')
[ -n "$pw" ] || { echo "観測 : getent passwd dave → 何も返らない（dave の行が台帳から消えている）"; exit 1; }

echo "判定 : 観測型（外から dave の鍵で ssh し、中で root から su - dave して、実際に入れるかを見た）"
sshout=$(ssh -o BatchMode=yes -o ConnectTimeout=20 -l dave linuc 'echo IN-AS-$(id -un)' 2>&1)
suout=$(lab-guest "su - dave -c 'echo IN-AS-\$(id -un)'" 2>&1)
st=$(G 'passwd -S dave')
exp=$(G 'chage -l dave' | sed -n 's/^Account expires[[:space:]]*:[[:space:]]*//p')
shell=$(cut -d: -f7 <<<"$pw")

echo "観測 : ssh -l dave linuc（鍵）→ $(tr '\n' ' ' <<<"$sshout" | sed 's/ *$//')"
echo "       su - dave（練習機の中、root から）→ $(tr '\n' ' ' <<<"${suout:-（出力なし）}" | sed 's/ *$//')"
echo "       passwd -S dave → $st"
echo "       アカウントの有効期限 → ${exp:-（読めない）}"
echo "       ログインシェル → $shell"

ng=0
grep -q 'IN-AS-dave' <<<"$sshout" && { echo "       → 鍵での ssh で dave としてコマンドが動いた"; ng=1; }
grep -q 'IN-AS-dave' <<<"$suout"  && { echo "       → su - dave で dave としてコマンドが動いた"; ng=1; }
G 'test -f /home/dave/notes.txt' >/dev/null || { echo "       → /home/dave/notes.txt が無い（ファイルは残す条件）"; ng=1; }
G 'test -s /home/dave/.ssh/authorized_keys' >/dev/null || { echo "       → /home/dave/.ssh/authorized_keys が無い（鍵は消さない条件）"; ng=1; }

[ "$ng" = 0 ] || exit 1
echo "       台帳の行・ホーム・ファイル・鍵は残ったまま、ssh でも su でも dave として動けない"
echo "       → 止めたのはパスワードの欄ではなく、アカウントそのもの（期限かシェル）"
exit 0
