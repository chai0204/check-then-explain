#!/usr/bin/env bash
# 演習 12 の判定。観測型（~/work/12 の .rpm の中身、rpm の台帳、dnf が記録した経路を見る）。
set -uo pipefail
command -v rpm >/dev/null || { echo "前提不足: rpm が見つかりません"; exit 2; }
dir="$HOME/work/12"

# ~/work/12 にある .rpm を、ファイル名ではなく中身（rpm -qp）で数える
names=""
for f in "$dir"/*.rpm; do
  [ -f "$f" ] || continue
  n=$(rpm -qp --qf '%{NAME}' "$f" 2>/dev/null) && names="$names $n"
done
has() { case " $names " in *" $1 "*) return 0 ;; esac; return 1; }
# dnf が記録している「どこから入ったか」。rpm で直接入れたものは @System
from() { dnf -q list installed "$1" 2>/dev/null | awk -v n="$1" '$1 ~ "^"n"\\." {print $3}' | head -1; }

echo "判定 : 観測型（~/work/12 の .rpm の中身、rpm の台帳、dnf が記録した経路を見た）"
echo "観測 : ~/work/12 の .rpm =${names:- 無い}"
issues=()
for p in labtool labtool-data; do
  if rpm -q "$p" >/dev/null 2>&1; then
    f=$(from "$p")
    echo "       $p = $(rpm -q "$p")（経路 ${f:-不明}）"
    [ "$f" = "@System" ] || issues+=("$p が rpm ではなく yum のリポジトリ（${f:-不明}）から入っている")
  else
    echo "       $p = rpm の台帳に無い"
    issues+=("$p が rpm の台帳に無い")
  fi
  has "$p" || issues+=("~/work/12 に $p の .rpm が無い")
done
if command -v labtool >/dev/null 2>&1; then
  out=$(labtool 2>&1); rc=$?
  echo "       labtool = $out（終了コード $rc）"
  [ "$rc" = 0 ] || issues+=("labtool が終了コード $rc で終わった")
else
  echo "       labtool = コマンドとして見つからない"
  issues+=("labtool が動かない")
fi
if [ "${#issues[@]}" -gt 0 ]; then
  printf '       → %s\n' "${issues[@]}"
  exit 1
fi

echo "       取ってきた2つの .rpm から rpm で入り（@System）、labtool が動いた"
exit 0
