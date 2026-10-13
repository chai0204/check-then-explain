#!/usr/bin/env python3
"""docker / podman の記事: 本文の端末ブロックから読者の入力を機械的に作り、読者と同じ起動・同じ入り方の
1つのシェルに、第1章から最後の章まで通して打った記録を取る（本文の端末表示の出どころ）。

  python3 -I probe/docker-seq.py --slug docker                     章のひな形（probe/docker-tpl/）から打って記録を取る
  python3 -I probe/docker-seq.py --slug docker --src pages --out X  公開する本文（public/docker/theory/）から打つ（突き合わせ用）
  python3 -I probe/docker-seq.py --slug podman …                    podman の記事も同じ（檻は lab-podman）

読者と同じにしているもの（tools-brief §1.1）:
  起動  : 入口の docker run と同じオプション（-d --hostname host --stop-timeout 30、/home/lab/vm と /home/lab/.lab に
          ボリューム）。ボリュームは名前を付けない（終わったら docker rm -f -v でコンテナと一緒に消える）。
          練習機が起動し、初回の準備（provision.sh）が終わるまで待ってから入る（本文の入口もそれを待たせる）。
  入り方: ホストの疑似端末（pty、80 桁 × 24 行、TERM=xterm）の上で `docker exec -it <名前> bash -l` で外に入り、
          そこで `ssh linuc` と打って練習機の対話のログインシェルに入る。以後、第1章から最後の章まで、
          その1つのシェルに続けて打つ（章の間で exit しない）。umask・TERM・alias・作ったファイル・動かしたプロセスは、
          読者と同じく章をまたいで持ち越される。
  画面  : 出力の \\r（行頭へ戻る）・ESC[K（行末まで消す）・カーソルの上下左右を端末と同じように解釈して、
          最後に見える行にする（進み具合の表示は書き換えられた後の姿が残る）。色などのほかの制御文字は捨てる。

本文（またはひな形）から作る入力（手で足したものは無い）:
  "$ コマンド"（ひな形では "@@ コマンド"）→ そのまま打つ / "> 続き" → 複数行のコマンドの続きの行として打つ
記録のための操作は、練習機に入った直後の1つだけ: PROMPT_COMMAND で PS1 を "$ "（＋端末の題名に見えない印）にする。
本文のプロンプトの約束に合わせるためと、コマンドの終わり（次のプロンプト）を確実に見つけるため。
行頭に空白を置いて打つので、履歴には残らない（student の ~/.bashrc は HISTCONTROL=ignoreboth）。

プロンプトに戻らないコマンドは、読者と同じく q（pager）→ Ctrl-C を送り、それでも戻らなければ外から止めて、
記録に「プロンプトに戻らなかった」と残す（突き合わせはこれを違いとして数える）。
"""
import argparse, html, os, pty, re, select, subprocess, sys, time, fcntl, termios, struct
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MARK = b"\x1b]0;SEQ\x07$ "          # PS1: 端末の題名に入れる見えない印 + "$ "
PS1_SET = " export PROMPT_COMMAND='PS1=\"\\[\\e]0;SEQ\\a\\]$ \"'"

# 打った後の間合い（秒）。読者は手で打つので、次の行までに必ず数秒空く。その間だけ待つ（コマンドは足していない）。
WAITS = [
    (re.compile(r"\b(docker|podman) (run|start|restart)\b.*\s-d\b|\b(docker|podman) (start|restart)\b"), 1.5),
    (re.compile(r"\bsystemctl (--user )?(start|restart|stop)\b"), 1.5),
]
BASE_WAIT = 0.6
LONG = [(re.compile(r"\b(docker|podman) (build|buildx)\b"), 600), (re.compile(r"\bsleep \d+"), 300)]
DEFAULT_TIMEOUT = 120


