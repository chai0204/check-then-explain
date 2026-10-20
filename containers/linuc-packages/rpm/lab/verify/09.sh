#!/usr/bin/env bash
# 演習 09 の判定。観測型（labapp を動かした出力、rpm の台帳、dnf が記録した経路、rpm -V を見る）。
set -uo pipefail
command -v rpm >/dev/null || { echo "前提不足: rpm が見つかりません"; exit 2; }
command -v dnf >/dev/null || { echo "前提不足: dnf が見つかりません"; exit 2; }

want='liblab: こんにちは from labapp 1.0'
# dnf が記録している「どこから入ったか」。yum でリポジトリ lab から入れると @lab、rpm で直接入れると @System
from() { dnf -q list installed "$1" 2>/dev/null | awk -v n="$1" '$1 ~ "^"n"\\." {print $3}' | head -1; }

echo "判定 : 観測型（labapp を動かし、rpm の台帳・入った経路・rpm -V labapp を見た）"
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
  # 設定ファイル（c の印）は書き換えてよいので、それ以外を数える
  other=$(printf '%s\n' "$ver" | grep -v '^$' | grep -v '^.\{9\}  c ' || true)
  if [ -n "$ver" ]; then
    echo "       rpm -V labapp（台帳と違うファイル）:"
    printf '%s\n' "$ver" | sed 's/^/       │ /'
  else
    echo "       rpm -V labapp = 何も出ない（どのファイルも台帳の記録のまま）"
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

echo "       labapp と liblab は yum で lab から入り、書き換わったのは設定ファイルだけで、挨拶はこんにちは"
exit 0
