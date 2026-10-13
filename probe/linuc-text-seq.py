#!/usr/bin/env python3
"""LinuC 主題1.03: 本文を、読者と同じ起動・同じ打ち方で第1章から第10章まで通して打った記録を取る。

  bash probe/linuc-text-run.sh seq          → 80 桁と 200 桁で通しを取り、章を作り直し（@@seq）、本文と突き合わせる
  python3 -I probe/linuc-text-seq.py [--cols 80 --rows 24 --out logs/linuc-text-seq.log]   通しを1回取るだけ
  python3 -I probe/linuc-text-seqcompare.py [記録 ...]                                       突き合わせるだけ

本文の記録（probe）は章ごとに新しいコンテナで取っている。読者は docker run の PID 1 の bash -l の中で、
章をまたいで同じシェルのまま打つ（PID 1 で exit するとコンテナごと消える）。そこで、本文の端末ブロックに
出てくる「読者が打つもの」を本文の順に機械的に作り、読者と同じ起動の1つのシェルへ打ち込む（2026-10-13）。

起動は読者の起動コマンドそのもの（docker run --rm -it --hostname linuc、ボリューム2つ）を、ホストの
疑似端末（pty）の上で走らせる。だから端末あり・PID 1 は bash -l・umask 022・TERM=xterm が読者と同じになる。
ボリュームは名前を付けない（--rm でコンテナと一緒に消える）。

本文から作る入力（手で足したものは無い）:
  "$ コマンド"             → そのまま打つ（行頭の空白も含めて）
  "> 続き"                 → ヒアドキュメントの続きの行として打つ
  "（打鍵: …）"            → 直前のコマンド（vim / nano）が開いた画面に、キーを1つずつ送る
  "Choose 1-2 [1]: 2"      → select-editor の問いが出るのを待って 2 と答える
  "echo a?...y"            → xargs -p の問いが出るのを待って y と答える
記録のための操作は1つだけ: 最初に PROMPT_COMMAND で PS1 を "$ "（＋端末の題名に印）にする。
本文のプロンプトの約束に合わせるためと、コマンドの終わり（次のプロンプト）を確実に見つけるため。
行頭に空白を置いて打つので、履歴には残らない（HISTCONTROL=ignoreboth）。

端末の幅は既定で 80 桁 × 24 行（--cols / --rows で変えられる）。ls の段組みや man の折り返しは端末の幅で
変わるので、幅を変えて2回取り、どちらも本文と同じになることを確かめる（--out で別の場所に書く）。

プロンプトに戻らないコマンド（端末の入力を待って止まるもの）は、30 秒待ってから外から止め（docker exec で
pts/0 の一番新しいプロセスに SIGKILL）、記録に「プロンプトに戻らなかった」と残して先へ進む。読者の端末では
止まって見えるので、突き合わせ（seqcompare）はこれを違いとして数える。最初の通しで第10章の vim -es が
これに当たった（-c q が E37 で断られ、端末から次の命令を待つ）。
"""
import argparse, html, os, pty, re, select, subprocess, sys, time, fcntl, termios, struct
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PAGES = sorted((REPO / "public" / "linuc-text" / "theory").glob("[01][0-9]-*.html"))
IMG = "lab-linuc-text:1.0.1"
NAME = "linuc-text-seq"              # 実際の名前は幅を付けて linuc-text-seq-80 など
OUT = REPO / "logs" / "linuc-text-seq.log"
MARK = b"\x1b]0;SEQ\x07$ "          # PS1 の先頭に入れる見えない印（端末の題名）＋ "$ "
CTRL = {"^K": "\x0b", "^O": "\x0f", "^X": "\x18", "^W": "\x17"}


