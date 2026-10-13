#!/usr/bin/env bash
# 演習 08 の判定。観測型（変換後のファイルのバイト列を、正しい読み方で読んだ元の文と突き合わせる）。
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外の端末で vm start）"; exit 2; }
G() { lab-guest "$@" 2>/dev/null; }
D=/home/student/lab08
G "test -f $D/a.txt -a -f $D/b.txt -a -f $D/c.txt" >/dev/null \
  || { echo "前提不足: $D の a.txt / b.txt / c.txt がそろっていません（vm reset --yes で最初の状態に戻せます）"; exit 2; }

echo "判定 : 観測型（$D/utf8/ の各ファイルを UTF-8 として読み、元のファイルを正しい文字コードで読んだ文と比べた）"
ng=0; first=1
for f in a b c; do
  case $f in a) enc=SHIFT_JIS ;; b) enc=EUC-JP ;; c) enc=ISO-2022-JP ;; esac
  # 結果: ok / missing / notutf8 / differ（differ のときは1行目も返す）
  r=$(G "o=$D/utf8/$f.txt
         if [ ! -f \$o ]; then echo missing
         elif ! iconv -f UTF-8 -t UTF-8 \$o >/dev/null 2>&1; then echo notutf8
         elif iconv -f $enc -t UTF-8 $D/$f.txt | cmp -s - \$o; then echo ok
         else echo differ; head -1 \$o; fi")
  kind=$(head -1 <<<"$r"); line1=$(sed -n 2p <<<"$r")
  case $kind in
    ok)      msg="UTF-8 で、元の文と一致" ;;
    missing) msg="無い"; ng=1 ;;
    notutf8) msg="UTF-8 として読めないバイトがある"; ng=1 ;;
    differ)  msg="UTF-8 としては読めるが、元の文と違う（1行目: $line1）"; ng=1 ;;
    *)       msg="読み取れない"; ng=1 ;;
  esac
  if [ "$first" = 1 ]; then p="観測 :"; first=0; else p="      "; fi
  echo "$p utf8/$f.txt → $msg"
done

[ "$ng" = 0 ] || exit 1
echo "       3つとも、元のバイト列を正しい文字コードで読んで UTF-8 に書き直せている"
echo "       → ファイルは自分の文字コードを名乗らない。読み方を決めたのは iconv -f に渡した名前"
exit 0
