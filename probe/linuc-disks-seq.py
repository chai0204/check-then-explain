#!/usr/bin/env python3
"""LinuC 主題1.05: 本文を、読者と同じ起動・同じ打ち方（端末つきの対話シェルに、本文の順に1行ずつ）で
第1章から第11章まで通して打った記録を取る（演習の通しのような台本も打てる: --steps）。

  python3 -I probe/linuc-disks-seq.py --out logs/linuc-disks-seq.log            章のひな形（probe/linuc-disks-tpl/）から
  python3 -I probe/linuc-disks-seq.py --pages --out logs/linuc-disks-reseq.log  出来上がった本文（public/linuc-disks/theory/）から
  python3 -I probe/linuc-disks-fill.py                                          記録からひな形を埋めて本文を書き出す
  python3 -I probe/linuc-disks-seqcompare.py [記録 ...]                          本文と記録を突き合わせる

probe/linuc-files-seq.py（pty で対話シェルに1行ずつ打ち、y/n にも答える）を写し、仮想マシン型の檻のために
probe/kvm-seq.py の「ssh linuc で入って exit で出る」と画面の描き直し（render）を足した（2026-10-20）。

起動は読者と同じ: docker run -d …（名前付きボリューム2つ・--stop-timeout 30）のあと、`docker exec -it <名前> bash -l`
をホストの疑似端末（80 桁 × 24 行・TERM=xterm）の上で動かす。これが読者の1つ目の端末。
本文の端末ブロックは <pre data-where="…"> でどこで打つかを書いてある。
  「練習機の中（student@linuc）」 … 練習機に入っている端末で打つ（入っている端末が無ければ止まる＝本文に ssh linuc が足りない）
  「外（lab@host）」              … 外にいる端末で打つ。外にいる端末が無ければ、2つ目の端末を開く
                                   （本文の第6章で「端末をもう1つ開く」と書いてある。読者と同じ docker exec -it … bash -l）
                                   練習機の再起動で外に戻された端末があれば、それを先に使う（読者はその端末で vm start と ssh linuc を打つ）
本文から作る入力:
  "$ コマンド"                           → そのまま打つ
  ひな形の "$ コマンド<!--o keys="a|b||c"-->" → fdisk・gdisk・parted の問いが出るたびに、a・b・（Enter）・c と1つずつ答える
  出来上がった本文（--pages）では、対話の問いの行（"Command (m for help): n" など）から答えを読み取る
記録のための操作は、シェルに入るたびに1つだけ: PROMPT_COMMAND で PS1 を "$ "（＋端末の題名に印）にする。
本文のプロンプトの約束に合わせるためと、コマンドの終わり（次のプロンプト）を確実に見つけるため。
行頭に空白を置いて打つので、履歴には残らない（HISTCONTROL=ignoreboth）。

読者が次の行を打つまでの間（本文の地の文で「少し待つ」と書いてあるところ）:
  どの行も打つ前に 1 秒（THINK。読者が打つ手間）
  sudo reboot の後 25 秒 / virsh attach-device・detach-device の後 10 秒 / virsh change-media の後 4 秒 /
  区画の表を書き換えた後（fdisk・gdisk・parted の対話、sgdisk、parted … rm・mkpart）3 秒
  sudo timeout N udevadm monitor … は、終わるのを待たずに次へ進む（読者はもう1つの端末で USB を挿す）。
  その端末で次に打つときに、監視が終わるのを待ってから出力を記録する。
プロンプトに戻らないコマンドは、待ち時間を過ぎたら外から止め（docker exec で読者の端末の一番新しいプロセスに SIGKILL）、
記録に「プロンプトに戻らなかった」と残して先へ進む。突き合わせ（seqcompare）はこれを違いとして数える。
"""
import argparse, html, os, pty, re, select, subprocess, sys, time, fcntl, termios, struct
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TPL_DIR = REPO / "probe" / "linuc-disks-tpl"
PAGE_DIR = REPO / "public" / "linuc-disks" / "theory"
IMG = "lab-linuc-disks:1.1.0"
MARK = b"\x1b]0;SEQ\x07$ "          # PS1 の先頭に入れる見えない印（端末の題名）＋ "$ "
SETPS = " export PROMPT_COMMAND='PS1=\"\\[\\e]0;SEQ\\a\\]$ \"'"
GUEST_PROMPT = re.compile(rb"student@linuc:~\$ $")
HOST_PROMPT = re.compile(rb"lab@host:~\$ $")

