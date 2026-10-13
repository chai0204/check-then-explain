#!/usr/bin/env bash
# 演習 01 の判定。観測型（疑似端末の上で bob と alice のシェルを実際に起動し、出てきた文字を数える）。
# 「どのファイルに書いたか」は見ない。起動したときに何が出たかだけを見る。
set -uo pipefail
id bob   >/dev/null 2>&1 || { echo "前提不足: ユーザ bob がいません（イメージが違う可能性）"; exit 2; }
id alice >/dev/null 2>&1 || { echo "前提不足: ユーザ alice がいません（イメージが違う可能性）"; exit 2; }
command -v script >/dev/null || { echo "前提不足: script コマンドがありません"; exit 2; }
sudo -n true 2>/dev/null || { echo "前提不足: sudo がパスワードなしで使えません"; exit 2; }

msg="ようこそ bob さん"
mark="__子のシェル__"

# 人が端末で打つのと同じ形で起動する。疑似端末（script）の上で動かし、少し待ってから1行ずつ打つ。
term() {  # term "起動コマンド" 入力1 入力2 ...
  local cmd=$1; shift
  { for l in "$@"; do sleep 1; printf '%s\n' "$l"; done; sleep 0.5; } \
    | (cd /tmp && script -q -c "$cmd" /dev/null) 2>&1 | tr -d '\r'
}

out=$(term "sudo -iu bob" "echo $mark" bash exit exit)
login_part=$(sed "/^${mark}\$/,\$d" <<<"$out")
child_part=$(sed -n "/^${mark}\$/,\$p" <<<"$out")
alice_out=$(term "sudo -iu alice" exit)

n_login=$(grep -c -- "$msg" <<<"$login_part")
n_child=$(grep -c -- "$msg" <<<"$child_part")
n_alice=$(grep -c -- "$msg" <<<"$alice_out")
files=$(sudo ls -A /home/bob 2>/dev/null \
  | grep -E '^\.(bash_profile|bash_login|profile|bashrc|bash_logout)$' | tr '\n' ' ')

echo "判定 : 観測型（疑似端末で bob のログインシェルを起動し、その中で bash と打った。alice のログインも起動した）"
echo "観測 : 「$msg」が出た回数"
echo "         bob のログインシェル（sudo -iu bob）      $n_login 回"
echo "         そこで bash と打った子のシェル            $n_child 回"
echo "         alice のログインシェル（sudo -iu alice）  $n_alice 回"
echo "       bob のホームにある起動ファイル: $files"

ng=0
[ "$n_login" -eq 1 ] || { echo "       → ログインシェルで $n_login 回出た（1回ではない）"; ng=1; }
[ "$n_child" -eq 0 ] || { echo "       → ログインしない子のシェルでも出た"; ng=1; }
[ "$n_alice" -eq 0 ] || { echo "       → alice のログインでも出た"; ng=1; }
[ "$ng" = 0 ] || exit 1

echo "       bob がログインしたときだけ1回出ている"
echo "       → ログインシェルが読んだファイルと、子のシェルが読んだファイルは別のもの"
exit 0
