# ログイン時に現在地を必ず出す。読者が「いま何をすればいいか」を探さずに済むようにする。
# 非対話シェル（docker run … lab check 03 のような素通し）では出さない。
case $- in *i*) ;; *) return ;; esac
[ -x /usr/local/bin/lab ] || return

printf '\n'
printf '── %s ' "lab-${LAB_THEME:-base} ${LAB_VERSION:-}"
printf '%.0s─' $(seq 1 40); printf '\n'
/usr/local/bin/lab status
printf '  lab ls      演習一覧 / lab start NN  課題を開く / lab check  答え合わせ\n'
printf '%.0s─' $(seq 1 60); printf '\n\n'
