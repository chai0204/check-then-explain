#!/usr/bin/env bash
# 演習 05 の判定。観測型（student のホームの message.txt を読み、old-usb.img の中の message.txt と比べる。
# 課題文の「使い終わったらマウントは外す」も、イメージにつながったループデバイスがマウントされていないかで見る）。
# old-usb.img は、初回の準備（provision.sh）が作った FAT のイメージ。中の message.txt は、マウントしないと読めない。
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }
lab-guest 'test -f /home/student/old-usb.img' >/dev/null 2>&1 || {
  echo "前提不足: 練習機に /home/student/old-usb.img がありません（vm reset --yes で初期状態に戻せます）"; exit 2; }
WANT='伝言: 3 番の棚の鍵は、青い箱の中'

got=$(lab-guest 'cat /home/student/message.txt 2>/dev/null' 2>/dev/null)
loops=$(lab-guest 'losetup -l -n -O NAME,BACK-FILE 2>/dev/null | grep old-usb.img | paste -sd " "' 2>/dev/null)
# old-usb.img につながったループデバイスのうち、どこかにマウントされているもの（課題文の「マウントは外しておく」）
mnt=$(lab-guest 'for l in $(losetup -l -n -O NAME -j /home/student/old-usb.img 2>/dev/null); do findmnt -rn -S "$l" -o TARGET; done | paste -sd " "' 2>/dev/null)

echo "判定 : 観測型（ホームの message.txt を読み、イメージの中の伝言と比べ、イメージがマウントされたままかを見た）"
echo "観測 : ~/message.txt  = ${got:-（無い）}"
[ -n "$loops" ] && echo "       old-usb.img につながったループデバイス = $loops"
echo "       イメージのマウント先 = ${mnt:-（どこにもマウントされていない）}"
ng=0
if [ -z "$got" ]; then
  echo "       → ホームに message.txt が無い（イメージの中から取り出す）"; ng=1
elif [ "$got" != "$WANT" ]; then
  echo "       → 中身が、イメージの中の message.txt と違う"; ng=1
fi
[ -n "$mnt" ] && { echo "       → イメージがまだマウントされている（$mnt）"; ng=1; }
[ "$ng" = 0 ] || exit 1
echo "       ファイルのままのディスクのイメージをマウントして、中のファイルを取り出せた"
echo "       → ループデバイスを通すと、ファイルも装置と同じようにマウントできる"
exit 0
