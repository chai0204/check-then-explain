#!/usr/bin/env python3
"""LinuC 主題1.09: 本文を、読者と同じ起動・同じ入り方（端末つき）で第1章から第7章まで通して打った記録を取る。

  python3 -I probe/linuc-services-seq.py [--cols 80 --rows 24 --out logs/linuc-services-tty.log]
  python3 -I probe/linuc-services-seqcompare.py [記録 ...]      突き合わせるだけ

本文の記録（probe/linuc-services-probe.sh）は `docker exec … bash -l /tmp/probe.sh` で取っていて、端末が無い。
読者は `docker exec -it lab-linuc bash -l` で端末つきのシェルに入って打つ。端末の有無で表示が変わるコマンドがある
（ls は横に並べる、systemd の道具は幅で切る・pager を使う、apt は進み具合を出す）。そこで、本文の端末ブロックに
出てくる「読者が打つもの」を本文の順に機械的に作り、読者と同じ起動・同じ入り方の1つのシェルへ打ち込む（2026-10-13）。
作りは probe/linuc-text-seq.py（主題1.03）にならった。違いは次のとおり。

  起動: 入口の docker run（-d -t --hostname linuc --cap-add SYS_ADMIN、/root/.lab にボリューム）で起動し、
        systemd が running になってから、ホストの疑似端末（pty）の上で `docker exec -it <名前> bash -l` で入る。
        だから端末あり・root の login シェル・umask 0000（docker exec）・TERM=xterm が読者と同じになる。
        ボリュームは名前を付けない（終わったら docker rm -f -v でコンテナと一緒に消す）。
  間合い: logger・mail・再起動の結果はデーモンが非同期に書く。読者は手で打つので次の行まで必ず数秒空く。
        本文の記録（probe）と同じく、その間だけ待つ（WAITS）。コマンドは足していない。
  画面: 出力の \\r（行頭へ戻る）と ESC[K（行末まで消す）を端末と同じように解釈して、最後に見える行にする
        （apt-get update の進み具合の表示など）。色などのほかの制御文字は捨てる。

本文から作る入力（手で足したものは無い）:
  "$ コマンド" → そのまま打つ / "> 続き" → 複数行のコマンドの続きの行として打つ
記録のための操作は1つだけ: 最初に PROMPT_COMMAND で PS1 を "$ "（＋端末の題名に印）にする。
本文のプロンプトの約束に合わせるためと、コマンドの終わり（次のプロンプト）を確実に見つけるため。
行頭に空白を置いて打つので、履歴には残らない（Ubuntu の root の .bashrc は HISTCONTROL=ignoreboth）。

端末の幅は既定で 80 桁 × 24 行（--cols / --rows で変えられる）。幅で変わる出力を見つけるために、
幅を変えてもう1回取る（--out で別の場所に書く）。

プロンプトに戻らないコマンド（pager が開いたままなど）は、60 秒待ってから読者と同じく q を打って抜け、それでも
戻らなければ外から止め（docker exec で、読者のシェルの端末で一番新しいプロセスに SIGKILL）、記録に
「プロンプトに戻らなかった」と残して先へ進む。
読者の端末では止まって見えるので、突き合わせ（seqcompare）はこれを違いとして数える。
"""
import argparse, html, os, pty, re, select, subprocess, sys, time, fcntl, termios, struct
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PAGES = sorted((REPO / "public" / "linuc-services" / "theory").glob("0[1-9]-*.html"))
IMG = "lab-linuc-services:1.0.2"     # 公開名 ghcr.io/chai0204/lab-linuc-services:1.0.2（push 済みのものと同じイメージ）
NAME = "linuc-services-tty"          # 実際の名前は幅を付けて linuc-services-tty-80 など
OUT = REPO / "logs" / "linuc-services-tty.log"
MARK = b"\x1b]0;SEQ\x07$ "          # PS1 の先頭に入れる見えない印（端末の題名）＋ "$ "
TTY = "pts/1"                        # 読者のシェルの端末（起動後に tty で確かめて置き換える）

# 打った後の間合い（秒）。probe/linuc-services-probe.sh の W と同じ考え方で、少し長めに取る。
WAITS = [
    (re.compile(r"invalid\.example"), 6.0),          # 届かない宛先: 差し戻しが root に届くまで
    (re.compile(r"\|\s*mail\b"), 4.0),               # メールを1通送った
    (re.compile(r"^for "), 3.0),                     # logger を60行投げてから切る
    (re.compile(r"\blogger\b"), 1.5),
    (re.compile(r"\bsystemctl restart\b"), 1.5),
    (re.compile(r"\bchronyc makestep\b"), 1.5),
    (re.compile(r"\bnewaliases\b"), 1.0),
]
BASE_WAIT = 0.6                      # 読者が次の行を打つまでの最小の間


