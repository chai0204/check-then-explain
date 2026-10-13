#!/usr/bin/env python3
"""KVM の記事: 読者と同じ起動・同じ打ち方（端末つき・1つのシェルで第1章から順に）で打った記録を取る。

  python3 -I probe/kvm-seq.py --steps probe/kvm-steps.txt --out logs/kvm-probe.log   台本から（本文の記録の出どころ）
  python3 -I probe/kvm-seq.py --pages --out logs/kvm-seq.log                         本文の端末ブロックから（通しの再現）
  python3 -I probe/kvm-seqcompare.py [記録 ...]                                       本文と突き合わせる

作りは probe/linuc-text-seq.py（主題1.03）と probe/linuc-services-seq.py（主題1.09）にならった。

  起動: 読者の起動コマンド（docker run --rm -it --hostname host、--device /dev/kvm --group-add <GID>）を、
        ホストの疑似端末（pty。既定 80 桁 × 24 行）の上で走らせる。だから端末あり・PID 1 は tini・その子が bash -l・
        umask 022・TERM=xterm が読者と同じになる。ボリュームは名前を付けない（--rm でコンテナと一緒に消える）。
  端末: 1つの檻の中では、第1章から最後まで同じシェルのまま打つ（章の間で exit しない）。練習機には本文と同じく
        `ssh linuc` で入り、`exit` で外へ戻る（同じ端末の中で入れ子になる）。
  檻は3つまで並べて使う（本文の <pre data-where="…"> で決まる）:
        main  … 読者の檻（--device /dev/kvm と --group-add を付けて起動）。既定
        nodev … data-where に「--device なし」とある端末ブロック。--device を付けずに起動した2つ目の檻
        pc    … data-where に「あなたの PC」とある端末ブロック。コンテナの外（このホストの bash）で打つ
        data-where に「Ubuntu」とあるブロックは別の PC（lab の仮想マシン）で取った記録なので、ここでは打たない。
        台本（--steps）では、ほかの名前の檻も使える（@priv など。docker run のオプションは --sess-args 名前=… で渡す）。
  画面: 出力の \\r（行頭へ戻る）と ESC[K（行末まで消す）を端末と同じように解釈して、最後に見える行にする。

本文から作る入力（手で足したものは無い）:
  "$ コマンド" → そのまま打つ / "> 続き" → 複数行のコマンドの続きの行として打つ
記録のための操作は、シェルに入るたびに1つだけ: PROMPT_COMMAND で PS1 を "$ "（＋端末の題名に印）にする。
本文のプロンプトの約束（$）に合わせるためと、コマンドの終わり（次のプロンプト）を確実に見つけるため。
行頭に空白を置いて打つので、履歴には残らない（HISTCONTROL=ignoreboth）。

プロンプトに戻らないコマンドは、待ち時間を過ぎたら外から止め（docker exec で読者の端末の一番新しいプロセスに
SIGKILL）、記録に「プロンプトに戻らなかった」と残して先へ進む。突き合わせ（seqcompare）はこれを違いとして数える。
"""
import argparse, html, os, pty, re, select, subprocess, sys, time, fcntl, termios, struct
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PAGES = sorted((REPO / "public" / "kvm" / "theory").glob("[0-9][0-9]-*.html"))
IMG = "lab-kvm:1.0.0"
MARK = b"\x1b]0;SEQ\x07$ "          # PS1 の先頭に入れる見えない印（端末の題名）＋ "$ "
SETPS = " export PROMPT_COMMAND='PS1=\"\\[\\e]0;SEQ\\a\\]$ \"'"
GUEST_PROMPT = re.compile(rb"student@linuc:~\$ $")
HOST_PROMPT = re.compile(rb"(lab@host:~\$|root@host:\S*#) $")   # root は --user 0 で起動した檻（演習02 の判定の確かめ。作業場所は /home/lab のまま）

# 1つのコマンドを待つ時間（秒）。練習機の起動は TCG で 30〜90 秒かかる
def timeout_for(cmd):
    if re.match(r"qemu-linuc(\s|$)", cmd) and not re.match(r"qemu-linuc (stop|status|reset)", cmd):
        return 420
    if cmd.startswith("qemu-linuc stop") or cmd.startswith("vm stop"):
        return 150
    if cmd.startswith("vm start"):
        return 420
    if cmd.startswith("lab check"):
        return 120
    return 60


