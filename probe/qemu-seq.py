#!/usr/bin/env python3
"""QEMU の記事: 本文の端末ブロックから読者の入力を機械的に作り、読者と同じ起動・同じ端末の1つのシェルに、
第1章から第7章まで通して打った記録を取る。本文の端末表示はこの記録から引く（logs/qemu-seq.log）。

  python3 -I probe/qemu-seq.py [--out logs/qemu-seq.log] [--cols 80 --rows 24] [--chapters 1,2]
  python3 -I probe/qemu-seqcompare.py [記録 ...]      本文と突き合わせる

起動は読者の起動コマンドそのもの（docker run --rm -it --hostname host、ボリューム2つ）を、ホストの tmux の
窓（既定 80 桁 × 24 行・設定ファイルを読まない・ステータス行なし）の上で走らせる。だから端末あり・
bash -l・umask 022・TERM=xterm が読者と同じになり、記録は「読者の画面に最後に残るもの」になる
（\\r で書き換えられる行は最後の形、幅を超える行は折り返しをつないだ1行、端末の折り返しが止められていれば
切れた行のまま）。ボリュームは名前を付けない（--rm でコンテナと一緒に消える）。

章の間で exit しない。読者は1つのシェルのまま章をまたいで打つ（作ったファイル・動かしたプロセス・端末の状態が
次の章に持ち越される。第1章で SeaBIOS が止めた端末の折り返しは、第2章の最初の画面に効く）。

本文から作る入力（手で足したものは無い）:
  "$ コマンド"              外（lab@host）のシェルにそのまま打つ
  "… <kbd>文字</kbd>"       QEMU の画面（練習機のシリアルや QEMU のモニタ）に打つ（Enter 付き）。
                            行の頭（プロンプト）の文字が出るのを待ってから打つ。行の頭が空なら練習機のプロンプトを待つ
  "Password:"               練習機のログインのパスワード（本文に書いてある student）を打つ
  "（打鍵: Ctrl-a c）" など  キーを押す（Ctrl-a c / Ctrl-a x / Ctrl-a h / Ctrl-C / Enter）
記録のための操作は1つだけ: 最初に PROMPT_COMMAND で PS1 を "$ "（＋端末の題名に通し番号）にする。
本文のプロンプトの約束に合わせるためと、コマンドの終わり（次のプロンプト）を確実に見つけるため。
行頭に空白を置いて打つので、履歴には残らない（HISTCONTROL=ignoreboth）。

待ち方: 「プロンプトが出たか」は、画面ではなく、端末に流れたバイト（tmux の pipe-pane で取る）で判断する。
練習機の systemd-fsckd は、起動の 30 秒ほど後に退場するとき、コンソール（= この端末）の1行を空白で上書きする
（実測: \\r と空白 51 個と \\r）。それがログインの案内やプロンプトの行に当たると、画面からはプロンプトが消えるので、
画面を見て待つと待ちきれない。流れたバイトには、消される前のプロンプトが残っている。

間合い（読者が次の行を打つまでの時間）は決めておく。練習機にログインしてから最初のキーまでは 15 秒、
ほかは、待つものが出てから 1 秒。
"""
import argparse, html, os, re, subprocess, sys, tempfile, time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
THEORY = REPO / "public" / "qemu" / "theory"
IMG = "lab-qemu:1.0.0"
SOCK = "qemu-seq"
NAME = "qemu-seq"
PASSWORD = "student"                  # 本文に書いてある練習機のパスワード
LOGIN_SETTLE = 15.0                   # ログインしてから最初のキーまで
SETTLE = 1.0                          # 待つものが出てから打つまで
GUEST_PROMPT = "student@linuc:~$"
KEYS = {"Ctrl-a c": ["C-a", "c"], "Ctrl-a x": ["C-a", "x"], "Ctrl-a h": ["C-a", "h"],
        "Ctrl-C": ["C-c"], "Enter": ["Enter"]}
STUCK, WARN = [], []


def tm(*a, check=False):
    r = subprocess.run(["tmux", "-u", "-L", SOCK, *a], capture_output=True, text=True)
    if check and r.returncode:
        raise RuntimeError(f"tmux {a[0]}: {r.stderr.strip()}")
    return r.stdout


def strip_tags(s):
    return html.unescape(re.sub(r"<[^>]+>", "", s))


