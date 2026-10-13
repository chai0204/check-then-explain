#!/usr/bin/env bash
# 演習 06 の判定。観測型（eve・bob・student として実際に atq と crontab -l を打ち、断られるかを見る）。
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外の端末で vm start）"; exit 2; }
for u in eve bob; do
  lab-guest "id $u" >/dev/null 2>&1 || { echo "前提不足: 練習機に $u がいません（vm reset --yes で最初の状態に戻せます）"; exit 2; }
done

# 1人ぶんの観測: 「at 使える/断られた」「crontab 使える/断られた」とメッセージ
probe_at() {   # 断られたら 1
  local out; out=$(lab-guest -u "$1" 'atq' 2>&1)
  if grep -qi 'permission' <<<"$out"; then echo "断られた（$(head -1 <<<"$out")）"; return 1; fi
  echo "使える"; return 0
}
probe_cron() { # 断られたら 1。「no crontab for …」は使える（表がまだ無いだけ）
  local out; out=$(lab-guest -u "$1" 'crontab -l' 2>&1)
  if grep -qi 'not allowed' <<<"$out"; then echo "断られた（$(head -1 <<<"$out")）"; return 1; fi
  echo "使える"; return 0
}

echo "判定 : 観測型（3人それぞれとして atq と crontab -l を実際に打ち、断られるかを見た）"
ng=0; first=1
for u in eve bob student; do
  a=$(probe_at "$u");   ar=$?
  c=$(probe_cron "$u"); cr=$?
  if [ "$first" = 1 ]; then p="観測 :"; first=0; else p="      "; fi
  printf '%s %-7s at → %s / crontab → %s\n' "$p" "$u" "$a" "$c"
  if [ "$u" = eve ]; then
    [ $ar -eq 1 ] || { echo "       → eve が at を使える"; ng=1; }
    [ $cr -eq 1 ] || { echo "       → eve が crontab を使える"; ng=1; }
  else
    [ $ar -eq 0 ] || { echo "       → $u も at を断られている"; ng=1; }
    [ $cr -eq 0 ] || { echo "       → $u も crontab を断られている"; ng=1; }
  fi
done
echo "       ある許可ファイル: $(lab-guest 'ls -1 /etc/at.allow /etc/at.deny /etc/cron.allow /etc/cron.deny 2>/dev/null' 2>/dev/null | paste -sd ' ')"

[ "$ng" = 0 ] || exit 1
echo "       eve だけが at と crontab の両方を断られ、bob と student は使える"
echo "       → 誰に使わせるかは、at と cron がそれぞれ自分の許可ファイルを読んで決めた"
exit 0
