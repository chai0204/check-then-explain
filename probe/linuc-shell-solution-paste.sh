#!/bin/bash
# 主題1.06 の模範解答04〜07: lab solve NN が画面に出した「cat > … <<'EOF' から EOF まで」の塊を、画面に出たとおり
# 切り出して bash に流す（読者が画面から写して貼り付けるのと同じ）。1.0.3 までは塊が4桁字下げされていて EOF で終わらず、
# 作られたスクリプトの1行目も「    #!/bin/bash」になっていた（2026-10-21）。
#   bash probe/linuc-shell-solution-paste.sh [イメージ ...] > logs/linuc-shell-solution-paste.log 2>&1
O=$(mktemp -d)
cat > "$O/inner.sh" <<'IN'
for n in 04 05 06 07; do
  lab start $n >/dev/null 2>&1; cd ~/work/$n || exit 1
  lab solve $n 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' > /tmp/sol.txt
  awk '/cat > [^ ]+ <<.EOF./{f=1} f{print} f&&/^ *EOF$/{exit}' /tmp/sol.txt > /tmp/block.txt
  script=$(grep -o 'cat > [^ ]*' /tmp/block.txt | head -1 | cut -c7-)
  out=$(timeout 5 bash < /tmp/block.txt 2>&1); rc=$?
  printf '%s %-10s 塊 %2d 行 / rc=%s / 1行目=[%s] / bash -n=%s %s\n' "$n" "$script" "$(wc -l < /tmp/block.txt)" "$rc" "$(head -1 "$script" 2>/dev/null)" "$(bash -n "$script" 2>/dev/null && echo ok || echo NG)" "$(printf '%s' "$out" | head -1)"
  cd ~
done
IN
for t in "${@:-lab-linuc-shell:1.0.3 lab-linuc-shell:1.0.4}"; do
  for i in $t; do echo "== $i"; docker run --rm -i --hostname linuc --entrypoint bash "$i" -l < "$O/inner.sh" 2>&1; done
done