def chapter_steps(chapters=None):
    """章ごとに [(名前, [ステップ…])]。ステップ = {"cmd", "events": [...]}。
    event = ("type", 行の頭, 文字) / ("pw",) / ("key", 名前) / ("see", 出力の行)"""
    out = []
    for f in sorted(THEORY.glob("[0-9][0-9]-*.html")):
        n = int(f.name[:2])
        if chapters and n not in chapters:
            continue
        steps = []
        src = f.read_text(encoding="utf-8")
        for m in re.finditer(r"<pre\b[^>]*><code>([\s\S]*?)</code></pre>", src):
            raw_lines = m.group(1).split("\n")
            if not any(strip_tags(l).startswith("$ ") for l in raw_lines):
                continue
            cur = None
            for raw in raw_lines:
                raw = re.sub(r"\s{2,}←.*$", "", raw)
                txt = strip_tags(raw)
                if txt.startswith("$ "):
                    cur = {"cmd": txt[2:], "events": [], "chap": f.name}
                    steps.append(cur)
                    continue
                if cur is None:
                    continue
                km = re.search(r"<kbd>([\s\S]*?)</kbd>", raw)
                t = txt.strip()
                if km:
                    prefix = strip_tags(raw[:km.start()])
                    cur["events"].append(("type", prefix.rstrip(), strip_tags(km.group(1))))
                elif re.fullmatch(r"Password:", t):
                    cur["events"].append(("pw",))
                elif re.fullmatch(r"（打鍵: (.+)）", t):
                    k = re.fullmatch(r"（打鍵: (.+)）", t).group(1)
                    if k not in KEYS:
                        raise SystemExit(f"{f.name}: 知らないキー: {k}")
                    cur["events"].append(("key", k))
                elif t and not re.fullmatch(r"(\.\.\.|…|（[^）]*）)", t):
                    cur["events"].append(("see", t))
        out.append((f.name, steps))
    return out


class Term:
    def __init__(self, cols, rows):
        subprocess.run(["docker", "rm", "-f", "-v", NAME], capture_output=True)
        tm("kill-server")
        fd, self.rawpath = tempfile.mkstemp(prefix=f"{NAME}-", suffix=".raw")
        os.close(fd)
        run = (f"docker run --rm -it --name {NAME} --hostname host "
               f"-v /home/lab/work -v /home/lab/.lab {IMG}")
        tm("-f", "/dev/null", "start-server", ";", "set", "-g", "history-limit", "500000", ";",
           "set", "-g", "status", "off", ";",
           "new-session", "-d", "-s", "r", "-x", str(cols), "-y", str(rows), run, check=True)
        # 端末に流れたバイトをそのまま残す（プロンプトが出たかの判断に使う。記録そのものは画面から取る）
        tm("pipe-pane", "-t", "r", "-o", f"cat >> {self.rawpath}")
        end = time.time() + 120
        while time.time() < end:
            if "lab@host" in self.title():
                break
            time.sleep(0.3)
        else:
            raise RuntimeError("檻のプロンプトが出ない")
        time.sleep(1.0)
        self.banner = self.capture_all()
        tm("send-keys", "-t", "r", "-l",
           " export PROMPT_COMMAND='__n=$((__n+1)); PS1=\"\\[\\e]0;SEQ$__n\\a\\]\\$ \"'")
        tm("send-keys", "-t", "r", "Enter")
        if not self.wait(lambda: self.title().startswith("SEQ"), 30):
            raise RuntimeError("PS1 が切り替わらない")
        time.sleep(0.5)

    def title(self):
        return tm("display", "-p", "-t", "r", "#{pane_title}").strip()

    def pos(self):
        hs, cy = tm("display", "-p", "-t", "r", "#{history_size} #{cursor_y}").split()
        return int(hs), int(cy)

    def screen(self):
        return [l.rstrip() for l in tm("capture-pane", "-p", "-t", "r").split("\n")]

    def last(self):
        ls = [l for l in self.screen() if l.strip()]
        return ls[-1] if ls else ""

    def capture_all(self):
        return tm("capture-pane", "-p", "-J", "-S", "-", "-E", "-", "-t", "r")

    def since(self, top):
        hs, _ = self.pos()
        txt = tm("capture-pane", "-p", "-J", "-S", str(top - hs), "-E", "-", "-t", "r")
        return [l.expandtabs(8).rstrip() for l in txt.split("\n")]

    # 端末に流れたバイト
    def mark(self):
        return os.path.getsize(self.rawpath)

    def raw_since(self, m):
        with open(self.rawpath, "rb") as f:
            f.seek(m)
            return f.read()

    def wait_raw(self, pats, m, timeout):
        """m から後に流れたバイトに、pats のどれかが現れるまで待つ"""
        pats = [p.encode("utf-8") if isinstance(p, str) else p for p in pats]
        return self.wait(lambda: any(p in self.raw_since(m) for p in pats), timeout)

    @staticmethod
    def wait(cond, timeout, step=0.25):
        end = time.time() + timeout
        while time.time() < end:
            if cond():
                return True
            time.sleep(step)
        return False

    def stable(self, quiet, timeout):
        """画面が quiet 秒変わらなくなるまで待つ"""
        end, prev, since = time.time() + timeout, None, time.time()
        while time.time() < end:
            cur = tm("capture-pane", "-p", "-t", "r")
            if cur != prev:
                prev, since = cur, time.time()
            elif time.time() - since >= quiet:
                return True
            time.sleep(0.25)
        return False

    def keys(self, *k):
        tm("send-keys", "-t", "r", *k)

    def lit(self, s):
        tm("send-keys", "-t", "r", "-l", s)

    def alive(self):
        return subprocess.run(["tmux", "-u", "-L", SOCK, "has-session", "-t", "r"],
                              capture_output=True).returncode == 0

    def close(self):
        for _ in range(3):                    # 読者と同じく exit で抜ける（--rm で檻ごと消える）
            if not self.alive():
                break
            self.lit("exit")
            self.keys("Enter")
            time.sleep(1.5)
        tm("kill-server")
        # --rm の自動削除を待たずに消す場合も、名前の無いボリュームを -v で一緒に消す
        subprocess.run(["docker", "rm", "-f", "-v", NAME], capture_output=True)
        try:
            os.unlink(self.rawpath)
        except OSError:
            pass


