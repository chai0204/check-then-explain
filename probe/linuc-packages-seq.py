#!/usr/bin/env python3
"""LinuC 主題1.04: 本文の端末ブロックを、読者と同じ起動・同じ端末で、章ごとに打った記録を取る。

  python3 -I probe/linuc-packages-seq.py [--cols 80 --rows 24] [--chapters 1,2]
      → logs/linuc-packages-deb-tty.log と logs/linuc-packages-rpm-tty.log（--out-dir で置き場所を変えられる）
  python3 -I probe/linuc-packages-seq.py --script 入力.txt --cage deb|rpm --out 記録.log
      → 本文ではなく、同じ書き方の入力ファイルを檻で打つ（探るとき・課題文の画面を取るとき）。
        入力ファイルは「========== 題 ==========」の行で区切り、区切りごとに檻を起動し直す
  python3 -I probe/linuc-packages-seqcompare.py      → 本文の組と突き合わせる

読者は docker run -it の端末で打つ。端末の有無で出力が変わるコマンド（apt の WARNING・進み具合の表示、
ls の段組み、dpkg -l のページャ、apt の [Y/n] の問い）があるので、本文の $ 行を本文の順に機械的に取り出し、
読者と同じ起動の檻に、端末つきで打ち込んだ記録を取る（考え方は probe/linuc-text-seq.py と同じ。2026-10-13 に始め、
2026-10-20 の作り直しで、続きの行と問いへの答えを足した）。

- 檻は章ごとに起動し直す（本文の前提「檻を起動し直した直後」）。第1〜8章は Debian 系、第9〜11章は RPM 系。
  章の中で檻を変えるときは <pre data-cage="rpm"> のように印を付ける。
- 起動は読者の起動コマンドと同じ docker run --rm -it --hostname linuc。ボリュームは名前を付けない2つ
  （/home/lab/work と /home/lab/.lab。--rm でコンテナと一緒に消える）。
- 端末は tmux（専用のソケット・設定ファイルを読まない・ステータス行なし）。幅 80 × 高さ 24 が既定。
  tmux は端末として画面を描くので、記録は「読者の画面に最後に残るもの」になる（\\r で書き換えられる行は
  最後の形、apt の最下行の進み具合は消えたあと、幅を超える行は折り返しをつないだ1行）。
- 記録のための操作は1つだけ: 最初に PROMPT_COMMAND で PS1 を "$ "（＋端末の題名に通し番号）にする。
  題名の番号が変わったら、コマンドが終わってプロンプトに戻ったと分かる。行頭に空白を置くので履歴には残らない。

本文から作る入力（手で足したものは無い）:
  "$ コマンド"                               → そのまま打つ
  "> 続き"                                   → ヒアドキュメントなどの続きの行として打つ（続きのプロンプト "> " が出てから）
  "（打鍵: q）"                              → コマンドがまだ動いていれば（ページャの (END) など）、そのキーを送る
  "Do you want to continue? [Y/n] y" などの行 → その問いが画面のカーソルの行に出るのを待って、行末の答えと Enter を送る
                                               （答えの無い行は Enter だけ）。問いの形は ASK に並べたものだけ
探るとき（--script）にだけ使う入力:
  "（画面を写す）"                           → コマンドを打って 4 秒待ち、そのときの画面（全行）を記録に残す。
                                               画面いっぱいに描く対話（dpkg-reconfigure の選ぶ画面など）は、終わると
                                               消えるので、終わったあとの記録には残らない。それを残すため
  "（打鍵: <Enter> <Enter>）"                → <名前> は文字ではなく、tmux のキーの名前として送る

- プロンプトに戻らないコマンド（ページャの (END) や、答えていない問いで止まるなど）は、画面の最下行を記録に残してから
  q と Enter を送る（それでも戻らなければ、外から pts/0 の一番新しいプロセスを止める）。突き合わせはこれを違いとして数える。
"""
import argparse, html, re, subprocess, sys, time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
THEORY = REPO / "public" / "linuc-packages" / "theory"
IMG = {"deb": "lab-linuc-packages-deb:1.1.0", "rpm": "lab-linuc-packages-rpm:1.1.0"}
CAGE_OF = lambda n: "deb" if n <= 8 else "rpm"
SOCK = "linuc-packages-seq"
PAGER_BOTTOM = re.compile(r"\(END\)\s*$|^lines \d+-\d+|^:\s*$|^ ?Manual page .* line \d+")
# 答えを待つ問い（本文の出力の行が、この形で終わる部分を含み、後ろに答えが続く）
#   答えが Enter だけの行は、画面では問いの後ろに何も残らない（行末の空白は記録で落ちる）ので、空白は任意にする
ASK = [
    r"Do you want to continue\? \[Y/n\] ?",
    r"Is this ok \[y/N\]: ?",
    r"Geographic area: ?",
    r"Time zone: ?",
    r"\[More\] ?",              # debconf の文字だけの画面（-f teletype）が、一覧が画面に収まらないときに出す
]
ASK_RE = re.compile(r"^(.*?(?:" + "|".join(ASK) + r"))(\S*)$")
STUCK, WARN = [], []