# 対話のコマンド（fdisk・gdisk・parted を引数1つで打ったとき）の問い。行末がこれで終わったら答えを1つ送る
PROMPTS = [
    r"Command \(m for help\): ",
    r"Select \(default [a-z]\): ",
    r"Partition number \([^)]*\): ",
    r"First sector \([^)]*\): ",
    r"Last sector, \+/-sectors or \+/-size\{K,M,G,T,P\} \([^)]*\): ",
    r"Do you want to remove the signature\? \[Y\]es/\[N\]o: ",
    r"Partition type or alias \(type L to list all\): ",
    r"Hex code or alias \(type L to list all\): ",
    r"Command \(\? for help\): ",
    r"Proceed\? \(Y/N\): ",
    r"Do you want to proceed\? \(Y/N\): ",
    r"First sector \([^)]*\) or \{\+-\}size\{KMGTP\}: ",
    r"Last sector \([^)]*\) or \{\+-\}size\{KMGTP\}: ",
    r"Hex code or GUID \(L to show codes, Enter = [0-9A-Fa-f]+\): ",
    r"\(parted\) ",
]
PROMPT_END = re.compile("(" + "|".join(PROMPTS) + r")\Z")
PROMPT_LINE = re.compile("^(" + "|".join(PROMPTS) + ")(.*)$")
INTERACTIVE = re.compile(r"^sudo (fdisk|gdisk|parted) /dev/[a-z0-9]+$")


def timeout_for(cmd):
    if cmd.startswith("vm start"):
        return 420
    if cmd.startswith("vm stop"):
        return 150
    if cmd.startswith("ssh linuc"):
        return 90
    if re.search(r"\bmkfs\.btrfs\b|\blvreduce\b|\blvextend\b|\bxfs_repair\b|\bdd if=", cmd):
        return 240
    return 120


THINK = 1.0      # 読者が次のコマンドを打つまでの間（打つ手間）。udev などが前の操作の後始末を終える時間でもある


def pause_after(cmd):
    if re.match(r"sudo (systemctl )?reboot$", cmd):
        return 25
    # 区画の表を書き換えた後は、カーネルと udev が新しい区画を調べ終わるまで数秒かかる（TCG では遅い）。
    # 本文ではここに説明の段落があり、読者はそれを読んでから次を打つ
    if INTERACTIVE.match(cmd) or re.match(r"sudo (sgdisk|parted /dev/\S+ (rm|mkpart))\b", cmd):
        return 3
    if re.match(r"virsh (attach|detach)-device ", cmd):
        return 10
    if re.match(r"virsh change-media ", cmd):
        return 4
    return 0


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
    """端末に出た文字の並びを、最後に画面に見える行にする（\\r・ESC[K・横の移動・\\b を解釈し、ほかの制御は捨てる）。
    行の折り返し（80 桁）は描かない。読者の端末では長い行が折り返されて見えるが、文字は同じ。"""
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
    """疑似端末の上で docker exec -it <名前> bash -l を動かす（読者の端末1つぶん）。"""
    def __init__(self, label, container, cols, rows):
        self.label, self.container = label, container
        argv = ["docker", "exec", "-it", container, "bash", "-l"]
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
            os.environ["TERM"] = "xterm"
            os.execvp(argv[0], argv)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
        self.buf = b""
        self.in_guest = False
        self.dropped = False         # 練習機の再起動で外に戻された（読者はこの端末で vm start と ssh linuc を打つ）
        self.pending = None          # 終わるのを待たずに次へ進んだコマンド（udevadm monitor）の記録先

    def send(self, s):
        os.write(self.fd, s.encode("utf-8"))

    def read_some(self, t=0.2):
        r, _, _ = select.select([self.fd], [], [], t)
        if r:
            try:
                chunk = os.read(self.fd, 65536)
            except OSError:
                raise Stuck("端末が閉じた")
            if not chunk:
                raise Stuck("端末が閉じた")
            self.buf += chunk
            return True
        return False

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
            self.read_some()
        got, self.buf = self.buf[:k], self.buf[k:]
        return got

    def until_prompt(self, timeout):
        """対話のコマンドが問いを出して入力を待つまで読む（画面の最後の行が PROMPTS のどれかで終わるまで）。"""
        end = time.time() + timeout
        while True:
            vis = ANSI.sub("", self.buf.decode("utf-8", "replace"))
            last = vis.replace("\r\n", "\n").split("\n")[-1].split("\r")[-1]
            if PROMPT_END.search(last):
                got, self.buf = self.buf, b""
                return got
            if time.time() > end:
                raise Stuck(f"問いが出なかった\n最後に見えたもの: {self.buf[-400:]!r}")
            self.read_some()

    def drain(self, t):
        end = time.time() + t
        while time.time() < end:
            try:
                self.read_some(0.2)
            except Stuck:
                return

    def close(self):
        for _ in range(3):
            try:
                self.send("exit\r")
            except OSError:
                break
            self.drain(1.5)
        try:
            os.waitpid(self.pid, 0)
        except ChildProcessError:
            pass