def steps_from_pages():
    steps = []
    for f in PAGES:
        s = f.read_text(encoding="utf-8")
        steps.append({"kind": "chapter", "name": f"{int(f.name[:2])}. {f.name}"})
        for m in re.finditer(r"<pre\b[^>]*><code>([\s\S]*?)</code></pre>", s):
            lines = html.unescape(re.sub(r"<[^>]+>", "", m.group(1))).split("\n")
            if not any(l.startswith("$ ") for l in lines):
                continue
            cur = None
            for raw in lines:
                l = re.sub(r"\s{2,}←.*$", "", raw)
                if l.startswith("$ "):
                    cur = {"kind": "cmd", "cmd": l[2:], "cont": [], "keys": None, "answers": [], "chap": f.name}
                    steps.append(cur)
                elif cur is None:
                    continue
                elif l.startswith("> "):
                    cur["cont"].append(l[2:])
                else:
                    t = l.strip()
                    mk = re.fullmatch(r"（打鍵: (.*)）", t)
                    ma = re.fullmatch(r"(Choose \d+-\d+ \[\d+\]: )(\S+)", t)
                    mx = re.fullmatch(r"(.*\?\.\.\.)(\S+)", t)
                    if mk:
                        cur["keys"] = mk.group(1)
                    elif ma and "editor" in cur["cmd"]:
                        cur["answers"].append((ma.group(1), ma.group(2)))
                    elif mx and re.search(r"\bxargs\b.*\s-p\b", cur["cmd"]):
                        cur["answers"].append((mx.group(1), mx.group(2)))
    return steps


def keystream(show):
    """本文の「打鍵」の表示を、送るキーの並びに戻す。区切りの空白はキーではない。
    ":" "/" "?" で始まる語は ⏎ までが1つの入力（中の空白はキー）。"""
    toks, out, i = show.split(" "), [], 0
    while i < len(toks):
        t = toks[i]
        if t[:1] in (":", "/", "?") and not t.endswith("⏎"):
            j = i
            while j < len(toks) - 1 and not toks[j].endswith("⏎"):
                j += 1
            t, i = " ".join(toks[i:j + 1]), j
        if t == "ESC":
            out.append("\x1b")
        elif t in CTRL:
            out.append(CTRL[t])
        else:
            out.append(t.replace("⏎", "\r").replace("␣", " "))
        i += 1
    return out


ANSI = re.compile(r"\x1b\][^\x07]*\x07|\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b[()][0-9A-Za-z]|\x1b[=>78]")


WARN = []
STUCK = []


def clean(raw, typed):
    """端末の出力から、打った行のこだま（エコー）を除いて行に分ける。
    typed: 打った行（1行目がコマンド、2行目からは "> " で始まる続きの行として出る）。
    端末の幅を超える行は折り返されて出るので、文字を順に照らして（間の空白・改行は飛ばして）除く。"""
    text = ANSI.sub("", raw.decode("utf-8", "replace")).replace("\r", "")
    i = 0
    for k, tl in enumerate(typed):
        target, j = (tl if k == 0 else "> " + tl), 0
        while j < len(target) and i < len(text):
            if text[i] == target[j]:
                i, j = i + 1, j + 1
            elif text[i] in " \n":
                i += 1
            else:
                break
        if j < len(target):
            WARN.append(f"こだまを照らせなかった: {typed[0]!r}")
            i = text.find("\n") + 1 if "\n" in text else len(text)
            break
        nl = text.find("\n", i)
        i = len(text) if nl < 0 else nl + 1
    lines = text[i:].split("\n")
    while lines and not lines[-1].strip():
        lines.pop()
    return lines


class Stuck(Exception):
    pass


def unstick(t, timeout):
    """プロンプトに戻らないコマンドを、外から止める（読者の端末 pts/0 で一番新しいプロセスに SIGKILL）。
    記録には「止まった」と「外から止めた」を残す。本文を直したあとの通しでは、これが起きないことを確かめる。"""
    subprocess.run(["docker", "exec", NAME, "pkill", "-KILL", "-n", "-t", "pts/0"], capture_output=True)
    raw = t.until(MARK, timeout)[:-len(MARK)]
    return raw


class Term:
    def __init__(self, cols, rows):
        cmd = ["docker", "run", "--rm", "-it", "--name", NAME, "--hostname", "linuc",
               "-v", "/home/lab/work", "-v", "/home/lab/.lab", IMG]
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
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
        """何かが出たあと gap 秒静かになるまで待つ（起動の案内とプロンプトが出きるまで）。"""
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
        raise TimeoutError("起動の案内が終わらない")


