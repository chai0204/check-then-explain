#!/usr/bin/env python3
"""LinuC 主題1.04: ヒントと模範解答のヒアドキュメントを、画面から写して打っても通るかを確かめる記録。

  python3 -I probe/linuc-packages-paste.py      → logs/linuc-packages-{deb,rpm}-paste.log

lab hint・lab solve は .md をそのまま画面に出す。読者はその画面から写して端末に貼る。
ヒアドキュメント（<<'END' 〜 END）は、行頭に空白があると END で終わらず、終わらせても中身の各行が
字下げされたファイルになる（.repo は yum が黙って読まず、control は dpkg-deb が断る）。そこで .md では、
ヒアドキュメントの塊だけを行頭に空白を入れずに書いた（2026-10-21、2回目の独立確認の指摘 新9）。

この記録は、その塊が画面の文字のままで通ることを見る。読者と同じ起動の檻（probe/linuc-packages-seq.py の Cage）で、
  1. 塊の前までの手順を打ち、lab hint NN（3段目まで）か lab solve NN を打って、塊を画面に出す
  2. 端末の画面（tmux の capture-pane。スクロールして消えた行も含む）から、塊の1行目から END の行までを取り出す
  3. その文字列を1行ずつ、そのまま端末へ送る（続きのプロンプト "> " が出てから次の行。貼り付けと同じ入力になる）
  4. できたファイルを cat -A で見て（行頭に空白が無いこと）、解答の続きを打ち、lab check NN で ✔ になるかを見る
節（========== 題 ==========）ごとに檻を起動し直す。
"""
import importlib.util, sys
from pathlib import Path
from types import SimpleNamespace

REPO = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("seq", REPO / "probe" / "linuc-packages-seq.py")
seq = importlib.util.module_from_spec(spec)
spec.loader.exec_module(seq)

D08 = ["$ lab start 08", "$ cd ~/work/08", "$ mkdir -p labmine/usr/bin labmine/DEBIAN",
       "$ cp labmine.sh labmine/usr/bin/labmine", "$ chmod 755 labmine/usr/bin/labmine"]
A08 = ["$ cat -A labmine/DEBIAN/control", "$ dpkg-deb --build --root-owner-group labmine .",
       "$ sudo apt install ./labmine_1.0_all.deb", "Do you want to continue? [Y/n] y",
       "$ labmine", "$ lab check 08"]
S08 = "cat > labmine/DEBIAN/control <<'END'"
A10 = ["$ cat -A /etc/yum.repos.d/lab-tools.repo", "$ yum repolist",
       "$ sudo yum install lab-mathtools", "Is this ok [y/N]: y", "Is this ok [y/N]: y",
       "$ labcalc 2 3", "$ lab check 10"]
S10 = "sudo tee /etc/yum.repos.d/lab-tools.repo <<'END'"

CASES = {
    "deb": [
        ("演習08 のヒント3段目: 画面に出た塊（cat > labmine/DEBIAN/control <<'END' 〜 END）を写して打つ",
         D08 + ["$ lab hint 08"] * 3, S08, A08),
        ("演習08 の模範解答: 画面に出た塊（cat > labmine/DEBIAN/control <<'END' 〜 END）を写して打つ",
         D08 + ["$ lab solve 08"], S08, A08),
    ],
    "rpm": [
        ("演習10 のヒント3段目: 画面に出た塊（sudo tee /etc/yum.repos.d/lab-tools.repo <<'END' 〜 END）を写して打つ",
         ["$ lab start 10"] + ["$ lab hint 10"] * 3, S10, A10),
        ("演習10 の模範解答: 画面に出た塊（sudo tee /etc/yum.repos.d/lab-tools.repo <<'END' 〜 END）を写して打つ",
         ["$ lab start 10", "$ lab solve 10"], S10, A10),
    ],
}


def block_from_screen(sess, start):
    """端末の画面（スクロールして消えた行も含む）から、最後に出た塊（start の行から END の行まで）を取り出す"""
    text = seq.tm("capture-pane", "-p", "-J", "-S", "-", "-t", sess)
    lines = [l.rstrip() for l in text.split("\n")]
    i = max(k for k, l in enumerate(lines) if l == start)
    j = next(k for k in range(i + 1, len(lines)) if lines[k] == "END")
    return lines[i:j + 1]


def main():
    a = SimpleNamespace(cols=80, rows=24, offline=False)
    seq.tm("kill-server")
    first = True
    try:
        for cage, cases in CASES.items():
            log = seq.head(cage, a, "") + [
                "# ↑ の作り方の代わりに: python3 -I probe/linuc-packages-paste.py",
                "# ヒントと模範解答のヒアドキュメントを、画面から写して打った記録（節ごとに檻を起動し直した）"]
            n = 0
            for title, before, start, after in cases:
                c = seq.Cage(cage, a.cols, a.rows, first, tag="-paste")
                first = False
                log.append(f"\n\n========== {title} ==========")
                try:
                    n += seq.record(seq.parse_lines(before), c, log)
                    blk = block_from_screen(c.sess, start)
                    n += seq.record([{"cmd": blk[0], "cont": blk[1:], "keys": None, "answers": []}], c, log)
                    n += seq.record(seq.parse_lines(after), c, log)
                finally:
                    c.close()
            out = REPO / "logs" / f"linuc-packages-{cage}-paste.log"
            out.write_text("\n".join(log) + "\n", encoding="utf-8")
            print(f"\n→ {out}（{n} コマンド）", file=sys.stderr)
    finally:
        seq.tm("kill-server")
    for w in seq.WARN + [f"止まった: {s}" for s in seq.STUCK]:
        print(w, file=sys.stderr)
    return 1 if seq.STUCK else 0


if __name__ == "__main__":
    sys.exit(main())