def loose(line):
    """本文の出力の行を、数（と小数点）と空白の違いを許す形にする。時間や数が毎回変わる行
    （time の real・user・sys など）も、キーを押す前の目印に使えるように。"""
    out = []
    for p in re.split(r"(\d[\d.]*|\s+)", line.strip()):
        if not p:
            continue
        out.append(r"[\d.]+" if p[0].isdigit() else r"\s+" if p.isspace() else re.escape(p))
    return re.compile("".join(out))


def prompt_pat(prefix):
    """本文の行の頭（入力の前に画面に出ているもの）から、流れたバイトの中で待つ文字を決める"""
    p = prefix.rstrip()
    if p.endswith("login:"):
        return ["login: "]
    if p.endswith("(qemu)"):
        return ["(qemu) "]
    if p == "" or p.endswith(GUEST_PROMPT):
        return [GUEST_PROMPT + " "]
    return [p]


def run_step(t, st):
    """1つのコマンド（と、その中で打つ QEMU の画面への入力）を打ち、記録に書く行を返す。"""
    hs0, cy0 = t.pos()
    top = hs0 + cy0
    title0 = t.title()
    done = lambda: t.title().startswith("SEQ") and t.title() != title0
    m = t.mark()                              # 最後に打った時点（ここから後に流れたバイトで待つ）
    t.lit(st["cmd"])
    t.keys("Enter")
    time.sleep(0.5)
    notes = []
    state = {"logged_in": False, "ctx": None, "m": m}
    prev_see = None

    def note_wait(what):
        notes.append(f"（待ちきれなかった: {what}。最後の行: {t.last()!r}）")
        WARN.append(f"{st['chap']}: $ {st['cmd'][:60]} … {what}")

    def settle_ctx():
        """最後に打ったものが終わるまで待つ（練習機のシェルならプロンプト、モニタなら (qemu) が流れるまで）。
        読者は、打ったものの出力が出きってから次を打つ。画面が静かなだけでは終わったとは言えない
        （練習機の中の時間のかかるループは、何も出さずに数秒動く）。"""
        if state["ctx"] == "guest":
            if not t.wait_raw([GUEST_PROMPT + " "], state["m"], 400):
                note_wait("練習機のプロンプト")
        elif state["ctx"] == "monitor":
            if not t.wait_raw(["(qemu) "], state["m"], 400):
                note_wait("(qemu)")

    def pause():
        if state["logged_in"]:
            time.sleep(LOGIN_SETTLE)
            state["logged_in"] = False
        else:
            time.sleep(SETTLE)

    for ev in st["events"]:
        kind = ev[0]
        if kind == "see":
            prev_see = ev[1]
            continue
        if kind == "type":
            settle_ctx()
            pats = prompt_pat(ev[1])
            if not t.wait_raw(pats, state["m"], 400):
                note_wait(repr(pats[0]))
            pause()
            state["m"] = t.mark()
            before = t.last()
            t.lit(ev[2])
            # こだまが出てから Enter（練習機が忙しいとこだまが遅れる）。モニタのこだまは制御文字が混ざるので画面でも見る
            tail = ev[2][-3:].encode("utf-8")
            t.wait(lambda: tail in t.raw_since(state["m"]) or t.last() != before, 15, 0.1)
            t.keys("Enter")
            time.sleep(0.7)
            prev_see = None
            state["ctx"] = ("monitor" if pats == ["(qemu) "]
                            else "guest" if pats == [GUEST_PROMPT + " "] else None)
        elif kind == "pw":
            if not t.wait_raw(["Password: "], state["m"], 60):
                note_wait("'Password:'")
            time.sleep(SETTLE)
            state["m"] = t.mark()
            t.lit(PASSWORD)
            t.keys("Enter")
            time.sleep(0.7)
            state["logged_in"] = True
            prev_see = None
            state["ctx"] = "guest"            # 次はプロンプト（ログインの案内の後）を待つ
        elif kind == "key":
            name = ev[1]
            settle_ctx()
            if prev_see:
                # 直前に本文が見せている出力の行が、最後の入力より後に出るまで待つ（流れたバイトか、画面で）
                want = prev_see
                rx = loose(want)
                ok = t.wait(lambda: rx.search(t.raw_since(state["m"]).decode("utf-8", "replace").replace("\r", ""))
                            or any(rx.fullmatch(l.strip()) for l in t.since(top)), 400)
                if not ok:
                    note_wait(repr(want))
                t.stable(1.5, 30)
            else:
                t.stable(2.0, 60)
            pause()
            state["m"] = t.mark()
            t.keys(*KEYS[name])
            time.sleep(0.7)
            prev_see = None
            state["ctx"] = None
    # プロンプトに戻るのを待つ
    if not t.wait(done, 600):
        notes.append("（プロンプトに戻らなかった。外から止めて続けた）")
        STUCK.append(f"{st['chap']}: $ {st['cmd']}")
        t.keys("C-a", "x")
        time.sleep(2)
        t.keys("C-c")
        if not t.wait(done, 60):
            subprocess.run(["docker", "exec", NAME, "pkill", "-KILL", "-f", "qemu-system"], capture_output=True)
            if not t.wait(done, 60):
                raise RuntimeError(f"止まったまま戻らない: {st['cmd']}")
    time.sleep(0.3)
    lines = t.since(top)
    while lines and lines[-1] == "":
        lines.pop()
    # 最後の行は次のプロンプト（"$"）。出力が改行で終わっていなければ、その前に出力が続いている
    if lines and lines[-1].endswith("$"):
        rest = lines[-1][:-1].rstrip()
        lines = lines[:-1] + ([rest] if rest else [])
    echo = "$ " + st["cmd"]
    if not lines or lines[0].rstrip() != echo.rstrip():
        WARN.append(f"{st['chap']}: こだまが合わない: {st['cmd'][:60]!r} / 画面 {lines[:1]!r}")
        body = lines
    else:
        body = lines[1:]
    # 空行の連続は1つにする（画面の消去で押し出された空白の行）
    out, blank = [], False
    for l in body:
        if l.strip() == "":
            if not blank:
                out.append("")
            blank = True
        else:
            out.append(l)
            blank = False
    while out and out[0] == "":
        out.pop(0)
    return out + notes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cols", type=int, default=80)
    ap.add_argument("--rows", type=int, default=24)
    ap.add_argument("--chapters", default="")
    ap.add_argument("--out", default=str(REPO / "logs" / "qemu-seq.log"))
    a = ap.parse_args()
    chapters = {int(x) for x in a.chapters.split(",") if x.strip()} or None
    plan = chapter_steps(chapters)
    out = Path(a.out)
    log = ["# 本文の端末ブロックから機械的に作った入力を、読者と同じ起動（docker run --rm -it --hostname host、",
           "# 名前の無いボリューム2つ、bash -l、umask 022、TERM=xterm）の1つのシェルに、章をまたいで exit せずに打った記録。",
           f"# 端末 {a.cols} 桁 × {a.rows} 行（tmux）。画面に最後に残ったものを書く。作り方: python3 -I probe/qemu-seq.py（イメージ {IMG}）"]
    t = Term(a.cols, a.rows)
    n = 0
    t0 = time.time()
    try:
        # 檻に入った直後の画面と、検証環境（実践編に載せる lab env）
        log.append("\n\n========== 0. 檻に入った直後 ==========")
        log.extend(l.rstrip() for l in t.banner.rstrip("\n").split("\n"))
        body = run_step(t, {"cmd": "lab env", "events": [], "chap": "00"})
        log.append("\n$ lab env")
        log.extend(body)
        for name, steps in plan:
            log.append(f"\n\n========== {int(name[:2])}. {name} ==========")
            for st in steps:
                body = run_step(t, st)
                log.append(f"\n$ {st['cmd']}")
                log.extend(body)
                n += 1
                out.write_text("\n".join(log) + "\n", encoding="utf-8")
                print(f"\r{name} {n} コマンド {int(time.time() - t0)} 秒", end="", file=sys.stderr, flush=True)
    finally:
        out.write_text("\n".join(log) + "\n", encoding="utf-8")
        t.close()
    for w in STUCK:
        print("\n止まった: " + w, file=sys.stderr)
    for w in WARN:
        print("\n注意: " + w, file=sys.stderr)
    print(f"\n→ {out}（{n} コマンド、{int(time.time() - t0)} 秒）", file=sys.stderr)


if __name__ == "__main__":
    main()