ANSI = re.compile(r"\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\x1b\[[0-9;?<=>]*[ -/]*[@-~]|\x1b[()][0-9A-Za-z]|\x1b[=>78DEHMc]")
CSI = re.compile(r"\x1b\[([0-9;?<=>]*)[ -/]*([@-~])")
WARN, STUCK = [], []


def strip_echo(text, typed):
    """端末の出力の先頭にある、打った行のこだま（エコー）を除く（折り返し・制御文字は飛ばして照らす）。"""
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
    """端末に出た文字の並びを、最後に画面に見える行にする（\\r・ESC[K・横の移動を解釈し、ほかの制御は捨てる）。"""
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
    """疑似端末の上で1つのコマンド（docker run -it … / bash）を動かす。"""
    def __init__(self, argv, cols, rows, name=None):
        self.name = name
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
            os.environ["TERM"] = "xterm"
            os.execvp(argv[0], argv)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
        self.buf = b""
        self.in_guest = False

    def send(self, s):
        os.write(self.fd, s.encode("utf-8"))

    def until(self, pat, timeout):
        """pat（bytes か正規表現）が出るまで読み、そこまでを返す。"""
        end = time.time() + timeout
        while True:
            if isinstance(pat, bytes):
                k = self.buf.find(pat)
                if k >= 0:
                    k += len(pat)
                    break
            else:
                m = pat.search(self.buf)
                if m:
                    k = m.end()
                    break
            if time.time() > end:
                raise Stuck(f"待ちきれなかった: {pat!r}\n最後に見えたもの: {self.buf[-400:]!r}")
            r, _, _ = select.select([self.fd], [], [], 0.2)
            if r:
                try:
                    self.buf += os.read(self.fd, 65536)
                except OSError:
                    raise Stuck("端末が閉じた")
        got, self.buf = self.buf[:k], self.buf[k:]
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

    def close(self):
        for _ in range(3):
            try:
                self.send("exit\r")
            except OSError:
                break
            self.drain(1.5)
        if self.name:
            subprocess.run(["docker", "rm", "-f", "-v", self.name], capture_output=True)
        try:
            os.waitpid(self.pid, 0)
        except ChildProcessError:
            pass


def kvm_gid():
    try:
        return str(os.stat("/dev/kvm").st_gid)
    except OSError:
        return None


class Sessions:
    def __init__(self, a, log):
        self.a, self.log, self.t = a, log, {}
        # --sess-args 名前=オプション: main・nodev 以外の檻（台本の @名前）に付ける docker run のオプション
        self.extra = dict(x.split("=", 1) for x in (a.sess_args or []))

    def get(self, sess):
        if sess in self.t:
            return self.t[sess]
        name = f"{self.a.prefix}-{sess}"
        subprocess.run(["docker", "rm", "-f", "-v", name], capture_output=True)
        run = ["docker", "run", "--rm", "-it", "--name", name, "--hostname", "host"]
        if sess == "main":
            if self.a.main_args:
                run += self.a.main_args.split()
            else:
                gid = kvm_gid()
                if gid is not None:
                    run += ["--device", "/dev/kvm", "--group-add", gid]
        elif sess == "nodev" and self.a.nodev_args:
            run += self.a.nodev_args.split()
        elif sess in self.extra:
            run += self.extra[sess].split()
        # 2つ目の檻（nodev）は、本文の起動コマンドと同じくボリュームを付けない（--rm で全部消える）
        if sess == "main":
            run += ["-v", "/home/lab/vm", "-v", "/home/lab/.lab"]
        run += [self.a.image]
        t = Term(run, self.a.cols, self.a.rows, name)
        raw = t.until(HOST_PROMPT, 120)
        banner = render(raw.decode("utf-8", "replace"))
        if banner and re.search(r"(lab@host:~\$|root@host:\S*#)$", banner[-1]):
            banner = banner[:-1]
        self.log.append(f"\n# --- {sess}: 起動（{' '.join(run[2:])}）して入ったときの表示 ---")
        self.log.extend(banner)
        self.log.append("# --- ここまで ---")
        t.send(SETPS + "\r")
        t.until(MARK, 20)
        self.t[sess] = t
        return t

    def close(self, sess):
        t = self.t.pop(sess, None)
        if t:
            if t.in_guest:
                t.send("exit\r")
                t.drain(2)
            t.close()

    def close_all(self):
        for s in list(self.t):
            self.close(s)


