# linuc-boot の記録用スクリプト（probe / solve-all）が共通で使う道具。ホストの bash で source する。
#
# 記録の約束（本文の端末表示はすべてここから出る）:
#   H  … 外（lab@host）で打つコマンド。`$ ` 付きで書いてから docker exec で実行し、出力をそのまま記録する。
#   G  … 練習機の中（student@linuc）で打つコマンド。`$ ` 付きで書いてから外で ssh linuc '…' として実行する。
#        記録の `$ ` 行は、読者が練習機の中で打つ形（ssh linuc を付けない形）にしてある。
#        ssh 経由は非対話のシェルなので、色・別名（alias）・端末幅による折り返しは付かない。
#   tm_* … 対話が要るもの（GRUB のメニュー・パスワードの入力・Ctrl+Z・~. など）。
#        ホストの tmux を「読者の端末」として使い、docker exec -it で入った端末にキーを送って、
#        画面に出た文字をそのまま写し取る（tmux が描いた画面なので、制御文字は入らない）。
#        プロンプトは本文に合わせて PS1='$ ' にしている（実物は lab@host:~$ / student@linuc:~$）。
#   W  … 人が次の行を打つまでの間（秒）。記録には出さない。コマンドは足していない。
C=${C:-linuc-boot-probe}
LOG=${LOG:-/dev/null}
TM=(tmux -L "${TMUX_SOCK:-linuc-boot}")   # probe と solve-all を並べて走らせるときはソケットを分ける

S()    { LOG=$1; shift; printf '\n\n========== %s ==========\n' "$*" >> "$LOG"; }
note() { printf '\n# %s\n' "$*" >> "$LOG"; }
W()    { sleep "$1"; }
H()    { printf '\n$ %s\n' "$1" >> "$LOG"; docker exec -u lab -w /home/lab "$C" bash -c "$1" >> "$LOG" 2>&1; }
G()    { printf '\n$ %s\n' "$1" >> "$LOG"; docker exec -u lab -w /home/lab "$C" ssh linuc "$1" >> "$LOG" 2>&1; }
# 記録しない版（待ち合わせや準備に使う）
h()    { docker exec -u lab -w /home/lab "$C" bash -c "$1"; }
g()    { docker exec -u lab -w /home/lab "$C" ssh -o ConnectTimeout=5 linuc "$1"; }

# ---- 対話（ホストの tmux を読者の端末にする） ----------------------------------
tm_open() {   # tm_open 名前 [幅 高さ] — 端末を1つ開き、外のログインシェルに入る（docker exec -it … bash -l）
  local n=$1 w=${2:-160} hh=${3:-50}
  "${TM[@]}" kill-session -t "$n" 2>/dev/null
  "${TM[@]}" new-session -d -s "$n" -x "$w" -y "$hh" "docker exec -it -u lab -w /home/lab $C bash -l"
  "${TM[@]}" set-option -t "$n" history-limit 200000 >/dev/null
  tm_wait "$n" 'lab ls' 30
}
tm_close()  { "${TM[@]}" kill-session -t "$1" 2>/dev/null; }
tm_keys()   { "${TM[@]}" send-keys -t "$1" "${@:2}"; }                       # キーをそのまま（Enter C-z Up …）
tm_type()   { "${TM[@]}" send-keys -t "$1" -l "$2"; "${TM[@]}" send-keys -t "$1" Enter; }  # 1行打って Enter
tm_lit()    { "${TM[@]}" send-keys -t "$1" -l "$2"; }                        # 文字だけ（Enter なし）
tm_screen() { "${TM[@]}" capture-pane -p -t "$1"; }                          # いま見えている画面
tm_all()    { "${TM[@]}" capture-pane -p -J -S - -E - -t "$1"; }             # 履歴を含めた全部（折り返しは繋ぐ）
tm_ready()  { tm_screen "$1" | sed -e 's/[[:space:]]*$//' | grep -v '^$' | tail -1 | grep -qx '\$'; }  # プロンプト（$）だけの行で止まっている
tm_fresh()  {  # 画面と履歴を空にする（clear が効いてから履歴を消す）
  local i; tm_type "$1" clear
  for ((i = 0; i < 40; i++)); do tm_ready "$1" && break; sleep 0.25; done
  "${TM[@]}" clear-history -t "$1"
}
tm_run() {   # tm_run 端末 コマンド [秒] — 読者と同じ対話の端末で打ち、プロンプトが戻るまで待つ
  local n=$1 c=$2 t=${3:-120} i
  tm_type "$n" "$c"; sleep 0.7
  for ((i = 0; i < t * 4; i++)); do tm_ready "$n" && { sleep 0.3; return 0; }; sleep 0.25; done
  printf '\n# [プロンプトが戻らない: %s]\n' "$c" >> "$LOG"; return 1
}
tm_last()   { tm_screen "$1" | sed -e 's/[[:space:]]*$//' | grep -v '^$' | tail -1; }  # 画面の最後の空でない行
tm_wait_last() {  # tm_wait_last 端末 正規表現 [秒] — 画面の最後の行が合うまで待つ（履歴の古い行に引っかからない）
  local n=$1 pat=$2 t=${3:-120} i
  for ((i = 0; i < t * 4; i++)); do tm_last "$n" | grep -qE -- "$pat" && return 0; sleep 0.25; done
  printf '\n# [待ちきれなかった（最後の行）: %s]\n' "$pat" >> "$LOG"; return 1
}
tm_count() { tm_all "$1" | grep -c -- "$2"; }
tm_closed_wait() {  # tm_closed_wait 端末 前の数 — 「Connection to 127.0.0.1 closed」が1行増え、外のプロンプトに戻るまで待つ
  local n=$1 before=$2 i
  for ((i = 0; i < 480; i++)); do [ "$(tm_count "$n" 'Connection to 127.0.0.1 closed')" -gt "$before" ] && break; sleep 0.25; done
  tm_wait_last "$n" '^\$$' 30
}
tm_leave() {  # tm_leave 端末 コマンド — 練習機の中で打って ssh が閉じるまで待つ（exit / sudo reboot / sudo halt …）
  local n=$1 c=$2 before; before=$(tm_count "$n" 'Connection to 127.0.0.1 closed')
  tm_type "$n" "$c"; tm_closed_wait "$n" "$before"
}
tm_leave_keys() {  # tm_leave_keys 端末 キー… — キーで抜ける（C-d など）
  local n=$1 before; shift; before=$(tm_count "$n" 'Connection to 127.0.0.1 closed')
  "${TM[@]}" send-keys -t "$n" "$@"; tm_closed_wait "$n" "$before"
}
tm_cut() {  # tm_cut 端末 — Enter を押してから ~. で ssh をその場で切る（回線が切れたのと同じ）
  local n=$1 before; before=$(tm_count "$n" 'Connection to 127.0.0.1 closed')
  tm_keys "$n" Enter; sleep 0.8; tm_lit "$n" '~.'; tm_closed_wait "$n" "$before"
}
tm_login() {  # tm_login 端末 — 外の端末から ssh linuc で練習機に入り、プロンプトを本文に合わせる（鍵で入れる前提）
  local n=$1
  tm_type "$n" 'ssh linuc'
  tm_wait_last "$n" 'student@linuc:~\$$' 60 || return 1
  sleep 0.3; tm_type "$n" "PS1='\$ '"
  tm_wait_last "$n" '^\$$' 10
}
tm_wait() {   # tm_wait 名前 正規表現 [秒] — 画面（履歴込み）に現れるまで待つ
  local n=$1 pat=$2 t=${3:-120} i
  for ((i = 0; i < t; i++)); do tm_all "$n" | grep -qE -- "$pat" && return 0; sleep 1; done
  printf '\n# [待ちきれなかった: %s]\n' "$pat" >> "$LOG"; return 1
}
tm_record() { # tm_record 名前 見出し — 履歴込みの画面を記録に写す（行末の空白を落とし、空行の連続を1つにする）
  { printf '\n# --- 画面の写し: %s ---\n' "$2"; tm_all "$1" | sed -e 's/[[:space:]]*$//' | cat -s; printf '# --- ここまで ---\n'; } >> "$LOG"
}
tm_shot() {   # tm_shot 名前 見出し — いま見えている画面だけを写す（GRUB のメニューなど）
  { printf '\n# --- 画面の写し（見えている範囲）: %s ---\n' "$2"; tm_screen "$1" | sed -e 's/[[:space:]]*$//'; printf '# --- ここまで ---\n'; } >> "$LOG"
}