def parse_lines(lines):
    """端末ブロックの行（または入力ファイルの行）から手順を作る: [{"cmd", "cont", "keys", "answers"}]"""
    steps, cur = [], None
    for raw in lines:
        l = re.sub(r"\s{2,}←.*$", "", raw)
        if l.startswith("$ "):
            cur = {"cmd": l[2:], "cont": [], "keys": None, "answers": []}
            steps.append(cur)
        elif cur is None:
            continue
        elif l.startswith("> ") or l == ">":
            cur["cont"].append(l[2:])
        else:
            t = l.rstrip()
            mk = re.fullmatch(r"（打鍵: (.*)）", t.strip())
            ma = ASK_RE.match(t)
            if t.strip() == "（画面を写す）":
                cur["screen"] = True
            elif mk:
                cur["keys"] = mk.group(1)
            elif ma:
                cur["answers"].append((ma.group(1), ma.group(2)))
    return steps


def pages(chapters=None):
    out = []
    for f in sorted(THEORY.glob("[01][0-9]-*.html")):
        n = int(f.name[:2])
        if not chapters or n in chapters:
            out.append((n, f))
    return out


def blocks_of(n, f):
    """章の端末ブロックを本文の順に: [(檻, [手順, ...]), ...]"""
    s = f.read_text(encoding="utf-8")
    res = []
    for m in re.finditer(r"<pre\b([^>]*)><code>([\s\S]*?)</code></pre>", s):
        lines = html.unescape(re.sub(r"<[^>]+>", "", m.group(2))).split("\n")
        if not any(l.startswith("$ ") for l in lines):
            continue
        mc = re.search(r'data-cage="(deb|rpm)"', m.group(1))
        cage = mc.group(1) if mc else CAGE_OF(n)
        res.append((cage, parse_lines(lines)))
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


def cursor_line(t):
    _, _, cy, _ = info(t)
    lines = tm("capture-pane", "-p", "-t", t).split("\n")
    return lines[cy] if 0 <= cy < len(lines) else ""


