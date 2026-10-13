#!/usr/bin/env bash
# 演習 06 の判定。観測型（~/ex06 を別の場所に写し、greet.sh を書き換えて実際にビルドし、RUN の段が CACHED になるかを見る）。外（lab@host）で走り、練習機の中は lab-guest（qemu-guest-agent 経由・root）で見る。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値に引きずられないよう固定する
prereq() { echo "前提不足: 練習機が応答しません（起動の途中か、止まっている）。外で vm start を打ち、起動を待ってからもう一度"; exit 2; }
# 練習機に届くかを先に1回だけ確かめる。lab-guest は届かないとき 125 を返すが、podman や docker run も
# 自分の失敗に 125 を使うので、コマンドごとの 125 を「届かない」と読むと取り違える（実測: podman inspect の「無い」が 125）
lab-guest true >/dev/null 2>&1 || prereq

chk=$(lab-guest 'test -f /home/student/ex06/Dockerfile && test -f /home/student/ex06/greet.sh && echo ok' 2>&1); rc=$?
echo "判定 : 観測型（~/ex06 を写した場所で greet.sh を書き換えて実際にビルドし、段ごとのキャッシュの印と、出来たイメージの出力を見た）"
[ "$chk" = ok ] || { echo "観測 : ~/ex06 に Dockerfile と greet.sh が無い（課題の【準備】の段階）"; exit 1; }
# 1回目で手元のキャッシュに合わせ、greet.sh を書き換えた2回目の段ごとの印を見る（ビルドは root で。作ったものは消す）
log=$(lab-guest 'd=$(mktemp -d) && cp -r /home/student/ex06/. "$d"/ && cd "$d" && docker build -q -t lab-ex06-check:a . >/dev/null 2>&1; echo "# lab check 06" >> greet.sh; docker build --progress=plain -t lab-ex06-check:b . 2>&1; echo "=== run"; docker run --rm lab-ex06-check:b 2>&1; docker rmi lab-ex06-check:a lab-ex06-check:b >/dev/null 2>&1; cd / && rm -rf "$d"' 2>&1)
runstep=$(grep -oE '^#[0-9]+ \[[0-9]+/[0-9]+\] RUN .*sleep 8.*' <<<"$log" | head -1)
n=${runstep%% *}
out=$(sed -n '/^=== run$/,$p' <<<"$log" | tail -n +2 | tail -1)
if [ -z "$runstep" ]; then
  echo "観測 : ビルドの記録に、sleep 8 の RUN の段が見つからない（ビルドが失敗したか、段を書き換えたかもしれません）"
  grep -E 'ERROR|error' <<<"$log" | head -3 | sed 's/^/       /'
  exit 1
fi
echo "観測 : greet.sh を書き換えた後のビルドで、${runstep#* }"
if grep -qx "$n CACHED" <<<"$log"; then
  echo "       → CACHED（前回の層を使った）"
else
  echo "       → 作り直された（CACHED ではない）"
fi
echo "       出来たイメージの出力: ${out:-（無し）}"
grep -qx "$n CACHED" <<<"$log" || exit 1
[ "$out" = "hello, ready" ] || { echo "       出力が「hello, ready」ではない"; exit 1; }
echo "       → greet.sh を直しても、時間のかかる RUN の段（sleep 8）は作り直されない"
exit 0