def run_step(t, st, sess_name):
    """1つの組を打ち、記録に書く出力の行を返す。"""
    line = st["cmd"]
    t.send(line + "\r")
    for c in st["cont"]:
        t.drain(0.4)
        t.send(c + "\r")
    to = timeout_for(line)
    if line.strip() == "exit" and not t.in_guest:
        # 檻の bash -l を抜ける。--rm の檻はここで終わって消える（端末が閉じるまで読む）
        raw = b""
        end = time.time() + 30
        while time.time() < end:
            r, _, _ = select.select([t.fd], [], [], 0.2)
            if r:
                try:
                    chunk = os.read(t.fd, 65536)
                except OSError:
                    break
                if not chunk:
                    break
                raw += chunk
        t.closed = True
        return render(strip_echo((t.buf + raw).decode("utf-8", "replace"), [line]))
    if re.fullmatch(r"ssh linuc", line.strip()) and not t.in_guest:
        raw = t.until(GUEST_PROMPT, to)
        out = render(strip_echo(raw.decode("utf-8", "replace"), [line] + st["cont"]))
        # 最後の行は練習機のプロンプト（student@linuc:~$）。記録には入れない
        if out and out[-1].rstrip().endswith("student@linuc:~$"):
            out = out[:-1]
        t.in_guest = True
        t.send(SETPS + "\r")
        t.until(MARK, 20)
        return out
    raw = t.until(MARK, to)[:-len(MARK)]
    if line.strip() == "exit" and t.in_guest:
        t.in_guest = False
    return render(strip_echo(raw.decode("utf-8", "replace"), [line] + st["cont"]))


def run_pc(st):
    """コンテナの外（このホスト）で打つ。読むだけのコマンドに限る（本文の「あなたの PC」のブロック）。"""
    cmd = st["cmd"] + "".join("\n" + c for c in st["cont"])
    r = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True)
    out = (r.stdout + r.stderr).rstrip("\n")
    return out.split("\n") if out else []


def where_to_session(where):
    if not where:
        return "main"
    if "Ubuntu" in where:
        return None
    if "あなたの PC" in where:
        return "pc"
    if "--device なし" in where:
        return "nodev"
    return "main"


def steps_from_pages():
    steps = []
    for f in PAGES:
        s = f.read_text(encoding="utf-8")
        if not re.search(r'<body[^>]*data-ch="\d+"', s):
            continue
        steps.append({"kind": "chapter", "name": f"{int(f.name[:2])}. {f.name}"})
        for m in re.finditer(r"<pre\b([^>]*)><code>([\s\S]*?)</code></pre>", s):
            lines = html.unescape(re.sub(r"<[^>]+>", "", m.group(2))).split("\n")
            if not any(l.startswith("$ ") for l in lines):
                continue
            mw = re.search(r'data-where="([^"]*)"', m.group(1))
            sess = where_to_session(html.unescape(mw.group(1)) if mw else "")
            cur = None
            for raw in lines:
                l = re.sub(r"\s{2,}←.*$", "", raw)
                if l.startswith("$ "):
                    cur = {"kind": "cmd", "cmd": l[2:], "cont": [], "chap": f.name, "sess": sess}
                    steps.append(cur)
                elif cur is not None and l.startswith("> "):
                    cur["cont"].append(l[2:])
    return steps


