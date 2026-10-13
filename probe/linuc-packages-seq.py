#!/usr/bin/env python3
"""LinuC 主題1.04: 本文の端末ブロックを、読者と同じ起動・同じ端末で、章ごとに打った記録を取る。

  python3 -I probe/linuc-packages-seq.py [--cols 80 --rows 24] [--chapters 1,2]
      → logs/linuc-packages-deb-tty.log と logs/linuc-packages-rpm-tty.log（--out-dir で置き場所を変えられる）
  python3 -I probe/linuc-packages-seqcompare.py      → 本文の組と突き合わせる

本文のもとの記録（probe / extra / exam）は docker exec で、端末なしで取った。読者は docker run -it の端末で
打つので、端末の有無で出力が変わるコマンド（apt の WARNING・Listing... の Done・進み具合の表示、ls の段組み、
dpkg -l のページャ）は、本文と違って見える。そこで本文の $ 行を本文の順に機械的に取り出し、読者と同じ起動の
檻に、端末つきで打ち込んだ記録を取る（2026-10-13。考え方は probe/linuc-text-seq.py と同じ）。

- 檻は章ごとに起動し直す（本文の前提「檻を起動し直した直後」）。第2〜4章は Debian 系、第5〜7章は RPM 系。
  第1章は2つを並べて使う（RPM 系の端末ブロックは <pre data-cage="rpm"> と印を付けてある）。
- 起動は読者の起動コマンドと同じ docker run --rm -it --hostname linuc。ボリュームは名前を付けない2つ
  （/home/lab/work と /home/lab/.lab。--rm でコンテナと一緒に消える）。
- 端末は tmux（専用のソケット・設定ファイルを読まない・ステータス行なし）。幅 80 × 高さ 24 が既定。
  tmux は端末として画面を描くので、記録は「読者の画面に最後に残るもの」になる（\r で書き換えられる行は
  最後の形、apt の最下行の進み具合は消えたあと、幅を超える行は折り返しをつないだ1行）。
- 記録のための操作は1つだけ: 最初に PROMPT_COMMAND で PS1 を "$ "（＋端末の題名に通し番号）にする。
  題名の番号が変わったら、コマンドが終わってプロンプトに戻ったと分かる。行頭に空白を置くので履歴には残らない。
- プロンプトに戻らないコマンド（ページャの (END) で止まるなど）は、画面の最下行を記録に残してから q を送る
  （それでも戻らなければ、外から pts/0 の一番新しいプロセスを止める）。突き合わせはこれを違いとして数える。
  本文に「（打鍵: q）」の行があれば、読者が打つものとして q を送る（そのときは違いにしない）。
"""
import argparse, html, re, subprocess, sys, time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
THEORY = REPO / "public" / "linuc-packages" / "theory"
IMG = {"deb": "lab-linuc-packages-deb:1.0.1", "rpm": "lab-linuc-packages-rpm:1.0.1"}
DEFAULT_CAGE = {1: "deb", 2: "deb", 3: "deb", 4: "deb", 5: "rpm", 6: "rpm", 7: "rpm"}
SOCK = "linuc-packages-seq"
PAGER_BOTTOM = re.compile(r"\(END\)\s*$|^lines \d+-\d+|^:\s*$")
STUCK, WARN = [], []


def pages(chapters=None):
    out = []
    for f in sorted(THEORY.glob("0[1-7]-*.html")):
        n = int(f.name[:2])
        if not chapters or n in chapters:
            out.append((n, f))
    return out


def blocks_of(n, f):
    """章の端末ブロックを本文の順に: [(檻, [手順, ...]), ...]。手順は {"cmd", "keys"}。"""
    s = f.read_text(encoding="utf-8")
    res = []
    for m in re.finditer(r"<pre\b([^>]*)><code>([\s\S]*?)</code></pre>", s):
        lines = html.unescape(re.sub(r"<[^>]+>", "", m.group(2))).split("\n")
        if not any(l.startswith("$ ") for l in lines):
            continue
        mc = re.search(r'data-cage="(deb|rpm)"', m.group(1))
        cage = mc.group(1) if mc else DEFAULT_CAGE[n]
        steps = []
        for raw in lines:
            l = re.sub(r"\s{2,}←.*$", "", raw)
            if l.startswith("$ "):
                steps.append({"cmd": l[2:], "keys": None})
            elif steps:
                mk = re.fullmatch(r"（打鍵: (.*)）", l.strip())
                if mk:
                    steps[-1]["keys"] = mk.group(1)
        res.append((cage, steps))
    return res