def steps_from(slug, src):
    steps = []
    if src == "tpl":
        files = sorted((REPO / "probe" / f"{slug}-tpl").glob("[0-9][0-9]-*.html"))
    else:
        files = sorted((REPO / "public" / slug / "theory").glob("[0-9][0-9]-*.html"))
    for f in files:
        s = f.read_text(encoding="utf-8")
        if not re.search(r'<body[^>]*data-ch="\d+"', s):
            continue
        steps.append({"kind": "chapter", "name": f"{int(f.name[:2])}. {f.name}"})
        for m in re.finditer(r"<pre\b[^>]*><code>([\s\S]*?)</code></pre>", s):
            lines = html.unescape(re.sub(r"<[^>]+>", "", m.group(1))).split("\n")
            cmd_pfx = "@@ " if src == "tpl" else "$ "
            if not any(l.startswith(cmd_pfx) for l in lines):
                continue
            cur = None
            for raw in lines:
                l = re.sub(r"\s{2,}←.*$", "", raw)
                if l.startswith(cmd_pfx):
                    c = l[len(cmd_pfx):]
                    if src == "tpl":
                        c = re.sub(r"\s+##\s.*$", "", c)        # ひな形の指定（## lines=… など）は打たない
                    cur = {"kind": "cmd", "cmd": c, "cont": [], "chap": f.name}
                    steps.append(cur)
                elif cur is not None and (l.startswith("> ") or (src == "tpl" and l.startswith("@@> "))):
                    cur["cont"].append(l[4:] if l.startswith("@@> ") else l[2:])
    return steps


ANSI = re.compile(r"\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\x1b\[[0-9;?<=>]*[ -/]*[@-~]|\x1b[()][0-9A-Za-z]|\x1b[=>78DEHMc]")
CSI = re.compile(r"\x1b\[([0-9;?<=>]*)[ -/]*([@-~])")
WARN, STUCK = [], []


def strip_echo(text, typed):
    """端末の出力の先頭にある、打った行のこだまを除く（折り返し・制御文字は飛ばして文字を順に照らす）。"""
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
    """端末に出た文字の並びを、最後に画面に見える行にする（行の配列とカーソルを持つ小さな端末）。"""
    rows, r, col, i = [[]], 0, 0, 0
    def row():
        while len(rows) <= r:
            rows.append([])
        return rows[r]
    while i < len(text):
        c = text[i]
        if c == "\x1b":
            m = CSI.match(text, i)
            if m:
                p, f = m.group(1), m.group(2)
                n = int(p) if p.isdigit() else None
                cur = row()
                if f == "K":
                    if p in ("", "0"):
                        del cur[col:]
                    elif p == "1":
                        for x in range(min(col, len(cur))):
                            cur[x] = " "
                    elif p == "2":
                        rows[r] = []
                elif f == "G":
                    col = max(0, (n or 1) - 1)
                elif f == "C":
                    col += n or 1
                elif f == "D":
                    col = max(0, col - (n or 1))
                elif f == "A":
                    r = max(0, r - (n or 1))
                elif f == "B":
                    r += n or 1
                elif f == "J" and p in ("", "0"):
                    del cur[col:]
                    del rows[r + 1:]
                i = m.end()
                continue
            m = ANSI.match(text, i)
            i = m.end() if m else i + 1
            continue
        if c == "\r":
            col = 0
        elif c == "\n":
            r += 1
            col = 0
            row()
        elif c == "\b":
            col = max(0, col - 1)
        elif c == "\t" or ord(c) >= 32:
            cur = row()
            if col < len(cur):
                cur[col] = c
            else:
                cur.extend(" " * (col - len(cur)))
                cur.append(c)
            col += 1
        i += 1
    lines = ["".join(x).rstrip() for x in rows]
    while lines and not lines[-1].strip():
        lines.pop()
    return lines


class Stuck(Exception):
    pass


