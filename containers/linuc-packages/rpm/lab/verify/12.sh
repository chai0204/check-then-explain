#!/usr/bin/env bash
# 演習 12 の判定。観測型（~/work/12 の .rpm の中身、rpm の台帳、dnf の取引の記録を見る）。
set -uo pipefail
command -v rpm >/dev/null || { echo "前提不足: rpm が見つかりません"; exit 2; }
dir="$HOME/work/12"

# ~/work/12 にある .rpm を、ファイル名ではなく中身（rpm -qp）で数える
names=""
for f in "$dir"/*.rpm; do
  [ -f "$f" ] || continue
  n=$(rpm -qp --qf '%{NAME}' "$f" 2>/dev/null) && names="$names $n"
done
has() { case " $names " in *" $1 "*) return 0 ;; esac; return 1; }
# どの道具で入ったか（"rpm"、または "yum リポジトリ名"）。
# yum list installed の右端（@System など）は使わない。dnf は、その版について最後に残した記録を出し続けるので、
# yum で入れて消した版を rpm で入れ直しても @@System・@@commandline・@lab のままになる（実測 2026-10-21）。
# 代わりに、dnf の取引の記録（/var/lib/dnf/history.sqlite。一般ユーザも読める）で、この版を入れた最後の取引
# （Install 1・Downgrade 2・Obsolete 4・Upgrade 6・Reinstall 9 で、済んだもの）を探し、rpm の台帳の
# 「入れた時刻」（INSTALLTIME）がその取引の終わりより後なら、そのあと rpm で入れ直したものとみなす。
# 時刻は秒までなので、yum の取引と同じ秒のうちに rpm で入れ直すと yum と見分けられない。人の手では1秒以上
# あくが、機械で続けて打つ記録（probe など）では、間に1つコマンドをはさむ。
how() {
  python3 -I - "$1" <<'PY'
import sqlite3, subprocess, sys
q = subprocess.run(["rpm", "-q", "--qf", "%{NAME} %{VERSION} %{RELEASE} %{ARCH} %{INSTALLTIME}", sys.argv[1]],
                   capture_output=True, text=True)
if q.returncode != 0:
    print("none"); sys.exit()
n, v, r, a, t = q.stdout.split()
row = None
try:
    db = sqlite3.connect("file:/var/lib/dnf/history.sqlite?mode=ro", uri=True)
    row = db.execute(
        "SELECT COALESCE(t.dt_end, t.dt_begin, 0), repo.repoid FROM trans_item ti"
        " JOIN trans t ON t.id = ti.trans_id JOIN rpm ON rpm.item_id = ti.item_id"
        " JOIN repo ON repo.id = ti.repo_id"
        " WHERE rpm.name = ? AND rpm.version = ? AND rpm.release = ? AND rpm.arch = ?"
        "   AND ti.action IN (1, 2, 4, 6, 9) AND ti.state = 1"
        " ORDER BY t.id DESC LIMIT 1", (n, v, r, a)).fetchone()
except sqlite3.Error:
    pass
print("yum " + row[1] if row and int(t) <= int(row[0]) else "rpm")
PY
}

echo "判定 : 観測型（~/work/12 の .rpm の中身と、rpm の台帳と、dnf の記録を見た）"
echo "観測 : ~/work/12 の .rpm =${names:- 無い}"
issues=()
for p in labtool labtool-data; do
  if rpm -q "$p" >/dev/null 2>&1; then
    h=$(how "$p")
    case "$h" in
      rpm) by="rpm で入った" ;;
      "yum @commandline") by="yum で入った"
           issues+=("$p は yum が手元のファイルから入れた（rpm ではない）") ;;
      yum\ *) by="yum で入った"
           issues+=("$p は yum がリポジトリ ${h#yum } から入れた（rpm ではない）") ;;
      *) by="入れた道具が分からない"; issues+=("$p を入れた道具が分からない") ;;
    esac
    echo "       $p = $(rpm -q "$p")（$by）"
  else
    echo "       $p = rpm の台帳に無い"
    issues+=("$p が rpm の台帳に無い")
  fi
  has "$p" || issues+=("~/work/12 に $p の .rpm が無い")
done
if command -v labtool >/dev/null 2>&1; then
  out=$(labtool 2>&1); rc=$?
  echo "       labtool = $out（終了コード $rc）"
  [ "$rc" = 0 ] || issues+=("labtool が終了コード $rc で終わった")
else
  echo "       labtool = コマンドとして見つからない"
  issues+=("labtool が動かない")
fi
if [ "${#issues[@]}" -gt 0 ]; then
  printf '       → %s\n' "${issues[@]}"
  exit 1
fi

echo "       取ってきた2つの .rpm から rpm で入り、labtool が動いた"
exit 0
