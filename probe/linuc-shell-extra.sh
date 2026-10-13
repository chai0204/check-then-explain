#!/bin/bash
# LinuC 主題1.06 の補足の記録。本文で「man にこう書いてある」と言う箇所の出どころ。
# 記録の取り方（読者と同じ --hostname とボリューム2つで起動する。ボリューム名は linuc-shell- で始める）:
#   docker run -d --name linuc-shell-extra --hostname linuc \
#     -v linuc-shell-extra-work:/home/lab/work -v linuc-shell-extra-state:/home/lab/.lab \
#     lab-linuc-shell:1.0.0 sleep infinity
#   docker cp probe/linuc-shell-extra.sh linuc-shell-extra:/tmp/run.sh
#   docker exec -u lab -w /home/lab linuc-shell-extra bash /tmp/run.sh > logs/linuc-shell-extra.log 2>&1
#   docker rm -f linuc-shell-extra
# man は端末の幅で折り返しが変わるので、MANWIDTH=80 で固定して記録する（読者も同じ幅で再現できる）。
umask 022
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
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
printf '\n\n========== %s ==========\n' "man bash が書いている起動ファイルの規則（第1章）"
SESSION <<'IN'
MANWIDTH=80 man bash | grep -A6 'invoked as an interactive login shell'
MANWIDTH=80 man bash | grep -B2 -A2 'bash.bashrc'
MANWIDTH=80 man bash | grep -A2 'When an interactive login shell exits'
bash --login -c 'shopt login_shell'
exit
IN
printf '\n\n========== %s ==========\n' "PATH の書き間違い・alias の置き換え・export の書き方（第2章）"
SESSION <<'IN'
(PATH="/usr/bin;/opt/tools/bin"; echo "$PATH"; ls /)
$PATH=$PATH:/opt/tools/bin
bash -c 'shopt expand_aliases'
bash -ic 'shopt expand_aliases'
export z=3; bash -c 'echo "z=[$z]"'
exit
IN
printf '\n\n========== %s ==========\n' "本文の説明の裏付け（第3・6・7章）"
SESSION <<'IN'
mkdir -p ~/try && cd ~/try
echo "外 `echo \`id -un\``"
bash -c 'exit 300'; echo $?
seq 1 2 10
printf '1\n2\n' > list.txt; for x in $(cat list.txt); do echo "$x"; echo 9 >> list.txt; done; cat list.txt
case restart in start) echo "start に当たった" ;; *) echo "その他に入った" ;; esac
printf '%s\n' 'C:\temp' | { read p; echo "$p"; }
printf '%s\n' 'C:\temp' | { read -r p; echo "$p"; }
exit
IN
printf '\n\n========== %s ==========\n' "用語辞書の説明の裏付け"
SESSION <<'IN'
y=2; (echo "( ) の中: y=$y"); bash -c 'echo "bash -c の中: y=[$y]"'
sh -c '[[ 1 = 1 ]] && echo ok'
bash -x -c 'echo トレースは標準エラーに出る' 2>/dev/null
exit
IN
