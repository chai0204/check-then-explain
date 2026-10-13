#!/usr/bin/env bash
# 演習 02 の判定。観測型（/tmp に移動し、PATH をたどって greet を探し、実際に実行する）。
#   この判定はシェルの子プロセスなので、読者のシェルの PATH がそのまま見えている
#   （PATH はもともと環境変数として渡されている）。
set -uo pipefail
target="$HOME/work/02/bin/greet"
[ -f "$target" ] || { echo "前提不足: $target がありません。先に lab start 02 を打ってください"; exit 2; }
cd /tmp || { echo "前提不足: /tmp に移動できません"; exit 2; }

found=$(type -P greet 2>/dev/null)
rel=$(printf '%s\n' "$PATH" | tr ':' '\n' | grep -v '^/' | grep -v '^$' | tr '\n' ' ')
empty=$(printf '%s' "$PATH" | grep -cE '(^:|::|:$)')

echo "判定 : 観測型（/tmp に移動してから、名前だけで greet を探して実行した）"
echo "観測 : PATH = $PATH"
[ -n "$rel" ] && echo "       PATH の中の相対パス = ${rel}（/tmp から見た場所を指す）"
[ "$empty" -gt 0 ] && echo "       PATH の中に空の要素がある（カレントディレクトリを指す）"
echo "       /tmp から名前で探した greet = ${found:-（見つからない）}"

if [ -z "$found" ]; then
  echo "       → PATH をたどっても greet が見つからない"
  exit 1
fi
out=$(greet 2>&1); rc=$?
echo "       実行結果 = $out（終了コード $rc）"
if ! cmp -s "$found" "$target"; then
  echo "       → 見つかった $found は、配った greet と中身が違う"
  exit 1
fi
[ "$rc" -eq 0 ] || { echo "       → 見つかったが実行できなかった"; exit 1; }
echo "       どこにいても、名前だけで配った greet が見つかって動いた"
exit 0
