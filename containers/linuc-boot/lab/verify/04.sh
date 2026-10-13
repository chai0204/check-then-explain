#!/usr/bin/env bash
# 演習 04 の判定。観測型（既定のターゲットのリンクと、このブートが実際にどこまで進んだかを見る）。
#   「既定を変えた」だけでなく「その既定でこの起動が multi-user に止まった」ことを確かめる。
#   そのため、リンクを変えた時刻と、このブートが始まった時刻を比べる。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値（system）に引きずられないよう固定する

def=$(lab-guest 'systemctl get-default' 2>/dev/null); rc=$?
[ $rc -eq 125 ] && { echo "前提不足: 練習機の中から応答がありません（電源が切れている・起動の途中・systemd を通らない起動（init=/bin/bash など）のどれか）。virsh domstate linuc と virsh console linuc で状態を見てください"; exit 2; }
gr=$(lab-guest 'systemctl is-active graphical.target' 2>/dev/null)
mu=$(lab-guest 'systemctl is-active multi-user.target' 2>/dev/null)
link=$(lab-guest 'readlink /etc/systemd/system/default.target' 2>/dev/null)
lt=$(lab-guest 'stat -c %Y /etc/systemd/system/default.target 2>/dev/null' 2>/dev/null)
bt=$(lab-guest 'date -d "$(uptime -s)" +%s' 2>/dev/null)
cmdline=$(lab-guest 'cat /proc/cmdline' 2>/dev/null)

echo "判定 : 観測型（既定のターゲットと、このブートが到達したターゲット・始まった時刻を見た）"
echo "観測 : systemctl get-default → $def"
echo "       /etc/systemd/system/default.target → ${link:-（無い。/usr/lib の既定が使われている）}"
echo "       multi-user.target → $mu / graphical.target → $gr"

ng=0
[ "$def" = multi-user.target ] || { echo "       → 既定のターゲットが multi-user.target でない"; ng=1; }
[ "$mu" = active ] || { echo "       → multi-user.target が active でない"; ng=1; }
[ "$gr" = inactive ] || { echo "       → graphical.target が inactive でない"; ng=1; }
if grep -qE '(^| )(systemd\.unit=[^ ]+|[1-5]|single|emergency|rescue)( |$)' <<<"$cmdline"; then
  echo "       → このブートはカーネル引数でターゲットを指定して起動している（$cmdline）"
  ng=1
fi
if [ -n "$lt" ] && [ -n "$bt" ]; then
  if [ "$lt" -le "$bt" ]; then
    echo "       既定を変えたのは、このブートが始まる前（$((bt - lt)) 秒前）"
  else
    echo "       → 既定を変えたのは、このブートが始まった後（いまの状態は既定の設定から来たものではない）"
    ng=1
  fi
fi
[ "$ng" = 0 ] || exit 1

echo "       リンクを書き換えた後の起動が、既定の設定どおり multi-user.target に止まった"
exit 0
