#!/usr/bin/env python3
"""章のテンプレートから、記録（logs/linuc-text-probe.log）の出力を埋めた HTML を作る。

  python3 probe/linuc-text-gen.py probe/linuc-text-tpl/*.tpl

本文の端末表示を手で写さないための道具。テンプレートには「$ コマンド」の行だけを書き、
出力はログからそのまま引く（1文字も書き換えない）。probe を取り直したら、これを回し直せば本文が追いつく。

テンプレートの書き方:
  <pre><code>@@
  $ コマンド                       ← ログの "$ コマンド" と完全に同じ文字列
  $ コマンド ⟪k=2⟫                 ← 章の中で2回目の記録を使う（省略時は、テンプレートの中で何回目に出てきたかで決める）
  $ コマンド ⟪out=1-3⟫             ← 出力の1〜3行目だけ（後ろに ... を付けるなら ⟪out=1-3,more⟫）
  $ コマンド ⟪noout⟫               ← コマンド行だけ
  $ コマンド ⟪note=2:説明⟫          ← 出力の2行目の行末に "   ← 説明" を付ける（cmd は note=0）
  そのまま写す行                   ← $ で始まらない行は手で書いたとおり出す（ログにある行か ... だけにする）
  @@</code></pre>
  {{SESSION a-b}}                  ← 対話の記録（pty の上で打鍵した部分）の a〜b 行目をそのまま写す
"""
import html, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
LOG = REPO / "logs" / "linuc-text-probe.log"
SESSION_BEGIN = "--- ここから下は、端末（pty）の上で対話シェルを動かし、1行ずつ打鍵した記録 ---"
SESSION_END = "--- 対話の記録ここまで ---"


def sections():
    secs, cur, name = {}, [], None
    for line in LOG.read_text(encoding="utf-8").split("\n"):
        m = re.match(r"^========== (\d+)\. ", line)
        if m:
            if name is not None:
                secs[name] = cur
            name, cur = int(m.group(1)), []
            continue
        if name is not None:
            cur.append(line)
    if name is not None:
        secs[name] = cur
    return secs


def records(lines):
    """[(cmd, [output lines])] と、対話の記録の行のリストを返す。"""
    recs, session, in_session, cur = [], [], False, None
    for line in lines:
        if line == SESSION_BEGIN:
            in_session = True
            cur = None
            continue
        if line == SESSION_END:
            in_session = False
            continue
        if in_session:
            session.append(line)
            continue
        if line.startswith("$ "):
            cur = (line[2:], [])
            recs.append(cur)
        elif cur is not None:
            cur[1].append(line)
    out = []
    for cmd, o in recs:
        while o and o[-1] == "":
            o.pop()
        # 章の区切り（次の章のログイン時の表示）を落とす
        if "── lab-linuc-text" in "\n".join(o):
            i = next(i for i, l in enumerate(o) if l.startswith("── lab-linuc-text"))
            o = o[:i]
            while o and o[-1] == "":
                o.pop()
        out.append((cmd, o))
    return out, session


def esc(s):
    return html.escape(s, quote=False)


def render_block(body, recs, ch, seen):
    out = []
    for raw in body.split("\n"):
        if not raw.startswith("$ "):
            out.append(esc(raw))
            continue
        m = re.match(r"^\$ (.*?)(?: ⟪(.*)⟫)?$", raw)
        cmd, opts = m.group(1), m.group(2) or ""
        k, rng, more, noout, notes = None, None, False, False, {}
        for o in [x.strip() for x in opts.split(";") if x.strip()]:
            if o.startswith("k="):
                k = int(o[2:])
            elif o.startswith("out="):
                spec = o[4:]
                if spec.endswith(",more"):
                    more, spec = True, spec[:-5]
                a, b = spec.split("-")
                rng = (int(a), int(b))
            elif o == "noout":
                noout = True
            elif o.startswith("note="):
                n, t = o[5:].split(":", 1)
                notes[int(n)] = t
            else:
                sys.exit(f"第{ch}章: 不明な指定 {o}")
        if k is None:                      # 指定が無ければ、章の中で何回目に出てきたかで決める
            k = seen.get(cmd, 0) + 1
        seen[cmd] = max(seen.get(cmd, 0), k)
        hits = [r for r in recs if r[0] == cmd]
        if len(hits) < k:
            sys.exit(f"第{ch}章: ログに無いコマンド（{k}回目）: $ {cmd}")
        _, o = hits[k - 1]
        line = "$ " + cmd
        if 0 in notes:
            line += "   ← " + notes[0]
        out.append(esc(line))
        if noout:
            continue
        sel = list(enumerate(o, 1))
        if rng:
            sel = [(i, l) for i, l in sel if rng[0] <= i <= rng[1]]
        for i, l in sel:
            if i in notes:
                l = l + "   ← " + notes[i]
            out.append(esc(l))
        if more:
            out.append("...")
    return "\n".join(out)


def main():
    secs = sections()
    for tpl in sys.argv[1:]:
        tpl = Path(tpl)
        ch = int(tpl.name[:2])
        recs, session = records(secs[ch])
        src = tpl.read_text(encoding="utf-8")

        seen = {}

        def blk(m):
            return "<pre><code>" + render_block(m.group(1).strip("\n"), recs, ch, seen) + "</code></pre>"

        src = re.sub(r"<pre><code>@@\n(.*?)\n@@</code></pre>", blk, src, flags=re.S)

        def ses(m):
            a, b = int(m.group(1)), int(m.group(2))
            return "\n".join(esc(l) for l in session[a - 1:b])

        src = re.sub(r"\{\{SESSION (\d+)-(\d+)\}\}", ses, src)
        if "@@" in src or "⟪" in src:
            sys.exit(f"{tpl.name}: 置き換え残りがある")
        dst = REPO / "public" / "linuc-text" / "theory" / tpl.name.replace(".tpl", "")
        dst.write_text(src, encoding="utf-8")
        print(f"{tpl.name} -> {dst}")


if __name__ == "__main__":
    main()
