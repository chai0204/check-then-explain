#!/usr/bin/env bash
# 演習 01 の判定。観測型（練習機の中で frank の台帳の行・ホームの実物・パスワードの状態を見る）。
# 外側（lab）で走り、練習機の中は lab-guest（qemu-guest-agent 経由・root）で見る。
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外の端末で vm start）"; exit 2; }
G() { lab-guest "$@" 2>/dev/null; }

echo "判定 : 観測型（練習機の中で、frank の台帳の行・ホームの中身・パスワードの状態を見た）"
pw=$(G 'getent passwd frank')
if [ -z "$pw" ]; then
  echo "観測 : getent passwd frank → 何も返らない（frank という行が台帳に無い）"
  exit 1
fi
home=$(cut -d: -f6 <<<"$pw"); shell=$(cut -d: -f7 <<<"$pw")
echo "観測 : getent passwd frank → $pw"
ng=0

[ "$home" = /home/frank ] || { echo "       ホームの欄が /home/frank ではない（$home）"; ng=1; }
[ "$shell" = /bin/bash ] || { echo "       ログインシェルの欄が /bin/bash ではない（$shell）"; ng=1; }

owner=$(G "stat -c %U '$home'")
if [ -z "$owner" ]; then
  echo "       $home → ディレクトリが存在しない（台帳に書いてあるだけ）"; ng=1
else
  echo "       $home → 存在する（所有者 $owner）"
  [ "$owner" = frank ] || { echo "       ホームの所有者が frank ではない"; ng=1; }
  G "test -f '$home/.bashrc'" >/dev/null && echo "       $home/.bashrc → ある（/etc/skel から写された）" \
    || { echo "       $home/.bashrc → 無い（/etc/skel の中身が写されていない）"; ng=1; }
fi

if G 'test -f /etc/skel/README.txt' >/dev/null; then
  echo "       /etc/skel/README.txt → ある"
else
  echo "       /etc/skel/README.txt → 無い"; ng=1
fi
rowner=$(G "stat -c %U '$home/README.txt'")
if [ -n "$rowner" ]; then
  echo "       $home/README.txt → ある（所有者 $rowner）"
  [ "$rowner" = frank ] || { echo "       README.txt の所有者が frank ではない"; ng=1; }
else
  echo "       $home/README.txt → 無い"; ng=1
fi

st=$(G 'passwd -S frank')
echo "       passwd -S frank → $st"
case "$(awk '{print $2}' <<<"$st")" in
  P)  ;;
  L)  echo "       パスワードの欄がロック（L）のまま。このままではパスワードでログインできない"; ng=1 ;;
  NP) echo "       パスワードが空（NP）。パスワード無しで入れてしまう"; ng=1 ;;
  *)  echo "       パスワードの状態が読み取れない"; ng=1 ;;
esac

[ "$ng" = 0 ] || exit 1
echo "       台帳の行・ホームの実物・skel の写し・パスワードの4つがそろっている"
echo "       → useradd が書いたのは台帳の行。ホームと中身は -m を付けたから作られた"
exit 0
