#!/usr/bin/env bash
# 演習 09 の判定。観測型（labapp を動かした出力、rpm の台帳、dnf が記録した経路、rpm -V を見る）。
# 出力には rpm -V の名前を出さない（第11章で出る。順を追う監査 C-7）。
set -uo pipefail
command -v rpm >/dev/null || { echo "前提不足: rpm が見つかりません"; exit 2; }
command -v dnf >/dev/null || { echo "前提不足: dnf が見つかりません"; exit 2; }

want='liblab: こんにちは from labapp 1.0'
# dnf が記録している「どこから入ったか」。yum でリポジトリ lab から入れると @lab、rpm で直接入れると @System
from() { dnf -q list installed "$1" 2>/dev/null | awk -v n="$1" '$1 ~ "^"n"\\." {print $3}' | head -1; }

echo "判定 : 観測型（labapp の出力・入った経路・入れたときの中身との違いを見た）"
lead="観測 :"
for p in labapp liblab; do
  if rpm -q "$p" >/dev/null 2>&1; then
    printf '%s %s = %s（経路 %s）\n' "$lead" "$p" "$(rpm -q "$p")" "$(from "$p")"
  else
    printf '%s %s = rpm の台帳に無い\n' "$lead" "$p"
  fi
  lead="      "
done
if [ -x /usr/bin/labapp ]; then
  out=$(/usr/bin/labapp 2>&1); rc=$?
  echo "       labapp の出力 = $out（終了コード $rc）"
else
  out=""; rc=127
  echo "       /usr/bin/labapp = 無い（labapp と打っても見つからない）"
fi
ver=""; other=""
if rpm -q labapp >/dev/null 2>&1; then
  ver=$(rpm -V labapp 2>&1)
  # 行は「9文字の欄・印・パス」か、消えたファイルなら「missing・印・パス」（印 c が設定ファイル）。
  # パスだけを出し、消えたものと設定ファイルにはそう添える。設定ファイル（書き換えてよい）でない行を other に数える
  if [ -n "$ver" ]; then
    echo "       入れたときの中身と違うファイル:"
    while IFS= read -r l; do
      [ -n "$l" ] || continue
      if [[ $l =~ ^missing\ +(c\ +)?(/.*)$ ]]; then
        path=${BASH_REMATCH[2]}; conf=${BASH_REMATCH[1]}; gone="消えている。"
      elif [[ $l =~ ^.{9}\ +([cdglr]\ +)?(/.*)$ ]]; then
        path=${BASH_REMATCH[2]}; conf=""; gone=""; [[ ${BASH_REMATCH[1]} == c* ]] && conf=c
      else
        path=$l; conf=""; gone=""
      fi
      if [ -n "$conf" ]; then
        if [ -n "$gone" ]; then echo "       │ $path（消えている。設定ファイル）"; else echo "       │ $path（設定ファイル。書き換えてよい）"; fi
      else
        echo "       │ $path${gone:+（消えている）}"
        other="$other$l"
      fi
    done <<< "$ver"
  else
    echo "       入れたときの中身と違うファイル = 無い（どれも入れたときのまま）"
  fi
fi

ng=0
for p in labapp liblab; do
  f=$(from "$p")
  rpm -q "$p" >/dev/null 2>&1 || { echo "       → $p が入っていない"; ng=1; continue; }
  [ "$f" = "@lab" ] || { echo "       → $p が yum のリポジトリ lab から入っていない（経路 ${f:-不明}）"; ng=1; }
done
[ "$rc" = 0 ] && [ "$out" = "$want" ] || { echo "       → labapp が「$want」を出さない"; ng=1; }
[ -z "$other" ] || { echo "       → 設定ファイル以外のファイルが、台帳の記録と違う"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       labapp と liblab は yum で lab から入っている"
echo "       書き換わったのは設定ファイルだけで、挨拶はこんにちは"
exit 0
