#!/usr/bin/env bash
# 演習 08 の判定。観測型（dpkg の台帳に記録された labmine の状態・ファイル・依存と、apt の「自動で入った」印と、
# labmine を動かした結果を見る）。
set -uo pipefail
command -v dpkg-query >/dev/null || { echo "前提不足: dpkg-query が見つかりません"; exit 2; }

want='liblab: 自分で作ったパッケージから入りました'
st=$(dpkg-query -W -f='${db:Status-Abbrev}' labmine 2>/dev/null | tr -d ' ')
ver=$(dpkg-query -W -f='${Version}' labmine 2>/dev/null)
dep=$(dpkg-query -W -f='${Depends}' labmine 2>/dev/null)
owner=$(dpkg-query -S /usr/bin/labmine 2>/dev/null | head -1 | cut -d: -f1)
lib=$(dpkg-query -W -f='${db:Status-Abbrev}' liblab 2>/dev/null | tr -d ' ')
# 依存関係から入ったものには apt が「自動で入った」印を付ける（第5章）。apt install liblab で先に入れると付かない
auto=$(apt-mark showauto liblab 2>/dev/null)
fo=$(stat -c '%U:%G' /usr/bin/labmine 2>/dev/null)

echo "判定 : 観測型（labmine と liblab の台帳と、labmine を動かした結果を見た）"
echo "観測 : labmine の台帳 = ${st:-行が無い}${ver:+（版 $ver）}"
[ -n "$st" ] && echo "       labmine の依存関係（Depends）= ${dep:-書かれていない}"
echo "       /usr/bin/labmine を置いたパッケージ = ${owner:-台帳に無い}${fo:+（持ち主 $fo）}"
if [ "$lib" = ii ]; then
  if [ -n "$auto" ]; then mark=あり; else mark=なし; fi
  echo "       liblab の台帳 = ii（自動で入った印 $mark）"
else
  echo "       liblab の台帳 = ${lib:-行が無い}"
fi
if [ -x /usr/bin/labmine ]; then
  out=$(/usr/bin/labmine 2>&1); rc=$?
  echo "       labmine の出力 = $out（終了コード $rc）"
else
  out=""; rc=127
  echo "       /usr/bin/labmine = 無い（または実行できない）"
fi

ng=0
[ "$st" = ii ] || { echo "       → labmine が台帳で ii になっていない"; ng=1; }
[ -z "$st" ] || [ "$ver" = 1.0 ] || { echo "       → labmine の版が 1.0 ではない"; ng=1; }
[ -z "$st" ] || case " $dep " in *[\ ,]liblab[\ ,\(]*) ;; *) echo "       → labmine の情報に、liblab への依存関係が書かれていない"; ng=1 ;; esac
[ "$owner" = labmine ] || { echo "       → /usr/bin/labmine が、labmine のファイルとして台帳に載っていない"; ng=1; }
[ -z "$fo" ] || [ "$fo" = root:root ] || { echo "       → /usr/bin/labmine の持ち主が root:root ではない"; ng=1; }
[ "$rc" = 0 ] && [ "$out" = "$want" ] || { echo "       → labmine が期待の1行を出さない"; ng=1; }
[ "$lib" != ii ] || [ -n "$auto" ] || { echo "       → liblab に「自動で入った」印が無い（依存関係から入ると付く）"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       labmine 1.0 が、依存関係で liblab を連れて入り、"
echo "       /usr/bin/labmine（root の持ち物）が動いた"
exit 0
