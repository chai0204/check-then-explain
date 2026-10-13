#!/usr/bin/env bash
# 演習 04 の判定。観測型（labcalc を動かし、rpm の台帳・dnf の記録・鍵の台帳を見る）。
set -uo pipefail
command -v rpm >/dev/null || { echo "前提不足: rpm が見つかりません"; exit 2; }
command -v dnf >/dev/null || { echo "前提不足: dnf が見つかりません"; exit 2; }

echo "判定 : 観測型（labcalc を動かし、rpm の台帳と dnf の記録と鍵の台帳を見た）"
key=$(rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE} %{SUMMARY}\n' 2>/dev/null | grep 'lab tools' | head -1)
path=$(command -v labcalc 2>/dev/null)
if [ -z "$path" ]; then
  echo "観測 : labcalc = コマンドとして見つからない"
  echo "       lab tools の鍵 = ${key:-rpm の台帳に無い}"
  exit 1
fi

out=$(labcalc 2 3 2>&1)
owner=$(rpm -qf --qf '%{NAME}' "$path" 2>/dev/null)
echo "観測 : labcalc = $path"
echo "       labcalc 2 3 の出力 = $out"
if ! rpm -q "$owner" >/dev/null 2>&1; then
  echo "       rpm の台帳 = $path を持つパッケージが無い（手で置かれたファイル）"
  exit 1
fi
# dnf が記録している「どこから入ったか」（@repo id）。rpm で直接入れると @System になる
from=$(dnf -q list installed "$owner" 2>/dev/null | awk -v n="$owner" '$1 ~ "^"n"\\." {print $3}' | head -1)
repo=${from##*@}   # @lab-tools → lab-tools。手元のファイルから入れると @@commandline になる（実測）
base=""
case "$repo" in
  ""|System|commandline) ;;
  *) base=$(dnf -q repoinfo "$repo" 2>/dev/null | sed -n 's/^Repo-baseurl *: *//p' | head -1) ;;
esac
echo "       rpm の台帳 = $(rpm -q "$owner")"
echo "       入った経路 = ${from:-不明}${base:+（$base）}"
echo "       lab tools の鍵 = ${key:-rpm の台帳に無い}"

ng=0
[ "$out" = 5 ] || { echo "       → 2 と 3 を渡して 5 が返らない"; ng=1; }
case "$repo" in
  System)      echo "       → yum のリポジトリからではなく、rpm で直接入っている（@System）"; ng=1 ;;
  commandline) echo "       → リポジトリからではなく、手元のファイルを指定して入っている（@commandline）"; ng=1 ;;
  "")          echo "       → どのリポジトリから入ったかを dnf が記録していない"; ng=1 ;;
  *) case "$base" in
       *"/srv/lab-tools-rpm"*) ;;
       *) echo "       → 入ったリポジトリ $repo が /srv/lab-tools-rpm を指していない"; ng=1 ;;
     esac ;;
esac
[ -n "$key" ] || { echo "       → lab tools の鍵が rpm の台帳に無い（署名を確かめずに入っている）"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       labcalc は $owner のもので、$from から署名を確かめて入っている"
exit 0