# ---- GRUB（コンソールの端末 con で） ----------------------------------------------
#   80x24 の端末では見出し（GNU GRUB version 2.12）が画面外に出るので、数え下げの行で「メニューが出た」と判断する。
grub_wait_menu() { local i; for ((i = 0; i < ${1:-1200}; i++)); do tm_screen con | grep -q 'executed automatically in' && return 0; sleep 0.1; done; return 1; }
grub_stop() {     # 数え下げを止める。先頭のエントリ（Ubuntu）で ↑ を押すので、選択は動かない
  local i            # メニューが出た直後のキーは取りこぼされることがある（実測）。数え下げの行が消えるまで押す
  for ((i = 0; i < 8; i++)); do
    tm_keys con Up; sleep 1
    tm_screen con | grep -q 'executed automatically in' || break
  done
  tm_keys con Up; sleep 0.5; tm_keys con Up; sleep 0.5
}
grub_e() {        # e を押して編集画面を出す（出るまで3回まで押し直す）
  local i j
  for ((i = 0; i < 3; i++)); do
    tm_keys con e
    for ((j = 0; j < 20; j++)); do tm_screen con | grep -q 'setparams' && return 0; sleep 0.2; done
  done
  printf '\n# [GRUB の編集画面が出ない]\n' >> "$LOG"; return 1
}
grub_add() {      # grub_add 足す語 — 編集画面で linux の行（11行目）の末尾へ行き、語を足す
  local i
  for i in $(seq 1 10); do tm_keys con Down; sleep 0.3; done
  tm_keys con C-e; sleep 0.5
  tm_lit con " $1"; sleep 1.5
}

# ---- 練習機の待ち合わせ（記録しない） --------------------------------------------
vm_state()   { h 'virsh domstate linuc 2>/dev/null | head -1'; }
wait_agent() { local i; for ((i = 0; i < ${1:-240}; i++)); do h 'lab-guest true' >/dev/null 2>&1 && return 0; sleep 1; done; return 1; }
wait_ssh()   { local i; for ((i = 0; i < ${1:-240}; i++)); do g true >/dev/null 2>&1 && return 0; sleep 1; done; return 1; }
wait_off()   { local i; for ((i = 0; i < ${1:-180}; i++)); do [ "$(vm_state)" = "shut off" ] && return 0; sleep 1; done; return 1; }
wait_provisioned() { local i; for ((i = 0; i < ${1:-240}; i++)); do h 'test -f ~/vm/.provisioned' && return 0; sleep 1; done; return 1; }
wait_system() { # 練習機の systemd が起動を終えるまで（running か degraded）
  local i s; for ((i = 0; i < ${1:-240}; i++)); do
    s=$(h "lab-guest 'systemctl is-system-running' 2>/dev/null"); case "$s" in running|degraded) return 0 ;; esac; sleep 1
  done; return 1
}