def steps_from_pages():
    steps = []
    for f in PAGES:
        s = f.read_text(encoding="utf-8")
        if not re.search(r'<body[^>]*data-ch="\d+"', s):
            continue
        steps.append({"kind": "chapter", "name": f"{int(f.name[:2])}. {f.name}"})
        for m in re.finditer(r"<pre\b[^>]*><code>([\s\S]*?)</code></pre>", s):
            lines = html.unescape(re.sub(r"<[^>]+>", "", m.group(1))).split("\n")
            if not any(l.startswith("$ ") for l in lines):
                continue
            cur = None
            for raw in lines:
                l = re.sub(r"\s{2,}←.*$", "", raw)
                if l.startswith("$ "):
                    cur = {"kind": "cmd", "cmd": l[2:], "cont": [], "chap": f.name}
                    steps.append(cur)
                elif cur is not None and l.startswith("> "):
                    cur["cont"].append(l[2:])
    return steps


ANSI = re.compile(r"\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\x1b\[[0-9;?<=>]*[ -/]*[@-~]|\x1b[()][0-9A-Za-z]|\x1b[=>78DEHMc]")
CSI = re.compile(r"\x1b\[([0-9;?<=>]*)[ -/]*([@-~])")

WARN = []
STUCK = []


def strip_echo(text, typed):
    """端末の出力の先頭にある、打った行のこだま（エコー）を除く。
    typed: 打った行（1行目がコマンド、2行目からは "> " の後に出る続きの行）。
    端末の幅を超える行は折り返されて出るので、制御文字・\\r・改行・余分な空白は飛ばして文字を順に照らす。"""
    i = 0
    for k, tl in enumerate(typed):
        target, j = (tl if k == 0 else "> " + tl), 0
        while j < len(target) and i < len(text):
            m = ANSI.match(text, i)
            if m:
                i = m.end()
                continue
            ch = text[i]
            if ch == target[j]:
                i, j = i + 1, j + 1
            elif ch in " \r\n\b":
                i += 1
            else:
                break
        if j < len(target):
            WARN.append(f"こだまを照らせなかった: {typed[0]!r}")
            nl = text.find("\n")
            return text[nl + 1:] if nl >= 0 else ""
        nl = text.find("\n", i)
        i = len(text) if nl < 0 else nl + 1
    return text[i:]


def render(text):
    """端末に出た文字の並びを、最後に画面に見える行にする。
    \\r は行頭へ戻る、ESC[K は行末まで消す、ESC[nG・ESC[nC・ESC[nD は横に動く。ほかの制御は捨てる。"""
    lines, cur, col, i = [], [], 0, 0
    while i < len(text):
        c = text[i]
        if c == "\x1b":
            m = CSI.match(text, i)
            if m:
                p, f = m.group(1), m.group(2)
                n = int(p) if p.isdigit() else None
                if f == "K":
                    if p in ("", "0"):
                        del cur[col:]
                    elif p == "1":
                        for x in range(min(col, len(cur))):
                            cur[x] = " "
                    elif p == "2":
                        cur = [" "] * min(col, len(cur))
                elif f == "G":
                    col = max(0, (n or 1) - 1)
                elif f == "C":
                    col += n or 1
                elif f == "D":
                    col = max(0, col - (n or 1))
                i = m.end()
                continue
            m = ANSI.match(text, i)
            i = m.end() if m else i + 1
            continue
        if c == "\r":
            col = 0
        elif c == "\n":
            lines.append("".join(cur).rstrip())
            cur, col = [], 0
        elif c == "\b":
            col = max(0, col - 1)
        elif c == "\t" or ord(c) >= 32:
            if col < len(cur):
                cur[col] = c
            else:
                cur.extend(" " * (col - len(cur)))
                cur.append(c)
            col += 1
        i += 1
    if cur:
        lines.append("".join(cur).rstrip())
    while lines and not lines[-1].strip():
        lines.pop()
    return lines


class Stuck(Exception):
    pass


class Term:
    def __init__(self, cols, rows):
        cmd = ["docker", "exec", "-it", NAME, "bash", "-l"]
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            # 子の側（端末の slave）で、docker が起動時に読む端末の大きさを先に決めておく
            fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
            os.environ["TERM"] = "xterm"
            os.execvp(cmd[0], cmd)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
        self.buf = b""

    def send(self, s):
        os.write(self.fd, s.encode("utf-8"))

    def until(self, pat, timeout):
        end = time.time() + timeout
        while pat not in self.buf:
            if time.time() > end:
                raise Stuck(f"待ちきれなかった: {pat!r}\n最後に見えたもの: {self.buf[-400:]!r}")
            r, _, _ = select.select([self.fd], [], [], 0.2)
            if r:
                try:
                    self.buf += os.read(self.fd, 65536)
                except OSError:
                    break
        i = self.buf.index(pat) + len(pat)
        got, self.buf = self.buf[:i], self.buf[i:]
        return got

    def drain(self, t):
        end = time.time() + t
        while time.time() < end:
            r, _, _ = select.select([self.fd], [], [], 0.2)
            if r:
                try:
                    self.buf += os.read(self.fd, 65536)
                except OSError:
                    return

    def quiet(self, gap, limit):
        """何かが出たあと gap 秒静かになるまで待つ（入ったときの案内とプロンプトが出きるまで）。"""
        end, last = time.time() + limit, None
        while time.time() < end:
            r, _, _ = select.select([self.fd], [], [], 0.1)
            if r:
                try:
                    self.buf += os.read(self.fd, 65536)
                    last = time.time()
                except OSError:
                    return
            elif last and time.time() - last > gap:
                return
        raise TimeoutError("入ったときの案内が終わらない")