class Sessions:
    def __init__(self, a, log):
        self.a, self.log = a, log
        self.terms = []
        self.last = None

    def open(self):
        label = f"端末{len(self.terms) + 1}"
        t = Term(label, self.a.name, self.a.cols, self.a.rows)
        raw = t.until(HOST_PROMPT, 120)
        banner = render(raw.decode("utf-8", "replace"))
        if banner and banner[-1].rstrip().endswith("lab@host:~$"):
            banner = banner[:-1]
        self.log.append(f"\n# --- {label}: docker exec -it {self.a.name} bash -l で入ったときの表示 ---")
        self.log.extend(banner)
        self.log.append("# --- ここまで ---")
        t.send(SETPS + "\r")
        t.until(MARK, 20)
        self.terms.append(t)
        return t

    def pick(self, where):
        if "練習機の中" in where:
            ins = [t for t in self.terms if t.in_guest]
            if not ins:
                raise SystemExit(f"練習機に入っている端末が無い（本文に ssh linuc が足りない）: {where}")
            return ins[0]
        outs = [t for t in self.terms if not t.in_guest]
        dropped = [t for t in outs if t.dropped]
        if dropped:
            return dropped[0]
        if outs:
            return outs[-1]                # 2つ目の端末を開いた後は、そちらを外の端末として使う
        return self.open()

    def close_all(self):
        for t in self.terms:
            if t.in_guest:
                t.send("exit\r")
                t.drain(2)
            t.close()


def collect_pending(t):
    """終わるのを待たずに次へ進んだコマンド（udevadm monitor）の出力を、終わるのを待って記録に入れる。"""
    p = t.pending
    if not p:
        return
    t.pending = None
    try:
        raw = t.until(MARK, max(5, p["deadline"] - time.time()) + 30)[:-len(MARK)]
        p["entry"][:] = render(strip_echo(raw.decode("utf-8", "replace"), [p["cmd"]]))
    except Stuck as e:
        WARN.append(str(e))
        p["entry"][:] = ["（プロンプトに戻らなかった）"]


def run_step(S, st):
    """1つの組を打ち、記録に書く出力の行（リスト）を返す。"""
    line = st["cmd"]
    t = S.pick(st["where"])
    S.last = t
    collect_pending(t)
    time.sleep(THINK)
    to = timeout_for(line)
    t.buf = b""
    t.send(line + "\r")

    # 終わるのを待たずに次へ進む（読者は監視を走らせたまま、もう1つの端末で USB を挿す）
    m = re.search(r"\btimeout (\d+) udevadm monitor\b", line)
    if m:
        entry = []
        t.pending = {"cmd": line, "entry": entry, "deadline": time.time() + int(m.group(1))}
        time.sleep(5)                   # 監視が動き出すまで（読者が端末を持ち替えるくらいの間）
        return entry

    if re.fullmatch(r"ssh linuc", line) and not t.in_guest:
        raw = t.until(GUEST_PROMPT, to)
        out = render(strip_echo(raw.decode("utf-8", "replace"), [line]))
        if out and out[-1].rstrip().endswith("student@linuc:~$"):
            out = out[:-1]
        t.in_guest, t.dropped = True, False
        t.send(SETPS + "\r")
        t.until(MARK, 20)
        return out

    raw = b""
    if st.get("keys") is not None:
        for k in st["keys"]:
            raw += t.until_prompt(60)
            time.sleep(0.3)
            t.send(k + "\r")
    if re.match(r"sudo (systemctl )?reboot$", line) and t.in_guest:
        # 練習機の bash は reboot を受け付けるとすぐ次のプロンプトを出し、そのあとで接続が切れて外に戻る。
        # 「Connection to … closed.」の行と、外のプロンプトまで読む。途中に出た練習機のプロンプトは記録から除く
        # （本文のプロンプトは $ に揃えているが、出力の途中の $ はコマンドの行と見分けがつかなくなるため。本文に書く）。
        raw += t.until(re.compile(rb"Connection to 127\.0\.0\.1 closed\.\r*\n"), to)
        raw += t.until(MARK, 30)[:-len(MARK)]
        raw = raw.replace(MARK, b"")
        t.in_guest, t.dropped = False, True
    else:
        raw += t.until(MARK, to)[:-len(MARK)]
    if line == "exit" and t.in_guest:
        t.in_guest = False
    out = render(strip_echo(raw.decode("utf-8", "replace"), [line]))
    p = pause_after(line)
    if p:
        time.sleep(p)
    return out