def steps_from_file(path):
    """台本の形: "== 題 ==" 節の見出し / "@main" "@nodev" "@pc" 打つ場所 / "@close nodev" 檻を閉じる /
    "$ コマンド" / "> 続き" / "#" で始まる行は注釈（記録にも残す）/ "@sleep N" 人が次を打つまでの間（記録しない）"""
    steps, sess, cur = [], "main", None
    for raw in Path(path).read_text(encoding="utf-8").split("\n"):
        if raw.startswith("== ") and raw.endswith(" =="):
            steps.append({"kind": "chapter", "name": raw[3:-3]})
            cur = None
        elif raw.startswith("@close "):
            steps.append({"kind": "close", "sess": raw[7:].strip()})
            cur = None
        elif raw.startswith("@sleep "):
            steps.append({"kind": "sleep", "sec": float(raw[7:])})
            cur = None
        elif raw.startswith("@"):
            sess = raw[1:].strip()
            cur = None
        elif raw.startswith("$ "):
            cur = {"kind": "cmd", "cmd": raw[2:], "cont": [], "chap": "台本", "sess": sess}
            steps.append(cur)
        elif raw.startswith("> ") and cur is not None:
            cur["cont"].append(raw[2:])
        elif raw.startswith("# "):
            steps.append({"kind": "note", "text": raw[2:]})
            cur = None
    return steps


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cols", type=int, default=80)
    ap.add_argument("--rows", type=int, default=24)
    ap.add_argument("--out", required=True)
    ap.add_argument("--steps")
    ap.add_argument("--pages", action="store_true")
    ap.add_argument("--image", default=IMG)
    ap.add_argument("--main-args", default="", help="main の檻に付ける docker run のオプション（既定は --device /dev/kvm --group-add <GID>）")
    ap.add_argument("--nodev-args", default="")
    ap.add_argument("--sess-args", action="append", metavar="名前=オプション",
                    help="台本の @名前 の檻に付ける docker run のオプション（ボリュームは付けない）。何度でも")
    ap.add_argument("--title", default="")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--prefix", default="kvm-seq", help="記録用のコンテナの名前の頭（並べて走らせるときに分ける）")
    a = ap.parse_args()
    steps = steps_from_pages() if a.pages else steps_from_file(a.steps)
    out = Path(a.out)
    src = "本文の端末ブロックから機械的に作った入力" if a.pages else f"台本 {a.steps}"
    log = [f"# {src}を、読者と同じ起動（docker run --rm -it --hostname host、名前の無いボリューム2つ、PID 1 は tini、",
           "# その子の bash -l、umask 022、TERM=xterm）の1つのシェルに、最初から順に打った記録（章の間で exit しない）。",
           f"# 端末 {a.cols} 桁 × {a.rows} 行。作り方: python3 -I probe/kvm-seq.py（イメージ {a.image}）"]
    if a.title:
        log.append(f"# {a.title}")
    S = Sessions(a, log)
    n = 0
    t_start = time.time()
    try:
        for st in steps:
            k = st["kind"]
            if k == "chapter":
                log.append(f"\n\n========== {st['name']} ==========")
                continue
            if k == "note":
                log.append(f"\n# {st['text']}")
                continue
            if k == "close":
                S.close(st["sess"])
                continue
            if k == "sleep":
                time.sleep(st["sec"])
                continue
            if a.limit and n >= a.limit:
                break
            sess = st["sess"]
            if sess is None:          # 別の PC で取った記録（ここでは打たない）
                continue
            n += 1
            line = st["cmd"]
            stuck = False
            if sess == "pc":
                body = run_pc(st)
            else:
                t = S.get(sess)
                try:
                    body = run_step(t, st, sess)
                    if getattr(t, "closed", False):       # 檻を exit で閉じた
                        S.t.pop(sess, None)
                        subprocess.run(["docker", "rm", "-f", "-v", t.name], capture_output=True)
                        try:
                            os.waitpid(t.pid, 0)
                        except ChildProcessError:
                            pass
                except Stuck as e:
                    stuck = True
                    WARN.append(str(e))
                    subprocess.run(["docker", "exec", f"{a.prefix}-{sess}", "pkill", "-KILL", "-n", "-t", "pts/0"],
                                   capture_output=True)
                    try:
                        raw = t.until(MARK, 30)[:-len(MARK)]
                    except Stuck:
                        raw = b""
                    body = render(strip_echo(raw.decode("utf-8", "replace"), [line] + st["cont"]))
            log.append(f"\n$ {line}")
            for c in st["cont"]:
                log.append(f"> {c}")
            log.extend(body)
            if stuck:
                log.append("（プロンプトに戻らなかった。外から止めて続けた）")
                STUCK.append(f"{st.get('chap')}: $ {line}")
            print(f"\r{n} コマンド（{int(time.time() - t_start)} 秒）", end="", file=sys.stderr, flush=True)
    finally:
        out.write_text("\n".join(log) + "\n", encoding="utf-8")
        S.close_all()
    for w in STUCK:
        print("\n止まった: " + w, file=sys.stderr)
    for w in WARN:
        print("\n注意: " + w, file=sys.stderr)
    print(f"\n→ {out}（{n} コマンド）", file=sys.stderr)


if __name__ == "__main__":
    main()