class Cage:
    def __init__(self, cage, cols, rows, first, tag="", offline=False):
        self.cage, self.name = cage, f"linuc-packages-seq-{cage}{tag}"
        self.sess = f"{cage}{tag}"
        subprocess.run(["docker", "rm", "-f", "-v", self.name], capture_output=True)
        # --offline: ネットにつながっていない読者の代わり。名前を引けなくする（--dns 127.0.0.1）。
        # --network none にしないのは、/etc/hosts から檻の名前 linuc が消えて、sudo のたびに
        # 「unable to resolve host linuc」が出るから（読者の檻は、ネットが無くても docker の既定の網につながっている）
        dns = "--dns 127.0.0.1 " if offline else ""
        run = (f"docker run --rm -it --name {self.name} --hostname linuc {dns}"
               f"-v /home/lab/work -v /home/lab/.lab {IMG[cage]}")
        if first:   # サーバを起こし、設定を決めてから最初のセッションを作る（設定ファイルは読まない）
            tm("-f", "/dev/null", "start-server", ";", "set", "-g", "history-limit", "200000", ";",
               "set", "-g", "status", "off", ";",
               "new-session", "-d", "-s", self.sess, "-x", str(cols), "-y", str(rows), run, check=True)
        else:
            tm("new-session", "-d", "-s", self.sess, "-x", str(cols), "-y", str(rows), run, check=True)
        # 起動の案内が出て、檻のプロンプト（端末の題名 lab@linuc: ~）が出るまで待つ
        end = time.time() + 120
        while time.time() < end:
            title, *_ = info(self.sess)
            if title and "@linuc" in title:
                break
            time.sleep(0.3)
        else:
            raise RuntimeError(f"{cage}: 檻のプロンプトが出ない")
        time.sleep(1.0)
        tm("send-keys", "-t", self.sess, "-l",
           " export PROMPT_COMMAND='__n=$((__n+1)); PS1=\"\\[\\e]0;SEQ$__n\\a\\]\\$ \"'")
        tm("send-keys", "-t", self.sess, "Enter")
        self.wait_title(lambda x: x.startswith("SEQ"), 30)
        time.sleep(0.5)

    def wait_title(self, ok, timeout):
        end = time.time() + timeout
        while time.time() < end:
            title, *_ = info(self.sess)
            if title and ok(title):
                return True
            time.sleep(0.2)
        return False

    def run(self, st):
        """1つの手順を打ち、記録に書く行（"$ cmd" と続きの行のこだまを除いた出力）を返す。"""
        cmd, keys = st["cmd"], st["keys"]
        title0, hs0, cy0, _ = info(self.sess)
        top = hs0 + cy0                       # いまのプロンプトの行（絶対行）
        tm("send-keys", "-t", self.sess, "-l", cmd)
        tm("send-keys", "-t", self.sess, "Enter")
        for c in st["cont"]:                  # 続きの行は、続きのプロンプト "> " が出てから打つ
            end = time.time() + 10
            while time.time() < end and cursor_line(self.sess).rstrip() != ">":
                time.sleep(0.1)
            tm("send-keys", "-t", self.sess, "-l", c)
            tm("send-keys", "-t", self.sess, "Enter")
        done = lambda x: x.startswith("SEQ") and x != title0
        notes = []
        # 「（画面を写す）」: 打ってから 4 秒待ち、そのときの画面を全行写す（全画面の対話は終わると消えるため）
        screen = []
        if st.get("screen"):
            time.sleep(4)
            screen = [l.rstrip() for l in tm("capture-pane", "-p", "-t", self.sess).split("\n")]
            while screen and screen[-1] == "":
                screen.pop()
        # 問いに答える: 本文に書かれた順に、問いが画面のカーソルの行に出るのを待って答える
        for prompt, ans in st["answers"]:
            end, asked = time.time() + 120, False
            while time.time() < end:
                if cursor_line(self.sess).rstrip().endswith(prompt.rstrip()):
                    asked = True
                    break
                if self.wait_title(done, 0.3):
                    break
            if not asked:
                notes.append(f"（問い「{prompt.strip()}」が出なかった）")
                WARN.append(f"{self.sess}: 問いが出ない: {prompt!r} / $ {cmd}")
                break
            time.sleep(0.3)
            if ans:
                tm("send-keys", "-t", self.sess, "-l", ans)
            tm("send-keys", "-t", self.sess, "Enter")
        # 本文の「（打鍵: …）」: 読者が打つキーとして送る。ただし、そのときコマンドがまだ動いているときだけ
        # （幅の広い端末では dpkg -l のページャが止まらずに閉じる。そこへ q を送るとシェルに打ち込んでしまう）
        if keys and not self.wait_title(done, 2.0):
            for k in keys.split(" "):
                mk = re.fullmatch(r"<(\w+)>", k)
                if mk:                         # <Enter> などは tmux のキーの名前として送る
                    tm("send-keys", "-t", self.sess, mk.group(1))
                    time.sleep(1.5)
                else:
                    tm("send-keys", "-t", self.sess, "-l", k)
                    time.sleep(0.5)
        elif keys:
            notes.append("（打鍵は要らなかった。コマンドはすぐプロンプトに戻った）")
        end, finished = time.time() + 300, False
        while time.time() < end:
            if self.wait_title(done, 3):
                finished = True
                break
            bl = bottom_line(self.sess)
            if PAGER_BOTTOM.search(bl) or ASK_RE.match(cursor_line(self.sess).rstrip() + " x"):
                notes.append(f"（プロンプトに戻らなかった。最下行: {bl.strip()}）")
                STUCK.append(f"{self.sess}: $ {cmd}")
                tm("send-keys", "-t", self.sess, "q")
                tm("send-keys", "-t", self.sess, "Enter")
                finished = self.wait_title(done, 15)
                break
        if not finished:
            notes.append("（プロンプトに戻らなかった。外から止めて続けた）")
            STUCK.append(f"{self.sess}: $ {cmd}")
            subprocess.run(["docker", "exec", self.name, "pkill", "-KILL", "-n", "-t", "pts/0"],
                           capture_output=True)
            if not self.wait_title(done, 30):
                raise RuntimeError(f"{self.sess}: 止まったまま戻らない: {cmd}")
        time.sleep(0.3)
        title1, hs1, cy1, _ = info(self.sess)
        bot = hs1 + cy1                       # 次のプロンプトの行
        text = tm("capture-pane", "-p", "-J", "-t", self.sess,
                  "-S", str(top - hs1), "-E", str(bot - hs1))
        # タブは画面では空白になる（ls の段組み）。読者が見るとおり、8 桁ごとの空白に戻す
        lines = [l.expandtabs(8).rstrip() for l in text.split("\n")]
        while lines and lines[-1] == "":
            lines.pop()
        # 最後の行は次のプロンプト（"$ "）。出力が改行で終わっていなければ、その前に出力が続いている
        if lines and lines[-1].endswith("$"):
            rest = lines[-1][:-1].rstrip()
            lines = lines[:-1] + ([rest] if rest else [])
        echo = ["$ " + cmd] + ["> " + c for c in st["cont"]]
        k = 0
        while k < len(echo) and k < len(lines) and lines[k].rstrip() == echo[k].rstrip():
            k += 1
        if k < len(echo):
            WARN.append(f"{self.sess}: こだまが合わない: {cmd!r} / 画面 {lines[:len(echo)]!r}")
        body = lines[k:]
        if keys:
            body = [f"（打鍵: {keys}）"] + body
        if screen:
            body = ["（画面: 打ってから 4 秒後の画面。ここから）"] + screen + ["（画面: ここまで）"] + body
        return body + notes

    def alive(self):
        r = subprocess.run(["tmux", "-u", "-L", SOCK, "has-session", "-t", self.sess], capture_output=True)
        return r.returncode == 0 and info(self.sess)[3] != "1"

    def close(self):
        for _ in range(3):                    # PID 1 のシェルを exit で抜ける（檻ごと消える）
            if not self.alive():
                break
            tm("send-keys", "-t", self.sess, "-l", "exit")
            tm("send-keys", "-t", self.sess, "Enter")
            time.sleep(1.5)
        tm("kill-session", "-t", self.sess)
        # --rm の自動削除を待たずに消す場合も、名前の無いボリュームを -v で一緒に消す
        subprocess.run(["docker", "rm", "-f", "-v", self.name], capture_output=True)


