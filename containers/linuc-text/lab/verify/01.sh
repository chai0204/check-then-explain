#!/usr/bin/env bash
# 演習 01 の判定。観測型。
#   この判定スクリプトは「読者のシェル → lab → この bash」と起動された子プロセスである。
#   だからここで見える環境変数が、読者のシェルから子に渡っているもののすべてになる。
#   そのうえで sensible-editor を実際に起動し、呼ばれたエディタに --version で名乗らせる。
#   stdin を /dev/null にするのは、EDITOR が無いとき select-editor の対話画面が出るのを避けるため。
set -uo pipefail
command -v sensible-editor >/dev/null || { echo "前提不足: sensible-editor が見つかりません"; exit 2; }

seen=${EDITOR-}
who=$(sensible-editor --version < /dev/null 2>/dev/null | head -1 | sed 's/^ *//')

echo "判定 : 観測型（判定はこのシェルの子プロセス。子から見えた EDITOR と、それで起動したエディタの名乗りを見た）"
echo "観測 : 子プロセスから見た EDITOR = [${seen}]"
echo "       sensible-editor が起動したエディタ = ${who:-（何も名乗らなかった）}"

case $who in
  VIM*)
    if [ -z "$seen" ]; then
      echo "       → vim は起動したが、EDITOR は子プロセスに渡っていない（VISUAL か ~/.selected_editor が効いている）"
      exit 1
    fi ;;
  *)
    if [ -z "$seen" ]; then
      echo "       → EDITOR が子プロセスに渡っていない"
    else
      echo "       → EDITOR は渡っているが、起動したのは vi（vim）ではない"
    fi
    exit 1 ;;
esac
echo "       EDITOR が環境変数として子に渡り、それを読んだ sensible-editor が vim を起動した"
exit 0