def wait_after(line):
    for pat, sec in WAITS:
        if pat.search(line):
            return sec
    return 0.0


def run_step(t, st):
    """本文の1つの組を打ち、記録に書く出力の行を返す。"""
    line = st["cmd"]
    t.send(line + "\r")
    for c in st["cont"]:                 # 複数行のコマンドの続き
        t.drain(0.4)
        t.send(c + "\r")
    raw = t.until(MARK, 60)[:-len(MARK)]
    return render(strip_echo(raw.decode("utf-8", "replace"), [line] + st["cont"]))


def start_cage():
    subprocess.run(["docker", "rm", "-f", "-v", NAME], capture_output=True)
    subprocess.run(["docker", "run", "-d", "-t", "--name", NAME, "--hostname", "linuc",
                    "--cap-add", "SYS_ADMIN", "-v", "/root/.lab", IMG], check=True, capture_output=True)
    for _ in range(90):
        r = subprocess.run(["docker", "exec", NAME, "systemctl", "is-system-running", "--wait"],
                           capture_output=True, text=True)
        if r.stdout.strip() == "running":
            return
        time.sleep(1)
    raise TimeoutError("systemd が running にならない")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cols", type=int, default=80)
    ap.add_argument("--rows", type=int, default=24)
    ap.add_argument("--out", default=str(OUT))
    ap.add_argument("--limit", type=int, default=0, help="試し用: 最初の N コマンドだけ打つ")
    a = ap.parse_args()
    global NAME, TTY
    NAME = f"linuc-services-tty-{a.cols}"
    out = Path(a.out)
    steps = steps_from_pages()
    start_cage()
    t = Term(a.cols, a.rows)
    t.quiet(1.5, 90)
    t.buf = b""
    t.send(" export PROMPT_COMMAND='PS1=\"\\[\\e]0;SEQ\\a\\]$ \"'\r")
    t.until(MARK, 20)
    t.send(" tty\r")
    got = render(strip_echo(t.until(MARK, 20)[:-len(MARK)].decode("utf-8", "replace"), [" tty"]))
    if got and got[-1].startswith("/dev/"):
        TTY = got[-1][len("/dev/"):]
    log = ["# 本文の端末ブロックから機械的に作った入力を、読者と同じ起動（docker run -d -t --hostname linuc",
           "# --cap-add SYS_ADMIN、/root/.lab にボリューム）と同じ入り方（docker exec -it … bash -l。端末あり・root・",
           "# umask 0000・TERM=xterm）の1つのシェルに、第1章から第7章まで通して打った記録。",
           f"# 端末 {a.cols} 桁 × {a.rows} 行。作り方: python3 -I probe/linuc-services-seq.py（イメージ {IMG}）"]
    n = 0
    try:
        for st in steps:
            if st["kind"] == "chapter":
                log.append(f"\n\n========== {st['name']} ==========")
                continue
            if a.limit and n >= a.limit:
                break
            n += 1
            line = st["cmd"]
            stuck = False
            time.sleep(BASE_WAIT)
            try:
                body = run_step(t, st)
            except Stuck:
                # 読者なら pager（less）を q で抜ける。まず同じことをして、それでも戻らなければ外から止める
                stuck = True
                pending = t.buf
                t.buf = b""
                t.send("q")
                try:
                    raw = pending + t.until(MARK, 10)
                except Stuck:
                    subprocess.run(["docker", "exec", NAME, "pkill", "-KILL", "-n", "-t", TTY], capture_output=True)
                    raw = pending + t.until(MARK, 30)
                raw = raw[:-len(MARK)]
                body = render(strip_echo(raw.decode("utf-8", "replace"), [line] + st["cont"]))
            log.append(f"\n$ {line}")
            for c in st["cont"]:
                log.append(f"> {c}")
            log.extend(body)
            if stuck:
                log.append("（プロンプトに戻らなかった。外から止めて続けた）")
                STUCK.append(f"{st['chap']}: $ {line}")
            w = wait_after(line)
            if w:
                time.sleep(w)
            print(f"\r{n} コマンド", end="", file=sys.stderr, flush=True)
    finally:
        out.write_text("\n".join(log) + "\n", encoding="utf-8")
        try:
            t.send("exit\r")
        except OSError:
            pass
        t.drain(1.0)
        subprocess.run(["docker", "rm", "-f", "-v", NAME], capture_output=True)
        try:
            os.waitpid(t.pid, 0)
        except ChildProcessError:
            pass
    for w in STUCK:
        print("\n止まった: " + w, file=sys.stderr)
    for w in WARN:
        print("\n注意: " + w, file=sys.stderr)
    print(f"\n→ {out}（{n} コマンド、読者の端末 /dev/{TTY}）", file=sys.stderr)


if __name__ == "__main__":
    main()