def head(cage, a, src):
    return [
        "# 本文の端末ブロックから機械的に作った入力を、読者と同じ起動（docker run --rm -it --hostname linuc、",
        "# 名前の無いボリューム2つ、PID 1 の bash -l、umask 022、TERM=xterm）の檻に、章ごとに起動し直して打った記録。",
        f"# 端末 {a.cols} 桁 × {a.rows} 行（tmux）。画面に最後に残ったものを書く。"
        f"作り方: python3 -I probe/linuc-packages-seq.py{src}（イメージ {IMG[cage]}）"] + (
        ["# ネットにつながっていない読者の代わりに、名前を引けない檻（docker run に --dns 127.0.0.1 を足した）で打った。"]
        if getattr(a, "offline", False) else [])


def record(steps, cage_obj, log):
    n = 0
    for st in steps:
        body = cage_obj.run(st)
        log.append(f"\n$ {st['cmd']}")
        log.extend("> " + c for c in st["cont"])
        log.extend(body)
        n += 1
        print(f"\r{cage_obj.sess} {n} コマンド", end="", file=sys.stderr, flush=True)
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cols", type=int, default=80)
    ap.add_argument("--rows", type=int, default=24)
    ap.add_argument("--chapters", default="")
    ap.add_argument("--out-dir", default=str(REPO / "logs"))
    ap.add_argument("--script", help="本文の代わりに打つ入力ファイル（同じ書き方。========== 行で檻を起動し直す）")
    ap.add_argument("--cage", choices=["deb", "rpm"], default="deb")
    ap.add_argument("--out", help="--script のときの記録の置き場所")
    ap.add_argument("--note", default="", help="--script のときに記録の頭に足す説明（1行）")
    ap.add_argument("--offline", action="store_true", help="--script のとき、名前を引けない檻（ネットの無い読者の代わり）で打つ")
    a = ap.parse_args()
    tm("kill-server")
    n = 0
    if a.script:
        out = Path(a.out or (REPO / "logs" / f"linuc-packages-{a.cage}-script.log"))
        log = head(a.cage, a, f" --script {a.script} --cage {a.cage}" + (" --offline" if a.offline else ""))
        if a.note:
            log.append(f"# {a.note}")
        parts, cur = [], ["========== はじめ ==========", []]
        for l in Path(a.script).read_text(encoding="utf-8").split("\n"):
            if re.fullmatch(r"={10} .* ={10}", l.strip()):
                parts.append(cur)
                cur = [l.strip(), []]
            else:
                cur[1].append(l)
        parts.append(cur)
        first = True
        try:
            for title, lines in parts:
                steps = parse_lines(lines)
                if not steps:
                    continue
                c = Cage(a.cage, a.cols, a.rows, first, tag="-script", offline=a.offline)
                first = False
                log.append(f"\n\n{title}")
                try:
                    n += record(steps, c, log)
                finally:
                    c.close()
        finally:
            tm("kill-server")
            out.write_text("\n".join(log) + "\n", encoding="utf-8")
        print(f"\n→ {out}（{n} コマンド）", file=sys.stderr)
    else:
        chapters = {int(x) for x in a.chapters.split(",") if x.strip()} or None
        outdir = Path(a.out_dir)
        logs = {"deb": head("deb", a, ""), "rpm": head("rpm", a, "")}
        first = True
        try:
            for ch, f in pages(chapters):
                cages = {}
                try:
                    for cage, steps in blocks_of(ch, f):
                        if cage not in cages:
                            cages[cage] = Cage(cage, a.cols, a.rows, first)
                            first = False
                            logs[cage].append(f"\n\n========== {ch}. {f.name} ==========")
                        n += record(steps, cages[cage], logs[cage])
                finally:
                    for c in cages.values():
                        c.close()
        finally:
            tm("kill-server")
            for cage in ("deb", "rpm"):
                if chapters and not any(CAGE_OF(c) == cage for c in chapters):
                    continue
                p = outdir / f"linuc-packages-{cage}-tty.log"
                p.write_text("\n".join(logs[cage]) + "\n", encoding="utf-8")
        print(f"\n→ {outdir}/linuc-packages-{{deb,rpm}}-tty.log（{n} コマンド）", file=sys.stderr)
    for w in STUCK:
        print("止まった: " + w, file=sys.stderr)
    for w in WARN:
        print("注意: " + w, file=sys.stderr)


if __name__ == "__main__":
    main()