class Term:
    def __init__(self, name, cols, rows):
        cmd = ["docker", "exec", "-it", name, "bash", "-l"]
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
            os.environ["TERM"] = "xterm"
            os.execvp(cmd[0], cmd)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
        self.buf = b""

    def send(self, s):
        os.write(self.fd, s.encode("utf-8") if isinstance(s, str) else s)

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
        k = self.buf.index(pat) + len(pat)
        got, self.buf = self.buf[:k], self.buf[k:]
        return got

    def until_re(self, rx, timeout):
        end = time.time() + timeout
        while not rx.search(self.buf):
            if time.time() > end:
                raise Stuck(f"待ちきれなかった: {rx.pattern!r}\n最後に見えたもの: {self.buf[-400:]!r}")
            r, _, _ = select.select([self.fd], [], [], 0.2)
            if r:
                self.buf += os.read(self.fd, 65536)
        m = rx.search(self.buf)
        got, self.buf = self.buf[:m.end()], self.buf[m.end():]
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


def wait_after(line):
    for pat, sec in WAITS:
        if pat.search(line):
            return sec
    return 0.0


def timeout_for(line):
    for pat, sec in LONG:
        if pat.search(line):
            return sec
    return DEFAULT_TIMEOUT


def sh(*a, **k):
    return subprocess.run(list(a), capture_output=True, text=True, **k)


def start_cage(name, img):
    sh("docker", "rm", "-f", "-v", name)
    r = sh("docker", "run", "-d", "--name", name, "--hostname", "host", "--stop-timeout", "30",
           "-v", "/home/lab/vm", "-v", "/home/lab/.lab", img)
    if r.returncode:
        raise SystemExit(r.stderr)
    t0 = time.time()
    # 練習機の起動 → エージェントと ssh → 初回の準備（あれば）→ systemd が落ち着くまで
    has_prov = sh("docker", "exec", name, "test", "-f", "/etc/lab-vm/provision.sh").returncode == 0
    for _ in range(300):
        st = sh("docker", "exec", name, "vm", "status", "--short").stdout
        ok = "エージェント 応答あり / ssh 待ち受け中" in st
        if ok and has_prov:
            ok = sh("docker", "exec", name, "test", "-f", "/home/lab/vm/.provisioned").returncode == 0
        if ok:
            break
        time.sleep(2)
    else:
        raise TimeoutError("練習機が起動しない")
    sh("docker", "exec", name, "ssh", "linuc", "systemctl is-system-running --wait")
    print(f"練習機の準備まで {time.time() - t0:.0f} 秒", file=sys.stderr)


VM_PROMPT = re.compile(rb"student@linuc:[^\n]*\$ $")


