#!/usr/bin/env bash
# 演習 03 の判定。観測型（labsvc を動かした出力と、dpkg の台帳との照らし合わせを見る）。
set -uo pipefail
command -v dpkg-query >/dev/null || { echo "前提不足: dpkg-query が見つかりません"; exit 2; }
st=$(dpkg-query -W -f='${db:Status-Abbrev}' labsvc 2>/dev/null | tr -d ' ')
case "$st" in i?) ;; *)
  echo "前提不足: labsvc が入っていません（台帳 = ${st:-行が無い}）。檻を起動し直すと、配られた状態に戻ります"
  exit 2 ;;
esac

echo "判定 : 観測型（labsvc を動かした出力と、dpkg -V labsvc の結果を見た）"
if [ -x /usr/bin/labsvc ]; then
  out=$(/usr/bin/labsvc 2>/dev/null); rc=$?
  port=$(printf '%s\n' "$out" | sed -n 's/^port=//p' | tail -1)
  echo "観測 : labsvc が表示したポート = ${port:-（port= の行が無い）}（終了コード $rc）"
else
  port=""; rc=127
  echo "観測 : /usr/bin/labsvc = 実行できない"
fi
# 台帳と違うファイル。設定ファイル（c の印）は書き換えてよいので、それ以外を数える
ver=$(dpkg -V labsvc 2>&1)
other=$(printf '%s\n' "$ver" | grep -v '^$' | grep -v '^.\{9\} c ' || true)
if [ -n "$ver" ]; then
  echo "       dpkg -V labsvc（台帳と違うファイル）:"
  printf '%s\n' "$ver" | sed 's/^/       │ /'
else
  echo "       dpkg -V labsvc = 何も出ない（どのファイルも台帳の記録のまま）"
fi

ng=0
[ "$port" = 9090 ] || { echo "       → labsvc が port=9090 と表示しない"; ng=1; }
[ -z "$other" ] || { echo "       → 設定ファイル以外のファイルが、台帳の記録と違う"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       labsvc は port=9090 を表示し、書き換わったのは設定ファイルだけ"
exit 0
