#!/usr/bin/env python3
"""章のテンプレートの端末ブロックに、記録（logs/linuc-security-probe.log）の出力をそのまま埋めて章の HTML を作る。

  python3 -I probe/linuc-security-gen.py

本文の端末表示を手で写さないための道具（1.0.1 で導入）。1.0.0 は手で写しており、TAB を含む出力
（chage -l）を避けたり、行の取り違えが起きたりした。テンプレートには「$ コマンド」の行だけを書き、
出力は記録から1文字も変えずに引く。probe を取り直したら、これを回し直せば本文が追いつく。

入力:  probe/linuc-security-tpl/NN-名前.html.tpl
出力:  public/linuc-security/theory/NN-名前.html

テンプレートの書き方（<pre …><code>@@ と @@</code></pre> で囲んだ中だけが置き換わる）:
  $ コマンド                記録の「$ コマンド」と完全に同じ文字列。章番号と同じ節（========== N. …）の記録から引く。
                            同じコマンドが節に何度も出るときは、テンプレートの中で何回目に書いたかの順で引く
  $ コマンド ⟪k=2⟫           節の中の2回目の記録を使う
  $ コマンド ⟪out=1-3,5⟫     出力の1〜3行目と5行目だけ。"..." を並べるとその位置に ... の行を入れる
  $ コマンド ⟪noout⟫         コマンド行だけ（出力は載せない）
  $ コマンド ⟪sec=4⟫         別の節（4）の記録から引く
  $ コマンド ⟪pre=（3 秒待つ）⟫ 出力の前に、その1行（（…）か ... の形にする）を入れる。照合では飛ばされる
  オプションは ; で並べる（例: ⟪k=2; out=1-3⟫）
  それ以外の行              そのまま出す（... や（…）の行だけにする。記録に無い出力を書かない）
"""
import html
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
LOG = REPO / "logs" / "linuc-security-probe.log"
TPL = REPO / "probe" / "linuc-security-tpl"
OUT = REPO / "public" / "linuc-security" / "theory"


def load_sections(path):
    """{節番号: [(コマンド, [出力の行])]}"""
    secs, cur, num = {}, None, None
    for line in path.read_text(encoding="utf-8").split("\n"):
        m = re.match(r"^========== (\d+)\. ", line)
        if m:
            num = int(m.group(1))
            secs.setdefault(num, [])
            cur = None
            continue
        if num is None:
            continue
        if line.startswith("$ "):
            cur = (line[2:], [])
            secs[num].append(cur)
        elif cur is not None:
            cur[1].append(line)
    for recs in secs.values():
        for _, out in recs:
            while out and out[-1].strip() == "":
                out.pop()
    return secs


def pick(out, spec):
    res = []
    for part in spec.split(","):
        part = part.strip()
        if part == "...":
            res.append("...")
        elif "-" in part:
            a, b = (int(x) for x in part.split("-"))
            res.extend(out[a - 1:b])
            if b > len(out):
                raise SystemExit(f"out={spec}: 出力は {len(out)} 行しかない")
        else:
            i = int(part)
            if i > len(out):
                raise SystemExit(f"out={spec}: 出力は {len(out)} 行しかない")
            res.append(out[i - 1])
    return res


def render_block(body, chapter, secs, seen):
    lines_out = []
    for raw in body.split("\n"):
        if not raw.startswith("$ "):
            lines_out.append(raw)
            continue
        opts = {}
        m = re.match(r"^\$ (.*?)(?:\s*⟪(.*)⟫)?$", raw)
        cmd = m.group(1)
        if m.group(2):
            for kv in m.group(2).split(";"):
                kv = kv.strip()
                if "=" in kv:
                    k, v = kv.split("=", 1)
                    opts[k.strip()] = v.strip()
                elif kv:
                    opts[kv] = True
        sec = int(opts.get("sec", chapter))
        recs = [r for r in secs.get(sec, []) if r[0] == cmd]
        if not recs:
            raise SystemExit(f"第{chapter}章: 節 {sec} の記録に無いコマンド: $ {cmd}")
        if "k" in opts:
            k = int(opts["k"])
        else:
            key = (sec, cmd)
            seen[key] = seen.get(key, 0) + 1
            k = seen[key]
        if k > len(recs):
            raise SystemExit(f"第{chapter}章: $ {cmd} の記録は {len(recs)} 回しかない（{k} 回目を求めた）")
        out = recs[k - 1][1]
        lines_out.append("$ " + html.escape(cmd, quote=False))
        if "noout" in opts:
            continue
        if "pre" in opts:
            lines_out.append(opts["pre"])
        sel = pick(out, opts["out"]) if "out" in opts else out
        lines_out.extend(l if l == "..." else html.escape(l, quote=False) for l in sel)
    return "\n".join(lines_out)


def main():
    secs = load_sections(LOG)
    tpls = sorted(TPL.glob("*.html.tpl"))
    if not tpls:
        raise SystemExit(f"テンプレートがありません: {TPL}")
    for tpl in tpls:
        m = re.match(r"^(\d+)-", tpl.name)
        chapter = int(m.group(1))
        src = tpl.read_text(encoding="utf-8")
        seen = {}
        res = re.sub(r"(<pre[^>]*><code>)@@\n(.*?)\n@@(</code></pre>)",
                     lambda mm: mm.group(1) + render_block(mm.group(2), chapter, secs, seen) + mm.group(3),
                     src, flags=re.S)
        if "@@" in res:
            raise SystemExit(f"{tpl.name}: 置き換わらなかった @@ がある")
        dst = OUT / tpl.name[: -len(".tpl")]
        dst.write_text(res, encoding="utf-8")
        print(f"  {tpl.name} → {dst.relative_to(REPO)}")


if __name__ == "__main__":
    main()