def run_step(t, st, timeout):
    t.send(st["cmd"] + "\r")
    for c in st["cont"]:
        t.drain(0.4)
        t.send(c + "\r")
    if st["cmd"].strip() == "ssh linuc":
        # 練習機に入り直す（本文が外へ出てから戻る章）。入ったばかりのシェルのプロンプトは本物（student@linuc:~$）なので、
        # 最初に入ったときと同じく、記録のための PS1 の設定を1つだけ打つ（行頭の空白で履歴に残らない）
        raw = t.until_re(VM_PROMPT, timeout)
        raw = re.sub(rb"\x1b\]0;[^\x07]*\x07", b"", raw)
        raw = VM_PROMPT.sub(b"", raw)
        t.drain(0.5)
        t.buf = b""
        t.send(PS1_SET + "\r")
        t.until(MARK, 20)
        return render(strip_echo(raw.decode("utf-8", "replace"), [st["cmd"]]))
    raw = t.until(MARK, timeout)[:-len(MARK)]
    return render(strip_echo(raw.decode("utf-8", "replace"), [st["cmd"]] + st["cont"]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--slug", required=True)
    ap.add_argument("--src", choices=["tpl", "pages"], default="tpl")
    ap.add_argument("--img", default=None)
    ap.add_argument("--cols", type=int, default=80)
    ap.add_argument("--rows", type=int, default=24)
    ap.add_argument("--out", default=None)
    ap.add_argument("--limit", type=int, default=0, help="試し用: 最初の N コマンドだけ打つ")
    ap.add_argument("--keep", action="store_true", help="試し用: 終わってもコンテナを消さない")
    ap.add_argument("--entry", default=None, help="入口の画面（外に入ったときの表示と ssh linuc の表示）を書き出す先")
    ap.add_argument("--name", default=None, help="檻のコンテナの名前（既定 <slug>-seq-<桁数>。2本を同時に取るときに分ける）")
    a = ap.parse_args()
    img = a.img or f"lab-{a.slug}:1.0.0"
    name = a.name or f"{a.slug}-seq-{a.cols}"
    out = Path(a.out or REPO / "logs" / f"{a.slug}-seq.log")
    steps = steps_from(a.slug, a.src)
    start_cage(name, img)
    t = Term(name, a.cols, a.rows)
    # 外（lab@host）に入ったときの案内が出きるまで待つ。外のシェルにも記録のための PS1 を入れておく
    # （本文が練習機から exit して外で打つ章があるため。行頭の空白で履歴に残らない）。それから ssh linuc で練習機に入る
    t.drain(3.0)
    outer_login = render(re.sub(r"\x1b\]0;[^\x07]*\x07", "", t.buf.decode("utf-8", "replace")))
    t.buf = b""
    t.send(PS1_SET + "\r")
    t.until(MARK, 20)
    t.send("ssh linuc\r")
    first_ssh = t.until_re(VM_PROMPT, 90)
    first_ssh = VM_PROMPT.sub(b"", re.sub(rb"\x1b\]0;[^\x07]*\x07", b"", first_ssh))
    if a.entry:
        ent = ["# 入口の画面: 読者と同じ起動・同じ入り方（docker exec -it … bash -l。端末 %d 桁 × %d 行）で、" % (a.cols, a.rows),
               "# 外に入ったときに出る表示と、最初の ssh linuc の表示。作り方: python3 -I probe/docker-seq.py --entry",
               "", "========== 外（lab@host）に入ったときの表示 ==========", ""]
        ent += [l for l in outer_login if not l.endswith("$") and "lab@host:" not in l]
        ent += ["", "========== 練習機に入る ==========", "", "$ ssh linuc"]
        ent += render(strip_echo(first_ssh.decode("utf-8", "replace"), ["ssh linuc"]))
        Path(a.entry).write_text("\n".join(ent) + "\n", encoding="utf-8")
    t.drain(1.0)
    t.buf = b""
    t.send(PS1_SET + "\r")
    t.until(MARK, 20)
    t.send(" tty\r")
    got = render(strip_echo(t.until(MARK, 20)[:-len(MARK)].decode("utf-8", "replace"), [" tty"]))
    tty = got[-1][len("/dev/"):] if got and got[-1].startswith("/dev/") else "pts/0"
    log = [f"# 本文の端末ブロックから機械的に作った入力を、読者と同じ起動（docker run -d --hostname host --stop-timeout 30、",
           f"# /home/lab/vm と /home/lab/.lab にボリューム）と同じ入り方（docker exec -it … bash -l → ssh linuc。端末あり・",
           f"# TERM=xterm）の、練習機の中の1つの対話のログインシェルに、第1章から順に通して打った記録。",
           f"# 端末 {a.cols} 桁 × {a.rows} 行。作り方: python3 -I probe/docker-seq.py --slug {a.slug} --src {a.src}（イメージ {img}）"]
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
                body = run_step(t, st, timeout_for(line))
            except Stuck:
                stuck = True
                pending, t.buf = t.buf, b""
                raw = b""
                for key in (b"q", b"\x03"):
                    t.send(key)
                    try:
                        raw = pending + t.until(MARK, 10)
                        break
                    except Stuck:
                        pending, t.buf = pending + t.buf, b""
                else:
                    sh("docker", "exec", name, "ssh", "linuc", f"pkill -KILL -n -t {tty}")
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
            t.drain(1.0)
            t.send("exit\r")
        except OSError:
            pass
        t.drain(1.0)
        if not a.keep:
            sh("docker", "rm", "-f", "-v", name)
        try:
            os.waitpid(t.pid, 0)
        except ChildProcessError:
            pass
    for w in STUCK:
        print("\n止まった: " + w, file=sys.stderr)
    for w in WARN:
        print("\n注意: " + w, file=sys.stderr)
    print(f"\n→ {out}（{n} コマンド、読者の端末 /dev/{tty}）", file=sys.stderr)


if __name__ == "__main__":
    main()
