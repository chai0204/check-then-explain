#!/bin/bash
# LinuC 主題1.06 の訂正の裏付け（2026-10-13、事実確認で見つかった誤り3件・誤解を招く6件のうち、端末で示せるもの）。
# イメージは push 済みの lab-linuc-shell:1.0.0（sha256:377dbd9c…）のまま。作り直さずに、同じイメージで取る。
# 記録の取り方（読者と同じ --hostname とボリューム2つで起動する。ボリューム名は linuc-shell- で始める）:
#   docker run -d --name linuc-shell-extra6 --hostname linuc \
#     -v linuc-shell-extra6-work:/home/lab/work -v linuc-shell-extra6-state:/home/lab/.lab \
#     lab-linuc-shell:1.0.0 sleep infinity
#   docker cp probe/linuc-shell-extra6.sh linuc-shell-extra6:/tmp/run.sh
#   docker exec -u lab -w /home/lab linuc-shell-extra6 bash /tmp/run.sh > logs/linuc-shell-extra6.log 2>&1
#   docker rm -f linuc-shell-extra6
# man は端末の幅で折り返しが変わるので MANWIDTH=80 で固定する。
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

printf '\n\n========== %s ==========\n' "第2章: bash ~/.bashrc は8行目で止まらず最後まで読む（子の中では alias が定義される）"
SESSION <<'IN'
mkdir -p ~/try && cd ~/try
echo "alias hi='echo やあ'" >> ~/.bashrc
cp ~/.bashrc /tmp/bashrc.copy; echo 'alias hi' >> /tmp/bashrc.copy
bash /tmp/bashrc.copy; echo "終了ステータス $?"
hi
exit
IN

printf '\n\n========== %s ==========\n' "第2章: スクリプトの中の alias（bash の既定・expand_aliases・dash）"
SESSION <<'IN'
cd ~/try
printf 'alias hi3="echo alias が展開された"\nhi3\n' > a.sh
bash a.sh; echo "終了ステータス $?"
printf 'shopt -s expand_aliases\nalias hi3="echo alias が展開された"\nhi3\n' > a2.sh
bash a2.sh
sh a.sh
bash --posix a.sh
exit
IN

printf '\n\n========== %s ==========\n' "第2章・第8章: 名前だけで打ったコマンドを探す順番（関数 → 組み込み → PATH）"
SESSION <<'IN'
cd ~/try
MANWIDTH=80 man bash | grep -A10 'If the command name contains no slashes'
type -a echo
date() { echo "関数の date が先に動いた"; }
date
type date
unset -f date
type date
exit
IN

printf '\n\n========== %s ==========\n' "第4章: dash は function say { を1つのコマンドとして読む（say と { は引数）"
SESSION <<'IN'
cd ~/try
cat > hello.sh <<'END'
#!/bin/sh
function say {
    echo "こんにちは、$1"
}
say "$(id -un)"
echo "\$0 は $0"
END
mkdir -p fbin
printf '#!/bin/sh\necho "function が受け取った引数: $# 個: $*"\n' > fbin/function; chmod +x fbin/function
PATH="$HOME/try/fbin:$PATH" sh hello.sh
exit
IN

printf '\n\n========== %s ==========\n' "第4章: chmod +x は umask で隠されたビットには付けない / グループは所有者が変えられる"
SESSION <<'IN'
cd ~/try
sed -i '1s|.*|#!/bin/bash|' hello.sh; head -1 hello.sh
(umask 077; chmod 644 hello.sh; chmod +x hello.sh; ls -l hello.sh)
(umask 077; chmod 644 hello.sh; chmod a+x hello.sh; ls -l hello.sh)
sudo usermod -aG staff alice; id alice
sudo -u alice bash -c umask
sudo -u alice bash -c 'cd /tmp && touch g.txt && chgrp staff g.txt && ls -l g.txt'
sudo -u alice bash -c 'cd /tmp && chown :alice g.txt && ls -l g.txt'
sudo -u alice bash -c 'cd /tmp && chgrp lab g.txt'
sudo -u alice bash -c 'cd /tmp && chown lab g.txt'
exit
IN

printf '\n\n========== %s ==========\n' "第5章: 詰めすぎた shift は、bash では 1 を返して続き、dash ではスクリプトが終わる"
SESSION <<'IN'
cd ~/try
cat > sh.sh <<'END'
#!/bin/bash
echo "はじめ:     \$# = $#  \$1 = $1  \$@ = $@"
shift
echo "shift 後:   \$# = $#  \$1 = $1  \$@ = $@"
shift 2
echo "shift 2 後: \$# = $#  \$1 = $1"
shift 5
echo "shift 5 の終了ステータス = $?  \$# = $#"
END
bash sh.sh a b c d; echo "終了ステータス $?"
sh sh.sh a b c d; echo "終了ステータス $?"
exit
IN
