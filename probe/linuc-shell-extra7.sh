#!/bin/bash
# LinuC 主題1.06 の試験対策の追加（2026-10-13）。LinuC 公式例題（linuc.org/study/samples）の 102 の
# 1.06 の16件を本文で解けるかを監査し、足りなかったもの（配列・alias の避け方・= の前後の空白・HISTSIZE・
# expr・function 名前()）と、例題の解説とずれやすいところ（シバンが無いとき・$@・/etc/profile の alias）の記録。
# イメージは lab-linuc-shell:1.0.2（seed を 0755 にした版。ほかの記録と一緒に取り直す）。
# 記録の取り方（読者と同じ --hostname とボリューム2つで起動する。ボリューム名は linuc-shell- で始める）:
#   docker run -d --name linuc-shell-extra7 --hostname linuc \
#     -v linuc-shell-extra7-work:/home/lab/work -v linuc-shell-extra7-state:/home/lab/.lab \
#     lab-linuc-shell:1.0.2 sleep infinity
#   docker cp probe/linuc-shell-extra7.sh linuc-shell-extra7:/tmp/run.sh
#   docker exec -u lab -w /home/lab linuc-shell-extra7 bash /tmp/run.sh > logs/linuc-shell-extra7.log 2>&1
#   docker rm -f linuc-shell-extra7
umask 022
SESSION() {
  { sleep 1
    printf '%s\n' 'PROMPT_COMMAND='"'"'PS1="\$ "'"'"'; : __REC__'
    while IFS= read -r l; do
      case $l in "#sleep "*) sleep "${l#\#sleep }"; continue ;; esac
      sleep "${DELAY:-0.7}"; printf '%s\n' "$l"
    done
    sleep 1.5
  } | script -q -c "stty cols 200 rows 50; exec /bin/bash -l" /dev/null \
    | tr -d '\r' | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g; s/\x1b\][^\x07]*\x07//g' | sed '1,/__REC__/d'
}

printf '\n\n========== %s ==========\n' "第5章: 配列の要素は \${a[1]}（添字は 0 から）/ 引用符なしの \$@"
SESSION <<'IN'
mkdir -p ~/try && cd ~/try
a=(x y z)
echo ${a[1]}
echo $a[1]
echo $a
echo ${a[@]}; echo ${#a[@]}
set -- "my file.txt" b; for a in $@; do echo "[$a]"; done
sh -c 'a=(x y z)'
exit
IN

printf '\n\n========== %s ==========\n' "第2章: alias を一度だけ避ける・unalias・= の前後の空白"
SESSION <<'IN'
cd ~/try
alias ls='ls -l'
ls -d /etc
\ls -d /etc
command ls -d /etc
/usr/bin/ls -d /etc
unalias ls
alias ls
alias ll = 'ls -l'; echo "終了ステータス $?"
x = 1
x=no; [ "$x"="yes" ] && echo "空白が無いと、いつも真"
[ "$x" = "yes" ] || echo "空白があれば、正しく偽"
exit
IN

printf '\n\n========== %s ==========\n' "第2章: /etc/profile にも alias は書ける（ログインシェルで定義される）"
SESSION <<'IN'
cd ~/try
echo "alias zz='echo /etc/profile で定義した alias'" | sudo tee -a /etc/profile
bash -l -c 'alias zz'
bash -c 'alias zz'
sudo sed -i '/^alias zz=/d' /etc/profile; tail -1 /etc/profile
exit
IN

printf '\n\n========== %s ==========\n' "第2章: ~/.bashrc の HISTSIZE=0（履歴を覚えない・ファイルにも書かない）"
SESSION <<'IN'
cd ~/try
grep -n -E '^ *(PS1|HISTSIZE)=' ~/.bashrc
echo 'HISTSIZE=0' >> ~/.bashrc
HISTFILE=/tmp/hist-demo bash
echo 履歴に残すか
history
exit
ls -l /tmp/hist-demo
sed -i '/^HISTSIZE=0$/d' ~/.bashrc
HISTFILE=/tmp/hist-demo2 bash
echo 履歴に残すか
exit
cat /tmp/hist-demo2
exit
IN

printf '\n\n========== %s ==========\n' "第6章: expr は計算結果が 0 のとき終了ステータス 1 を返す"
SESSION <<'IN'
cd ~/try
expr 2 + 3; echo "終了ステータス $?"
expr 2 - 2; echo "終了ステータス $?"
expr 3 \* 4
i=0; i=$(expr $i + 1); echo $i
expr --help | grep -A1 'Exit status'
exit
IN

printf '\n\n========== %s ==========\n' "第8章: function 名前() { } とも書ける（bash だけ）"
SESSION <<'IN'
cd ~/try
function hi2() { echo "function と () を両方付けても書ける"; }
hi2
sh -c 'function f() { echo x; }; f'
exit
IN

printf '\n\n========== %s ==========\n' "第4章: 先頭行が無いスクリプトは、起動した側のシェルが読む"
SESSION <<'IN'
cd ~/try
printf 'echo "BASH_VERSION=[$BASH_VERSION]"\n' > noshebang.sh; chmod +x noshebang.sh
./noshebang.sh
sh -c ./noshebang.sh
exit
IN
