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

  追加の記録（logs/linuc-text-probe-extra.log。事実確認で直した箇所の裏付け）から引くときは、
  ブロックを <pre><code>@@+ … @@</code></pre>、対話の記録を {{SESSION+ a-b}} と書く。
  試験対策の追加の記録（logs/linuc-text-probe-exam.log）からは <pre><code>@@exam … @@</code></pre> と
  {{SESSION@exam a-b}}。

  通しの記録（logs/linuc-text-seq.log。読者と同じ起動の1つのシェルで第1章から順に打った記録）からは
  <pre><code>@@seq … @@</code></pre>。端末に出したときだけ変わる表示（ls の段組みや、空白を含む名前の引用符）と、
  前の章の状態がそろっていて初めて打てる行（章の終わりの後片付け）に使う。何回目の記録を使うかは、
  その章の中で（どの記録から引くブロックも含めて）何回目に出てきたかで決める。通しの記録は本文から作るので、
  @@seq に新しい行を足したときは LINUC_TEXT_SEQ_BOOTSTRAP=1 で一度作り（通しにまだ無い行は、ほかの記録に
  同じコマンドがあればその出力を仮に置き、無ければ出力を空にする。vim の「打鍵」の行が通しの入力になるため）、
  bash probe/linuc-text-run.sh seq で通しを取り直す（章も作り直される）。
"""
import os
import html, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
LOG = REPO / "logs" / "linuc-text-probe.log"
EXTRA = REPO / "logs" / "linuc-text-probe-extra.log"
EXAM = REPO / "logs" / "linuc-text-probe-exam.log"
SEQ = REPO / "logs" / "linuc-text-seq.log"
BOOTSTRAP = os.environ.get("LINUC_TEXT_SEQ_BOOTSTRAP") == "1"
FALLBACK = []        # 仮の版を作るときに使う、その章のほかの記録（main / extra / exam）
SESSION_BEGIN = "--- ここから下は、端末（pty）の上で対話シェルを動かし、1行ずつ打鍵した記録 ---"
SESSION_END = "--- 対話の記録ここまで ---"


def sections(path=LOG):
    secs, cur, name = {}, [], None
    if not path.exists():
        return secs
    for line in path.read_text(encoding="utf-8").split("\n"):
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


def render_block(body, recs, ch, seen, fixed_k=None):
    """fixed_k: @@seq のとき、ブロックの中の各コマンドに使う記録の番号（章の中で何回目か）を順に入れたリスト。"""
    out = []
    fixed_k = list(fixed_k) if fixed_k is not None else None
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
        if fixed_k is not None:            # @@seq: 章の中で何回目か（どの記録から引くブロックも数える）
            fk = fixed_k.pop(0)
            k = k or fk
        if k is None:                      # 指定が無ければ、章の中で何回目に出てきたかで決める
            k = seen.get(cmd, 0) + 1
        seen[cmd] = max(seen.get(cmd, 0), k)
        hits = [r for r in recs if r[0] == cmd]
        if len(hits) < k and fixed_k is not None and BOOTSTRAP:
            # 通しを取り直すための仮の版。ほかの記録に同じコマンドがあればその出力を仮に置く
            # （vim の「打鍵」の行は通しの入力になるので、ここで落とすと通しが打てない）
            alt = [r for r in FALLBACK if r[0] == cmd]
            print(f"第{ch}章: 通しの記録にまだ無い（{'ほかの記録の出力を仮に置いた' if alt else '出力を空のまま作った'}）: $ {cmd}",
                  file=sys.stderr)
            out.append(esc("$ " + cmd))
            out.extend(esc(l) for l in (alt[0][1] if alt else []))
            continue
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
    xsecs = sections(EXTRA)
    esecs = sections(EXAM)
    ssecs = sections(SEQ)
    for tpl in sys.argv[1:]:
        tpl = Path(tpl)
        ch = int(tpl.name[:2])
        recs, session = records(secs[ch])
        xrecs, xsession = records(xsecs.get(ch, []))
        erecs, esession = records(esecs.get(ch, []))
        srecs, _ = records(ssecs.get(ch, []))
        FALLBACK[:] = recs + xrecs + erecs
        src = tpl.read_text(encoding="utf-8")

        src_recs = {"": (recs, {}), "+": (xrecs, {}), "exam": (erecs, {}), "seq": (srecs, {})}
        src_ses = {"": session, "+": xsession, "@exam": esession}

        # 章の中のコマンドを、本文に出る順に数える（@@ のブロックと {{SESSION}} の "$ " 行）。@@seq の記録の番号に使う
        chapter_seen, seq_ks = {}, []
        tok = re.compile(r"<pre><code>@@(\+|exam|seq)?\n(.*?)\n@@</code></pre>|\{\{SESSION(\+|@exam)? (\d+)-(\d+)\}\}", re.S)
        for m in tok.finditer(src):
            if m.group(2) is not None:
                cmds = [re.match(r"^\$ (.*?)(?: ⟪(.*)⟫)?$", l).group(1)
                        for l in m.group(2).split("\n") if l.startswith("$ ")]
            else:
                lines = src_ses[m.group(3) or ""][int(m.group(4)) - 1:int(m.group(5))]
                cmds = [l[2:] for l in lines if l.startswith("$ ")]
            ks = []
            for c in cmds:
                chapter_seen[c] = chapter_seen.get(c, 0) + 1
                ks.append(chapter_seen[c])
            if m.group(1) == "seq":
                seq_ks.append(ks)

        def blk(m):
            r, seen = src_recs[m.group(1) or ""]
            fixed = seq_ks.pop(0) if m.group(1) == "seq" else None
            return "<pre><code>" + render_block(m.group(2).strip("\n"), r, ch, seen, fixed) + "</code></pre>"

        src = re.sub(r"<pre><code>@@(\+|exam|seq)?\n(.*?)\n@@</code></pre>", blk, src, flags=re.S)

        def ses(m):
            lines = src_ses[m.group(1) or ""]
            a, b = int(m.group(2)), int(m.group(3))
            return "\n".join(esc(l) for l in lines[a - 1:b])

        src = re.sub(r"\{\{SESSION(\+|@exam)? (\d+)-(\d+)\}\}", ses, src)
        if "@@" in src or "⟪" in src:
            sys.exit(f"{tpl.name}: 置き換え残りがある")
        dst = REPO / "public" / "linuc-text" / "theory" / tpl.name.replace(".tpl", "")
        dst.write_text(src, encoding="utf-8")
        print(f"{tpl.name} -> {dst}")


if __name__ == "__main__":
    main()
