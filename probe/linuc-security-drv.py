#!/usr/bin/env python3
"""練習機の中で、読者と同じ「対話のログインシェル」を pty の上に起動し、コマンドを1行ずつ送って記録する。

  python3 drv.py コマンドの並びのファイル

なぜ要るか（1.0.1 で作り直した理由）:
  1.0.0 の probe は `$` の行ごとに別の ssh セッションでコマンドを流していた。そのためシェルの状態
  （ulimit・変数・readonly・ssh-agent の環境変数）が行をまたいで持ち越されず、
  「ulimit -n 512 の後に ulimit -n 4096 が通る（rc=0）」という、読者の画面では起きない記録ができた。
  ここでは1つのシェルに続けて打つので、読者が1つの端末で打つのと同じ状態の流れになる。

読者と揃えているもの:
  - ログインシェル（argv[0] が -bash）・対話（tty の上）。エラーの頭が "-bash: …" になり、行番号が付かない
  - TERM=xterm（docker exec -it と ssh が渡す値）。~/.bashrc の alias（ls --color=auto など）が効く
  - 履歴展開（! の展開）も読者と同じく効く
揃えていないもの（記録の都合）:
  - 入力のエコーは切る（readline は --noediting で切り、端末の ECHO も切る）。代わりに "$ コマンド" を自分で書く
  - 色などの端末制御の文字は取り除いて残す（照合はテキストで行うため）

ファイルの書き方: 1行に1コマンド。空行は飛ばす。
  #!wait 秒      何も打たずに待ち、その間に出たものを記録する（TMOUT の自動ログアウトなど）
"""
import fcntl, os, pty, re, select, struct, sys, termios, time

COLS = int(os.environ.get("DRV_COLS", "80"))
ROWS = int(os.environ.get("DRV_ROWS", "24"))
TIMEOUT = float(os.environ.get("DRV_TIMEOUT", "240"))

# 端末制御の文字列（CSI・OSC・文字集合の切替など）
ANSI = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[()][A-Za-z0-9]|\x1b[=>78]")
CTRL = re.compile(r"[\x00-\x08\x0b-\x1f\x7f]")        # \t と \n 以外の制御文字（ベル \a、\r など）
PROMPT = re.compile(r"[a-z_][a-z0-9_-]*@linuc:[^\n]*?[$#] $")


def clean(b: bytes) -> str:
    s = b.decode("utf-8", errors="replace")
    s = ANSI.sub("", s)
    s = s.replace("\r\n", "\n").replace("\r", "")
    return CTRL.sub("", s)


def main():
    cmds = open(sys.argv[1], encoding="utf-8").read().split("\n")
    pid, fd = pty.fork()
    if pid == 0:
        attrs = termios.tcgetattr(0)
        attrs[3] &= ~(termios.ECHO | termios.ECHONL)
        termios.tcsetattr(0, termios.TCSANOW, attrs)
        fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
        env = dict(os.environ)
        env["TERM"] = "xterm"
        env.pop("PROMPT_COMMAND", None)
        home = env.get("HOME", "/")
        try:
            os.chdir(home)
        except OSError:
            pass
        os.execve("/bin/bash", ["-bash", "--noediting"], env)

    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
    alive = [True]

    def read_until(pred, limit):
        buf = b""
        end = time.time() + limit
        while time.time() < end:
            r, _, _ = select.select([fd], [], [], 0.2)
            if fd in r:
                try:
                    chunk = os.read(fd, 65536)
                except OSError:
                    chunk = b""
                if not chunk:
                    alive[0] = False
                    return buf, True
                buf += chunk
                if pred(buf):
                    return buf, True
        return buf, False

    def has_prompt(b):
        return PROMPT.search(clean(b)) is not None

    # 最初のプロンプト（ログイン時の表示は捨てる）
    read_until(has_prompt, 60)

    out = sys.stdout
    for line in cmds:
        if not alive[0]:
            break
        if not line.strip():
            continue
        if line.startswith("#!wait"):
            secs = float(line.split()[1])
            buf, _ = read_until(lambda b: False, secs)
            text = clean(buf)
            m = PROMPT.search(text)
            if m:
                text = text[: m.start()]
            out.write(text if text.endswith("\n") or not text else text + "\n")
            out.flush()
            continue
        out.write("\n$ " + line + "\n")
        out.flush()
        os.write(fd, (line + "\n").encode("utf-8"))
        buf, ok = read_until(has_prompt, TIMEOUT)
        text = clean(buf)
        m = PROMPT.search(text)
        if m:
            text = text[: m.start()]
        elif alive[0]:
            text += "\n[drv] プロンプトが戻らない（%d 秒）。Ctrl-C を送った\n" % TIMEOUT
            os.write(fd, b"\x03")
            read_until(has_prompt, 10)
        if text and not text.endswith("\n"):
            text += "\n"
        out.write(text)
        out.flush()

    if alive[0]:
        try:
            os.write(fd, b"exit\n")
        except OSError:
            pass
        read_until(lambda b: False, 3)
    try:
        os.waitpid(pid, 0)
    except ChildProcessError:
        pass


if __name__ == "__main__":
    main()