def parse_keys(directive):
    m = re.search(r'\bkeys="([^"]*)"', directive or "")
    return None if m is None else m.group(1).split("|")


def steps_from(dir_, chapters, from_pages):
    steps = []
    for f in sorted(dir_.glob("[0-9][0-9]-*.html")):
        n = int(f.name[:2])
        if chapters and n not in chapters:
            continue
        s = f.read_text(encoding="utf-8")
        if not re.search(r'<body[^>]*data-ch="\d+"', s):
            continue
        steps.append({"kind": "chapter", "name": f"{n}. {f.name}"})
        for m in re.finditer(r"<pre\b([^>]*)><code>([\s\S]*?)</code></pre>", s):
            mw = re.search(r'data-where="([^"]*)"', m.group(1))
            where = html.unescape(mw.group(1)) if mw else ""
            body = m.group(2)
            if not re.search(r"^\$ ", body, re.M):
                continue
            if not where:
                raise SystemExit(f"{f.name}: data-where の無い端末ブロックがある: {body[:60]!r}")
            cur = None
            for raw in body.split("\n"):
                d = re.search(r"<!--o\b(.*?)-->", raw)
                text = html.unescape(re.sub(r"<[^>]+>", "", re.sub(r"<!--.*?-->", "", raw)))
                text = re.sub(r"\s{2,}←.*$", "", text)
                if text.startswith("$ "):
                    cur = {"kind": "cmd", "cmd": text[2:], "where": where, "chap": f.name,
                           "keys": None if from_pages else parse_keys(d.group(1) if d else "")}
                    if from_pages and INTERACTIVE.match(cur["cmd"]):
                        cur["keys"] = []
                    steps.append(cur)
                elif cur is not None and from_pages and cur["keys"] is not None:
                    pm = PROMPT_LINE.match(text.rstrip("\n"))
                    if pm:
                        cur["keys"].append(pm.group(2).strip())
    return steps


