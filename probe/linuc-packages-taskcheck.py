#!/usr/bin/env python3
"""LinuC 主題1.04: 課題文（containers/linuc-packages/*/lab/tasks/NN.md）の「いまの状態」の画面を、
読者と同じ打ち方で取った記録（logs/linuc-packages-{deb,rpm}-extra.log）と突き合わせる。

  python3 -I probe/linuc-packages-taskcheck.py           突き合わせる（違いがあれば終了コード 1）
  python3 -I probe/linuc-packages-taskcheck.py --fill    課題文の「@@名前@@」だけの行を、記録の出力で置き換えてから突き合わせる

記録は probe/linuc-packages-{deb,rpm}-extra.sh が取る（演習ごとに檻を起動し直し、lab start NN のあとに、
課題文の「いまの状態」に書いたコマンドを順に打つ）。課題文の画面は、4 桁下げた「$ コマンド」の行と、
その下の 4 桁下げた出力の行でできている（空行か、4 桁下げていない行で終わる）。
課題文は lab start がそのまま端末に出すので、画面と1文字でも違うと、読者は仕様か不具合かを判別できない
（2026-10-20、1.06 演習03 の指摘）。だから日時などを伏せずに、行ごとに完全一致で比べる。
"""
import re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
LABS = {"deb": REPO / "containers/linuc-packages/deb/lab/tasks", "rpm": REPO / "containers/linuc-packages/rpm/lab/tasks"}
HEAD = re.compile(r"^={10} 演習(\d\d) ={10}$")


def log_sections(cage):
    p = REPO / "logs" / f"linuc-packages-{cage}-extra.log"
    secs, cur, ent = {}, None, None
    for raw in p.read_text(encoding="utf-8").split("\n"):
        m = HEAD.match(raw.strip())
        if m:
            cur = secs.setdefault(m.group(1), [])
            ent = None
            continue
        if cur is None:
            continue
        if raw.startswith("$ "):
            ent = [raw[2:], []]
            cur.append(ent)
        elif ent is not None:
            ent[1].append(raw.rstrip())
    for v in secs.values():
        for e in v:
            while e[1] and e[1][-1] == "":
                e[1].pop()
    return secs


def task_screens(lines):
    """課題文の「いまの状態」の画面: [(行番号, コマンド, [出力の行番号...]), ...]"""
    res, i, n = [], 0, len(lines)
    start = next((k for k, l in enumerate(lines) if l.startswith("【いまの状態】")), None)
    end = next((k for k, l in enumerate(lines) if l.startswith("【やること】")), n)
    if start is None:
        return res
    i = start
    while i < end:
        m = re.match(r"^    \$ (.*)$", lines[i])
        if not m:
            i += 1
            continue
        cmd, j, outs = m.group(1), i + 1, []
        while j < end and lines[j].startswith("    ") and not lines[j].startswith("    $ "):
            outs.append(j)
            j += 1
        res.append((i, cmd, outs))
        i = j
    return res


def main():
    fill = "--fill" in sys.argv
    bad = 0
    for cage, d in LABS.items():
        secs = log_sections(cage)
        for f in sorted(d.glob("[0-9][0-9].md")):
            nn = f.stem
            lines = f.read_text(encoding="utf-8").split("\n")
            ents = [e for e in secs.get(nn, []) if not e[0].startswith("lab start ")]
            screens = task_screens(lines)
            if fill:
                for (i, cmd, outs), e in zip(screens, ents):
                    if len(outs) == 1 and re.fullmatch(r"    @@\w+@@", lines[outs[0]]):
                        lines[outs[0]] = "\n".join("    " + o if o else "" for o in e[1])
                f.write_text("\n".join(lines), encoding="utf-8")
                lines = f.read_text(encoding="utf-8").split("\n")
                screens = task_screens(lines)
            probs = []
            if len(screens) != len(ents):
                probs.append(f"コマンドの数が違う（課題文 {len(screens)} / 記録 {len(ents)}）")
            for (i, cmd, outs), e in zip(screens, ents):
                if cmd != e[0]:
                    probs.append(f"{i+1} 行目のコマンドが違う（課題文 {cmd!r} / 記録 {e[0]!r}）")
                    continue
                got = [lines[k][4:].rstrip() for k in outs]
                want = [o for o in e[1]]
                if got != want:
                    probs.append(f"{i+1} 行目 $ {cmd}: 画面が違う\n      課題文: {got}\n      記録  : {want}")
            mark = "✔" if not probs else "✗"
            print(f"{mark} {cage} 演習{nn}: 画面 {len(screens)} 組" + ("" if not probs else ""))
            for p in probs:
                print("    " + p)
            bad += len(probs)
    print(f"違い {bad} 件")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
