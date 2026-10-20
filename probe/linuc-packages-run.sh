#!/bin/bash
# LinuC 主題1.04 の記録を取り直す（母艦で走らせる）。2026-10-20 の作り直し（1.1.0）からの形。
#
#   bash probe/linuc-packages-run.sh tty     → 本文の $ 行を、読者と同じ端末（80 桁 × 24 行・端末つきの対話シェル）で
#                                              章ごとに起動し直した檻に打った記録 logs/linuc-packages-{deb,rpm}-tty.log を取り、
#                                              本文の組と突き合わせる（probe/linuc-packages-seq.py・-seqcompare.py）。本文の出力の正本
#   bash probe/linuc-packages-run.sh probe   → 本文が画面を載せずに言い切っていること（表・確認問題の答え・たとえの崩れる点・
#                                              演習のヒントと解答のコマンド）を、同じ打ち方で確かめる → logs/linuc-packages-{deb,rpm}-probe.log
#                                              （「ふつうこう考える」で詰まったやり方は、本文の順の記録 tty の各章にある）
#   bash probe/linuc-packages-run.sh extra   → 課題文の「いまの状態」の画面（lab start NN のあとに課題文のコマンドを打つ）
#                                              → logs/linuc-packages-{deb,rpm}-extra.log
#   bash probe/linuc-packages-run.sh exam    → 本文の表と説明が拠っている man・--help の記述 → logs/linuc-packages-{deb,rpm}-exam.log
#   bash probe/linuc-packages-run.sh offline → ネットにつながっていないときに本文と違って出るところを、名前を引けない檻で打つ
#                                              → logs/linuc-packages-{deb,rpm}-offline.log
#   bash probe/linuc-packages-run.sh solve   → 演習を模範解答どおりに通す（未達で ✗、解答どおりで ✔）
#                                              → logs/linuc-packages-{deb,rpm}-solve-all.log
#   bash probe/linuc-packages-run.sh one deb|rpm 入力.txt   → 入力ファイルを1回打って標準出力へ（作業中の確認用）
#
# 端末つきの記録（tty・probe・extra・exam・offline）は読者と同じ起動（docker run --rm -it --hostname linuc、名前の無いボリューム2つ）。
# solve だけは、判定の出力を見るためのもので、docker exec で lab ユーザのシェルを開いて流す（端末なし）。
#   読者の起動コマンドとの違いは2つだけ:
#   - -it の代わりに -d と sleep infinity。シェルは docker exec で lab として開く
#   - 名前付きボリュームの代わりに無名ボリューム。マウント先は同じ（/home/lab/work と /home/lab/.lab）
set -u
cd /home/shun/learning-labs || exit 1
DEB=lab-linuc-packages-deb:1.1.0
RPM=lab-linuc-packages-rpm:1.1.0
SEQ="python3 -I probe/linuc-packages-seq.py"

one_exec() {  # one_exec <image> <script> <arg>
  local image="$1" script="$2" arg="$3"
  local name="linuc-packages-solve-${arg}"
  docker rm -fv "$name" >/dev/null 2>&1
  docker run -d --name "$name" --hostname linuc \
    -v /home/lab/work -v /home/lab/.lab "$image" sleep infinity >/dev/null || return 1
  docker cp "$script" "$name:/tmp/solve.sh" >/dev/null
  docker exec -u lab -w /home/lab "$name" bash /tmp/solve.sh "$arg"
  docker rm -fv "$name" >/dev/null
}

case "${1:-}" in
  tty)
    $SEQ && python3 -I probe/linuc-packages-seqcompare.py
    ;;
  probe|extra|exam|offline)
    # 入力は probe/linuc-packages-{deb,rpm}-<種類>.sh の中のヒアドキュメント（スクリプトが seq.py を呼ぶ）
    for cage in deb rpm; do
      bash "probe/linuc-packages-${cage}-$1.sh"
    done
    ;;
  solve)
    one_exec "$DEB" probe/linuc-packages-deb-solve-all.sh deb > logs/linuc-packages-deb-solve-all.log 2>&1
    one_exec "$RPM" probe/linuc-packages-rpm-solve-all.sh rpm > logs/linuc-packages-rpm-solve-all.log 2>&1
    ;;
  one)
    case "${2:-}" in
      deb|rpm) $SEQ --script "$3" --cage "$2" --out /dev/stdout ;;
      *) echo "使い方: bash probe/linuc-packages-run.sh one deb|rpm 入力.txt" >&2; exit 2 ;;
    esac
    ;;
  *) echo "使い方: bash probe/linuc-packages-run.sh tty|probe|extra|exam|offline|solve|one" >&2; exit 2 ;;
esac