def steps_from_file(path):
    """台本の形（演習の通し probe/linuc-disks-solve-all.txt などに使う）:
      "== 題 =="       節の見出し（記録の「========== 題 ==========」になる）
      "@外" / "@中"    この後のコマンドを打つ場所（外 = lab@host、中 = 練習機の中）
      "$ コマンド"     打つ
      "@keys a|b||c"   直前のコマンドの対話の答え（fdisk・gdisk・parted）
      "@sleep N"       人が次を打つまでの間（記録しない）
      "# 注釈"         記録に残す注釈"""
    WH = {"外": "外（lab@host）", "中": "練習機の中（student@linuc）"}
    steps, where, cur = [], WH["外"], None
    for raw in Path(path).read_text(encoding="utf-8").split("\n"):
        if raw.startswith("== ") and raw.endswith(" =="):
            steps.append({"kind": "chapter", "name": raw[3:-3]})
            cur = None
        elif raw.startswith("@keys "):
            cur["keys"] = raw[6:].split("|")
        elif raw.startswith("@sleep "):
            steps.append({"kind": "sleep", "sec": float(raw[7:])})
            cur = None
        elif raw.strip() in ("@外", "@中"):
            where = WH[raw.strip()[1:]]
            cur = None
        elif raw.startswith("$ "):
            cur = {"kind": "cmd", "cmd": raw[2:], "where": where, "chap": "台本", "keys": None}
            steps.append(cur)
        elif raw.startswith("# "):
            steps.append({"kind": "note", "text": raw[2:]})
            cur = None
    return steps


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cols", type=int, default=80)
    ap.add_argument("--rows", type=int, default=24)
    ap.add_argument("--out", required=True)
    ap.add_argument("--pages", action="store_true", help="出来上がった本文から打つ（既定はひな形）")
    ap.add_argument("--steps", help="台本のファイルから打つ（演習の通しなど）")
    ap.add_argument("--image", default=IMG)
    ap.add_argument("--name", default="linuc-disks-r11-seq", help="記録用のコンテナの名前（ボリュームは <名前>-vm・<名前>-state）")
    ap.add_argument("--chapters", default="", help="打つ章（例: 1-3）。省くと全部。状態は章をまたぐので、ふつうは 1 から")
    ap.add_argument("--keep", action="store_true", help="終わってもコンテナとボリュームを消さない（続きを手で調べるとき）")
    a = ap.parse_args()
    chapters = set()
    for part in filter(None, a.chapters.split(",")):
        lo, _, hi = part.partition("-")
        chapters.update(range(int(lo), int(hi or lo) + 1))
    steps = steps_from_file(a.steps) if a.steps else steps_from(PAGE_DIR if a.pages else TPL_DIR, chapters, a.pages)
    out = Path(a.out)

    vol_vm, vol_st = f"{a.name}-vm", f"{a.name}-state"
    subprocess.run(["docker", "rm", "-f", "-v", a.name], capture_output=True)
    subprocess.run(["docker", "volume", "rm", vol_vm, vol_st], capture_output=True)
    run = ["docker", "run", "-d", "--name", a.name, "--hostname", "host", "--stop-timeout", "30",
           "-v", f"{vol_vm}:/home/lab/vm", "-v", f"{vol_st}:/home/lab/.lab", a.image]
    subprocess.run(run, check=True, capture_output=True)
    time.sleep(3)

    src = (f"台本（{a.steps}）" if a.steps else
           "出来上がった本文（public/linuc-disks/theory/）" if a.pages else "章のひな形（probe/linuc-disks-tpl/）")
    which = "最初から順に" if a.steps else (f"第{a.chapters}章" if chapters else "第1章から第11章まで")
    log = [f"# {src}の端末ブロックから機械的に作った入力を、読者と同じ起動（docker run -d … 名前付きボリューム2つ、",
           "# docker exec -it … bash -l、umask 022、TERM=xterm）の端末に、" + which + "、本文の順に1行ずつ打った記録。",
           f"# 端末 {a.cols} 桁 × {a.rows} 行。外と練習機の中は data-where で打ち分けた。作り方: python3 -I probe/linuc-disks-seq.py",
           f"# イメージ {a.image}（{subprocess.run(['docker', 'image', 'inspect', '-f', '{{.Id}}', a.image], capture_output=True, text=True).stdout.strip()}）",
           f"# 開始 {time.strftime('%Y-%m-%d %H:%M:%S')}"]
    S = Sessions(a, log)
    n = 0
    t0 = time.time()
    try:
        S.open()
        for st in steps:
            if st["kind"] == "chapter":
                log.append(f"\n\n========== {st['name']} ==========")
                print(f"\n{st['name']}", file=sys.stderr, flush=True)
                continue
            if st["kind"] == "note":
                log.append(f"\n# {st['text']}")
                continue
            if st["kind"] == "sleep":
                time.sleep(st["sec"])
                continue
            n += 1
            line = st["cmd"]
            stuck = False
            try:
                body = run_step(S, st)
            except Stuck as e:
                stuck = True
                WARN.append(f"{st['chap']}: $ {line}\n{e}")
                # 止まった端末の、いちばん新しいプロセスを外から止める（docker exec の端末は pts/0 から順に付く）
                t = S.last
                subprocess.run(["docker", "exec", a.name, "bash", "-c",
                                f"pkill -KILL -n -t pts/{S.terms.index(t)}; true"], capture_output=True)
                try:
                    raw = t.until(MARK, 30)[:-len(MARK)]
                except Stuck:
                    raw = b""
                body = render(strip_echo(raw.decode("utf-8", "replace"), [line]))
            log.append(f"\n$ {line}")
            log.append(body)          # リストのまま入れる（udevadm monitor の出力は後から埋まる）。書き出すときに平らにする
            if stuck:
                log.append("（プロンプトに戻らなかった。外から止めて続けた）")
                STUCK.append(f"{st['chap']}: $ {line}")
            print(f"\r{n} コマンド（{int(time.time() - t0)} 秒）", end="", file=sys.stderr, flush=True)
        for t in S.terms:
            collect_pending(t)
    finally:
        # udevadm monitor のように、出力を後から埋める項目があるので、最後にまとめて書き出す
        out.write_text("\n".join(flatten(log)) + "\n", encoding="utf-8")
        S.close_all()
        if not a.keep:
            subprocess.run(["docker", "rm", "-f", "-v", a.name], capture_output=True)
            subprocess.run(["docker", "volume", "rm", vol_vm, vol_st], capture_output=True)
    for w in STUCK:
        print("\n止まった: " + w, file=sys.stderr)
    for w in WARN:
        print("\n注意: " + w, file=sys.stderr)
    print(f"\n→ {out}（{n} コマンド・{int(time.time() - t0)} 秒）", file=sys.stderr)


def flatten(log):
    out = []
    for x in log:
        if isinstance(x, list):
            out.extend(x)
        else:
            out.append(x)
    return out


if __name__ == "__main__":
    main()
