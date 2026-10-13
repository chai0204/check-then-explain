#!/usr/bin/env bash
# 演習 03 の判定。観測型（所有者と権限を読み、alice として実際に2回実行する）。
set -uo pipefail
f=/usr/local/bin/greet
id alice >/dev/null 2>&1 || { echo "前提不足: ユーザ alice がいません（イメージが違う可能性）"; exit 2; }
sudo -n true 2>/dev/null || { echo "前提不足: sudo がパスワードなしで使えません"; exit 2; }

want="こんにちは、alice さん。今日は $(date +%-m月%-d日) です"
echo "判定 : 観測型（$f の所有者と権限を読み、alice として greet を名前だけで2回実行した）"
if [ ! -e "$f" ]; then
  echo "観測 : $f が無い"
  exit 1
fi
owner=$(stat -c %U "$f"); group=$(stat -c %G "$f"); mode=$(stat -c %a "$f"); perm=$(stat -c %A "$f")
echo "観測 : $f  $perm（$mode）所有者 $owner グループ $group"

# 1回目: alice のログインシェルから（alice の起動ファイルが作る PATH で探す）
out1=$(cd /tmp && sudo -iu alice greet 2>&1); rc1=$?
# 2回目: date と id という名前の偽物を PATH の先頭に置いた人として
fake=$(mktemp -d /tmp/labchk03.XXXXXX)
printf '#!/bin/sh\necho "偽物の date"\n' > "$fake/date"
printf '#!/bin/sh\necho "偽物の id"\n'   > "$fake/id"
chmod 755 "$fake" "$fake/date" "$fake/id"
out2=$(cd /tmp && sudo -u alice env PATH="$fake:/usr/local/bin:/usr/bin:/bin" greet 2>&1); rc2=$?
find "$fake" -mindepth 1 -delete; rmdir "$fake"

last1=$(tail -1 <<<"$out1"); last2=$(tail -1 <<<"$out2")
echo "       alice のログインシェルから         終了ステータス $rc1  最後の行「$last1」"
echo "       偽の date と id が先頭にある PATH から  終了ステータス $rc2  最後の行「$last2」"

ng=0
[ "$owner" = root ] || { echo "       → 所有者が root ではない"; ng=1; }
(( 8#$mode & 8#022 )) && { echo "       → root 以外（グループかその他）が書き換えられる"; ng=1; }
(( (8#$mode & 8#005) == 8#005 )) || { echo "       → その他のユーザ（alice）に r と x の両方が無い"; ng=1; }
{ [ "$rc1" = 0 ] && grep -qxF -- "$want" <<<"$out1"; } || { echo "       → 1回目に「$want」が出なかった"; ng=1; }
{ [ "$rc2" = 0 ] && grep -qxF -- "$want" <<<"$out2"; } || { echo "       → 2回目に「$want」が出なかった"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       root 所有で他人は書き換えられず、alice の環境が違っても同じ1行が出た"
echo "       → スクリプトは使う人の PATH のコピーを受け取る。だから先頭で PATH を決める"
exit 0
