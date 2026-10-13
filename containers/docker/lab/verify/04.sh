#!/usr/bin/env bash
# 演習 04 の判定。観測型（ボリュームの置き場所の memo.txt を読み、ex04-data を使うコンテナが無いことを見る）。外（lab@host）で走り、練習機の中は lab-guest（qemu-guest-agent 経由・root）で見る。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値に引きずられないよう固定する
prereq() { echo "前提不足: 練習機が応答しません（起動の途中か、止まっている）。外で vm start を打ち、起動を待ってからもう一度"; exit 2; }
# 練習機に届くかを先に1回だけ確かめる。lab-guest は届かないとき 125 を返すが、podman や docker run も
# 自分の失敗に 125 を使うので、コマンドごとの 125 を「届かない」と読むと取り違える（実測: podman inspect の「無い」が 125）
lab-guest true >/dev/null 2>&1 || prereq

mp=$(lab-guest "docker volume inspect --format '{{.Mountpoint}}' ex04-data" 2>&1); rc=$?
echo "判定 : 観測型（練習機の上のボリュームの置き場所を読み、ボリュームを使うコンテナを数えた）"
if [ $rc -ne 0 ]; then
  echo "観測 : ex04-data という名前付きボリュームが無い"
  exit 1
fi
body=$(lab-guest "cat '$mp/memo.txt'" 2>&1); brc=$?
users=$(lab-guest "docker ps -a --filter volume=ex04-data --format '{{.Names}}'" 2>/dev/null | tr '\n' ' ')
echo "観測 : $mp/memo.txt → $([ $brc -eq 0 ] && echo "「$body」" || echo "無い")"
echo "       ex04-data を使っているコンテナ: ${users:-無し}"
[ $brc -eq 0 ] && [ "$body" = "keep me" ] || { echo "       memo.txt の中身が「keep me」の1行ではない"; exit 1; }
[ -z "${users// /}" ] || { echo "       ex04-data を使っているコンテナが残っている"; exit 1; }
echo "       → 書いたコンテナはもう無いが、データはボリュームに残っている"
exit 0