def tm(*args, check=False):
    r = subprocess.run(["tmux", "-u", "-L", SOCK, *args], capture_output=True, text=True)
    if check and r.returncode != 0:
        raise RuntimeError(f"tmux {args[0]}: {r.stderr.strip()}")
    return r.stdout


def info(t):
    out = tm("display", "-p", "-t", t, "#{pane_title}\t#{history_size}\t#{cursor_y}\t#{pane_dead}")
    parts = out.rstrip("\n").split("\t")
    if len(parts) != 4:
        return None, 0, 0, "1"
    return parts[0], int(parts[1]), int(parts[2]), parts[3]


def bottom_line(t):
    lines = tm("capture-pane", "-p", "-t", t).rstrip("\n").split("\n")
    while lines and not lines[-1].strip():
        lines.pop()
    return lines[-1] if lines else ""


class Cage:
    def __init__(self, cage, cols, rows, first):
        self.cage, self.name = cage, f"linuc-packages-seq-{cage}"
        subprocess.run(["docker", "rm", "-f", "-v", self.name], capture_output=True)
        run = (f"docker run --rm -it --name {self.name} --hostname linuc "
               f"-v /home/lab/work -v /home/lab/.lab {IMG[cage]}")
        if first:   # サーバを起こし、設定を決めてから最初のセッションを作る（設定ファイルは読まない）
            tm("-f", "/dev/null", "start-server", ";", "set", "-g", "history-limit", "200000", ";",
               "set", "-g", "status", "off", ";",
               "new-session", "-d", "-s", cage, "-x", str(cols), "-y", str(rows), run, check=True)
        else:
            tm("new-session", "-d", "-s", cage, "-x", str(cols), "-y", str(rows), run, check=True)
        # 起動の案内が出て、檻のプロンプト（端末の題名 lab@linuc: ~）が出るまで待つ
        end = time.time() + 120
        while time.time() < end:
            title, *_ = info(cage)
            if title and "@linuc" in title:
                break
            time.sleep(0.3)
        else:
            raise RuntimeError(f"{cage}: 檻のプロンプトが出ない")
        time.sleep(1.0)
        tm("send-keys", "-t", cage, "-l",
           " export PROMPT_COMMAND='__n=$((__n+1)); PS1=\"\\[\\e]0;SEQ$__n\\a\\]\\$ \"'")
        tm("send-keys", "-t", cage, "Enter")
        self.wait_title(lambda x: x.startswith("SEQ"), 30)

    def wait_title(self, ok, timeout):
        end = time.time() + timeout
        while time.time() < end:
            title, *_ = info(self.cage)
            if title and ok(title):
                return True
            time.sleep(0.2)
        return False

    def run(self, cmd, keys):
        """1つのコマンドを打ち、記録に書く行（"$ cmd" の行を除いた出力）を返す。"""
        title0, hs0, cy0, _ = info(self.cage)
        top = hs0 + cy0                       # いまのプロンプトの行（絶対行）
        tm("send-keys", "-t", self.cage, "-l", cmd)
        tm("send-keys", "-t", self.cage, "Enter")
        done = lambda x: x.startswith("SEQ") and x != title0
        notes = []
        # 本文の「（打鍵: …）」: 読者が打つキーとして送る。ただし、そのときコマンドがまだ動いているときだけ
        # （幅の広い端末では dpkg -l のページャが止まらずに閉じる。そこへ q を送るとシェルに打ち込んでしまう）
        if keys and not self.wait_title(done, 2.0):
            for k in keys.split(" "):
                tm("send-keys", "-t", self.cage, "-l", k)
                time.sleep(0.5)
        elif keys:
            notes.append("（打鍵は要らなかった。コマンドはすぐプロンプトに戻った）")
        end, finished = time.time() + 180, False
        while time.time() < end:
            if self.wait_title(done, 3):
                finished = True
                break
            if PAGER_BOTTOM.search(bottom_line(self.cage)):
                notes.append(f"（プロンプトに戻らなかった。最下行: {bottom_line(self.cage).strip()}）")
                STUCK.append(f"{self.cage}: $ {cmd}")
                tm("send-keys", "-t", self.cage, "q")
                finished = self.wait_title(done, 15)
                break
        if not finished:
            notes.append("（プロンプトに戻らなかった。外から止めて続けた）")
            STUCK.append(f"{self.cage}: $ {cmd}")
            subprocess.run(["docker", "exec", self.name, "pkill", "-KILL", "-n", "-t", "pts/0"],
                           capture_output=True)
            if not self.wait_title(done, 30):
                raise RuntimeError(f"{self.cage}: 止まったまま戻らない: {cmd}")
        time.sleep(0.3)
        title1, hs1, cy1, _ = info(self.cage)
        bot = hs1 + cy1                       # 次のプロンプトの行
        text = tm("capture-pane", "-p", "-J", "-t", self.cage,
                  "-S", str(top - hs1), "-E", str(bot - hs1))
        # タブは画面では空白になる（ls の段組み）。読者が見るとおり、8 桁ごとの空白に戻す
        lines = [l.expandtabs(8).rstrip() for l in text.split("\n")]
        while lines and lines[-1] == "":
            lines.pop()
        # 最後の行は次のプロンプト（"$ "）。出力が改行で終わっていなければ、その前に出力が続いている
        if lines and lines[-1].endswith("$"):
            rest = lines[-1][:-1].rstrip()
            lines = lines[:-1] + ([rest] if rest else [])
        echo = "$ " + cmd
        if not lines or lines[0].rstrip() != echo.rstrip():
            WARN.append(f"{self.cage}: こだまが合わない: {cmd!r} / 画面 {lines[:1]!r}")
        body = lines[1:] if lines else []
        if keys:
            body = [f"（打鍵: {keys}）"] + body
        return body + notes

    def alive(self):
        r = subprocess.run(["tmux", "-u", "-L", SOCK, "has-session", "-t", self.cage], capture_output=True)
        return r.returncode == 0 and info(self.cage)[3] != "1"

    def close(self):
        for _ in range(3):                    # PID 1 のシェルを exit で抜ける（檻ごと消える）
            if not self.alive():
                break
            tm("send-keys", "-t", self.cage, "-l", "exit")
            tm("send-keys", "-t", self.cage, "Enter")
            time.sleep(1.5)
        tm("kill-session", "-t", self.cage)
        # --rm の自動削除を待たずに消す場合も、名前の無いボリュームを -v で一緒に消す
        subprocess.run(["docker", "rm", "-f", "-v", self.name], capture_output=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cols", type=int, default=80)
    ap.add_argument("--rows", type=int, default=24)
    ap.add_argument("--chapters", default="")
    ap.add_argument("--out-dir", default=str(REPO / "logs"))
    a = ap.parse_args()
    chapters = {int(x) for x in a.chapters.split(",") if x.strip()} or None
    outdir = Path(a.out_dir)
    head = lambda cage: [
        "# 本文の端末ブロックから機械的に作った入力を、読者と同じ起動（docker run --rm -it --hostname linuc、",
        "# 名前の無いボリューム2つ、PID 1 の bash -l、umask 022、TERM=xterm）の檻に、章ごとに起動し直して打った記録。",
        f"# 端末 {a.cols} 桁 × {a.rows} 行（tmux）。画面に最後に残ったものを書く。"
        f"作り方: python3 -I probe/linuc-packages-seq.py（イメージ {IMG[cage]}）"]
    logs = {"deb": head("deb"), "rpm": head("rpm")}
    tm("kill-server")
    first, n = True, 0
    try:
        for ch, f in pages(chapters):
            cages = {}
            try:
                for cage, steps in blocks_of(ch, f):
                    if cage not in cages:
                        cages[cage] = Cage(cage, a.cols, a.rows, first)
                        first = False
                        logs[cage].append(f"\n\n========== {ch}. {f.name} ==========")
                    for st in steps:
                        body = cages[cage].run(st["cmd"], st["keys"])
                        logs[cage].append(f"\n$ {st['cmd']}")
                        logs[cage].extend(body)
                        n += 1
                        print(f"\r{ch}章 {n} コマンド", end="", file=sys.stderr, flush=True)
            finally:
                for c in cages.values():
                    c.close()
    finally:
        tm("kill-server")
        for cage in ("deb", "rpm"):
            p = outdir / f"linuc-packages-{cage}-tty.log"
            p.write_text("\n".join(logs[cage]) + "\n", encoding="utf-8")
    for w in STUCK:
        print("\n止まった: " + w, file=sys.stderr)
    for w in WARN:
        print("\n注意: " + w, file=sys.stderr)
    print(f"\n→ {outdir}/linuc-packages-{{deb,rpm}}-tty.log（{n} コマンド）", file=sys.stderr)


if __name__ == "__main__":
    main()
