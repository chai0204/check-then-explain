#!/usr/bin/env bash
# 演習04 の判定。観測型（deploy として実際に sudo を打ち、通る/通らないを見る）。
set -uo pipefail
vc=$(lab-guest 'visudo -cf /etc/sudoers 2>&1'); rc=$?
[ "$rc" -eq 125 ] && { echo "前提不足: 練習機が応答しません（外の端末で vm start / vm status）"; exit 2; }

# deploy として許可一覧を見て、実際に許可コマンド/不許可コマンドを打つ
allow=$(lab-guest -u deploy 'sudo -n journalctl -n1 >/dev/null 2>&1; echo $?')
deny=$(lab-guest  -u deploy 'sudo -n id          >/dev/null 2>&1; echo $?')
lst=$(lab-guest 'sudo -n -l -U deploy 2>/dev/null | grep -iE "NOPASSWD|/usr" | sed "s/^ *//"')

echo "判定 : 観測型（deploy として sudo journalctl と sudo id を実際に打った）"
echo "観測 : sudoers 構文 = $( printf '%s' "$vc" | grep -q 'parsed OK' && echo OK || echo NG )"
echo "       deploy に許された行 : ${lst:-（なし）}"
echo "       sudo -n journalctl -n1 の終了コード = ${allow:-?}（0 なら許可）"
echo "       sudo -n id          の終了コード = ${deny:-?}（0 以外なら拒否）"

ng=0
printf '%s' "$vc" | grep -q 'parsed OK' || { echo "       → sudoers の構文が壊れている"; ng=1; }
[ "$allow" = 0 ] || { echo "       → journalctl を sudo で実行できない（まだ許せていない／権限で無視された）"; ng=1; }
[ "$deny" = 0 ] && { echo "       → id まで sudo で通ってしまう（絞れていない）"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       journalctl だけが sudo で通り、ほかは拒否される"
exit 0
