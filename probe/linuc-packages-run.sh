#!/bin/bash
# LinuC 主題1.04 の記録を取り直す（母艦で走らせる）。
# 章ごとに檻を起動し直し、その中で probe を lab ユーザとして走らせる。
#
#   bash probe/linuc-packages-run.sh probe          → logs/linuc-packages-deb-probe.log と -rpm-probe.log
#   bash probe/linuc-packages-run.sh solve          → logs/linuc-packages-deb-solve-all.log と -rpm-solve-all.log
#   bash probe/linuc-packages-run.sh extra          → logs/linuc-packages-deb-extra.log と -rpm-extra.log（事実確認の後で足した記録）
#   bash probe/linuc-packages-run.sh exam           → logs/linuc-packages-deb-exam.log と -rpm-exam.log（公式例題の監査の後で足した記録）
#   bash probe/linuc-packages-run.sh one deb ch2    → 1節だけ標準出力へ（作業中の確認用）
#
# 読者の起動コマンド（本文に書いたもの）との違いは2つだけ:
#   - -it の代わりに -d と sleep infinity。シェルは docker exec で lab として開く
#   - 名前付きボリュームの代わりに無名ボリューム。マウント先は同じ（/home/lab/work と /home/lab/.lab）。
#     空のボリュームに中身と所有者が写される動きは名前付きと同じで、docker rm -v で一緒に片付く
# --hostname linuc は読者と同じに付ける（出力に出るホスト名を揃えるため）。
set -u
cd /home/shun/learning-labs || exit 1
DEB=lab-linuc-packages-deb:1.0.1
RPM=lab-linuc-packages-rpm:1.0.1

one() {  # one <image> <script> <section>
  local image="$1" script="$2" section="$3"
  local name="linuc-packages-probe-$section"
  docker rm -fv "$name" >/dev/null 2>&1
  docker run -d --name "$name" --hostname linuc \
    -v /home/lab/work -v /home/lab/.lab "$image" sleep infinity >/dev/null || return 1
  docker cp "$script" "$name:/tmp/probe.sh" >/dev/null
  docker exec -u lab -w /home/lab "$name" bash /tmp/probe.sh "$section"
  docker rm -fv "$name" >/dev/null
}

case "${1:-}" in
  probe)
    # 檻ごとに1本のログにまとめる。節ごとに檻を起動し直すので、節の見出しで区切って読む。
    #   bash probe/linuc-packages-run.sh probe         両方の檻
    #   bash probe/linuc-packages-run.sh probe rpm     片方だけ（もう片方のログの時刻を動かさない）
    if [ "${2:-deb}" = deb ] || [ -z "${2:-}" ]; then
      { for s in env ch1 ch2 ch3 ch4; do one "$DEB" probe/linuc-packages-deb-probe.sh "$s"; done; } \
        > logs/linuc-packages-deb-probe.log 2>&1
    fi
    if [ "${2:-rpm}" = rpm ] || [ -z "${2:-}" ]; then
      { for s in env ch1 ch5 ch6 ch7; do one "$RPM" probe/linuc-packages-rpm-probe.sh "$s"; done; } \
        > logs/linuc-packages-rpm-probe.log 2>&1
    fi
    ;;
  extra)
    # 事実確認（2026-10-13）を受けて足した記録（本文の端末表示の一部はここから引く）。
    { for s in x-upgrade x-autoremove x-root x-aptcmds x-un x-pending x-depends x-docs; do
        one "$DEB" probe/linuc-packages-deb-extra.sh "$s"; done; } > logs/linuc-packages-deb-extra.log 2>&1
    { for s in x-qp x-repoquery x-rpmsave; do
        one "$RPM" probe/linuc-packages-rpm-extra.sh "$s"; done; } > logs/linuc-packages-rpm-extra.log 2>&1
    ;;
  exam)
    # 公式例題（linuc.org/study/samples）の監査（2026-10-13）を受けて足した記録。
    #   bash probe/linuc-packages-run.sh exam          両方の檻
    #   bash probe/linuc-packages-run.sh exam deb      片方だけ（もう片方のログの時刻を動かさない）
    if [ "${2:-deb}" = deb ]; then
      { for s in e-showpkg; do
          one "$DEB" probe/linuc-packages-deb-exam.sh "$s"; done; } > logs/linuc-packages-deb-exam.log 2>&1
    fi
    if [ "${2:-rpm}" = rpm ]; then
      { for s in e-installed e-autoremove e-update; do
          one "$RPM" probe/linuc-packages-rpm-exam.sh "$s"; done; } > logs/linuc-packages-rpm-exam.log 2>&1
    fi
    ;;
  solve)
    one "$DEB" probe/linuc-packages-deb-solve-all.sh all > logs/linuc-packages-deb-solve-all.log 2>&1
    one "$RPM" probe/linuc-packages-rpm-solve-all.sh all > logs/linuc-packages-rpm-solve-all.log 2>&1
    ;;
  one)
    case "${2:-}" in
      deb) one "$DEB" "probe/linuc-packages-deb-${4:-probe}.sh" "$3" ;;
      rpm) one "$RPM" "probe/linuc-packages-rpm-${4:-probe}.sh" "$3" ;;
      *) echo "使い方: bash probe/linuc-packages-run.sh one deb|rpm <節> [probe|solve-all|extra|exam]" >&2; exit 2 ;;
    esac
    ;;
  *) echo "使い方: bash probe/linuc-packages-run.sh probe|solve|extra|exam|one" >&2; exit 2 ;;
esac