def run_step(t, st):
    """本文の1つの組を打ち、記録に書く出力の行を返す。"""
    line = st["cmd"]
    if st["keys"]:                       # vim / nano: 画面は捨て、出たエラーメッセージだけ残す（probe の KEYS と同じ）
        t.send(line + "\r")
        t.drain(1.5)
        for k in keystream(st["keys"]):
            t.send(k)
            t.drain(0.5)
        raw = t.until(MARK, 60)[:-len(MARK)]
        emsg = sorted(set(re.findall(r"E\d{2,3}: [^\x00-\x1f\x7f]*", raw.decode("utf-8", "replace"))))
        return [f"（打鍵: {st['keys']}）"] + emsg
    if st["answers"]:                    # 問いが出るのを待って答える
        t.send(line + "\r")
        raw = b""
        for prompt, ans in st["answers"]:
            raw += t.until(prompt.encode("utf-8"), 30)
            t.drain(0.3)
            t.send(ans + "\r")
        raw += t.until(MARK, 60)[:-len(MARK)]
        return clean(raw, [line])
    t.send(line + "\r")
    for c in st["cont"]:                 # ヒアドキュメントの続きの行
        t.drain(0.4)
        t.send(c + "\r")
    raw = t.until(MARK, 30)[:-len(MARK)]
    return clean(raw, [line] + st["cont"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cols", type=int, default=80)
    ap.add_argument("--rows", type=int, default=24)
    ap.add_argument("--out", default=str(OUT))
    a = ap.parse_args()
    global NAME
    NAME = f"linuc-text-seq-{a.cols}"
    out = Path(a.out)
    steps = steps_from_pages()
    subprocess.run(["docker", "rm", "-f", "-v", NAME], capture_output=True)
    t = Term(a.cols, a.rows)
    t.quiet(1.5, 90)
    t.buf = b""
    t.send(" export PROMPT_COMMAND='PS1=\"\\[\\e]0;SEQ\\a\\]\\$ \"'\r")
    t.until(MARK, 20)
    log = ["# 本文の端末ブロックから機械的に作った入力を、読者と同じ起動（docker run --rm -it --hostname linuc、",
           "# ボリューム2つ、PID 1 の bash -l、umask 022、TERM=xterm）の1つのシェルに、第1章から第10章まで通して打った記録。",
           f"# 端末 {a.cols} 桁 × {a.rows} 行。作り方: python3 -I probe/linuc-text-seq.py（イメージ {IMG}）"]
    n = 0
    try:
        for st in steps:
            if st["kind"] == "chapter":
                log.append(f"\n\n========== {st['name']} ==========")
                continue
            n += 1
            line = st["cmd"]
            stuck = False
            try:
                body = run_step(t, st)
            except Stuck:
                stuck = True
                raw = unstick(t, 30)
                body = [f"（打鍵: {st['keys']}）"] if st["keys"] else clean(raw, [line] + st["cont"])
            log.append(f"\n$ {line}")
            for c in st["cont"]:
                log.append(f"> {c}")
            log.extend(body)
            if stuck:
                log.append("（プロンプトに戻らなかった。外から止めて続けた）")
                STUCK.append(f"{st['chap']}: $ {line}")
            print(f"\r{n} コマンド", end="", file=sys.stderr, flush=True)
    finally:
        out.write_text("\n".join(log) + "\n", encoding="utf-8")
        # 終わる（入れ子のシェルが残っていても抜けきる）。抜けきらなければ自分のコンテナを消す
        for _ in range(4):
            try:
                t.send("exit\r")
            except OSError:
                break
            t.drain(1.0)
        reaped, end = False, time.time() + 20
        while not reaped and time.time() < end:
            try:
                reaped = os.waitpid(t.pid, os.WNOHANG)[0] != 0
            except ChildProcessError:
                reaped = True
            if not reaped:
                time.sleep(0.5)
        if not reaped:
            # --rm の自動削除を待たずに消すので、名前の無いボリュームも -v で一緒に消す
            # （-v を付けずに消した最初の通しで、名前の無いボリュームが2つ残った。2026-10-13）
            subprocess.run(["docker", "rm", "-f", "-v", NAME], capture_output=True)
            try:
                os.waitpid(t.pid, 0)
            except ChildProcessError:
                pass
    for w in STUCK:
        print("\n止まった: " + w, file=sys.stderr)
    for w in WARN:
        print("\n注意: " + w, file=sys.stderr)
    print(f"\n→ {out}（{n} コマンド）", file=sys.stderr)


if __name__ == "__main__":
    main()
