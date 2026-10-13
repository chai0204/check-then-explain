#!/usr/bin/env python3
"""linuc-boot の章（public/linuc-boot/theory/NN-*.html）の端末ブロックを、取り直した記録（logs/linuc-boot-NN-*.log）から
写し直す。端末表示を手で書き換えないための道具（PID・時刻・UUID が変わっても、記録からそのまま引き直す）。

  python3 probe/linuc-boot-sync.py          … 何が変わるかを報告するだけ（書き換えない）
  python3 probe/linuc-boot-sync.py --write  … 書き換える

1) "$ " 行を含むブロック: ブロックのコマンド列を、同じ章の記録の「画面の写し」1つの中で連続して探し、
   「最初のコマンドの行から、最後のコマンドの出力の終わりまで」で置き換える。
2) 本文で出力を間引いていた組（"（略）" などで一部だけ見せている組）と、"$ " 行の無いブロック（コンソールの画面。data-where 付きのもの）は、
   本文の各行を「数字の部分だけ違ってよい」形で記録の行に順番どおり対応させ、対応した記録の行に置き換える。
   "（略）" "..." の行はそのまま残す。対応が取れない行が1つでもあれば置き換えず、報告する（手で直す）。
"""
import html
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
THEORY = REPO / 'public' / 'linuc-boot' / 'theory'
LOGS = REPO / 'logs'
WRITE = '--write' in sys.argv
HEAD = re.compile(r'^# --- 画面の写し(?:（見えている範囲）)?: (.*) ---$')
SKIP = re.compile(r'^(\.\.\.|…|（[^）]*）|\([^)]*略[^)]*\))$')


def records(path):
    out, cur = [], None
    for line in path.read_text(encoding='utf-8').split('\n'):
        m = HEAD.match(line)
        if m:
            cur = (m.group(1), [])
            out.append(cur)
            continue
        if line == '# --- ここまで ---':
            cur = None
            continue
        if cur is not None:
            cur[1].append(line.rstrip())
    for _, ls in out:
        while ls and (ls[-1] == '' or ls[-1] == '$'):
            ls.pop()
        while ls and ls[0] in ('', '$'):
            ls.pop(0)
    return out


def groups(lines):
    gs = [[None, []]]
    for l in lines:
        if l.startswith('$ '):
            gs.append([l, []])
        else:
            gs[-1][1].append(l)
    if not any(x.strip() for x in gs[0][1]):
        gs.pop(0)
    return gs


q = lambda s: s.replace('"', "'")
nonblank = lambda ls: [x for x in ls if x.strip() and not SKIP.match(x.strip())]


def shape(line):
    """数字（と数字を含む16進の並び）・空白の幅だけが違ってよい、という正規表現にする。"""
    toks = line.strip().split()
    pats = []
    for t in toks:
        parts = re.split(r'([0-9A-Fa-f]*\d[0-9A-Fa-f]*)', t)
        p = ''.join('[0-9A-Fa-f]+' if (i % 2 == 1) else re.escape(x) for i, x in enumerate(parts))
        pats.append(p)
    return re.compile(r'^\s*' + r'\s+'.join(pats) + r'\s*$')


def align(book, rec):
    """本文の行（"（略）" を含む）を、記録の行へ順番どおりに対応させる。全部取れたら置き換え後の行を返す。"""
    out, k = [], 0
    for b in book:
        if b.strip() == '' or SKIP.match(b.strip()):
            out.append(b)
            continue
        rx = shape(b)
        j = k
        while j < len(rec) and not (rec[j] == b or rx.match(rec[j])):
            j += 1
        if j == len(rec):
            return None, b
        out.append(rec[j])
        k = j + 1
    return out, None


def main():
    chap = {}
    for p in sorted(LOGS.glob('linuc-boot-[0-9][0-9]*-*.log')):
        n = p.name.split('-')[2][:2]
        chap.setdefault(n, []).extend(records(p))
    total = changed = 0
    report = []
    for f in sorted(THEORY.glob('[0-9][0-9]-*.html')):
        n = f.name[:2]
        src = f.read_text(encoding='utf-8')
        recs = chap.get(n, [])
        out, pos = [], 0
        for m in re.finditer(r'(<pre\b[^>]*><code>)(.*?)(</code></pre>)', src, re.S):
            out.append(src[pos:m.start()])
            pos = m.end()
            body = html.unescape(m.group(2))
            lines = body.split('\n')
            new_lines, why = None, None
            if any(l.startswith('$ ') for l in lines):
                total += 1
                bg = groups(lines)
                lead = [] if bg[0][0] else bg.pop(0)[1]
                want = [q(c) for c, _ in bg]
                best = None
                for title, rl in recs:
                    rg = groups(rl)
                    cmds = [q(c) if c else None for c, _ in rg]
                    for i in range(len(cmds) - len(want) + 1):
                        if cmds[i:i + len(want)] != want:
                            continue
                        seg = rg[i:i + len(want)]
                        res, fail = [], None
                        for (bc, bo), (rc, ro) in zip(bg, seg):
                            res.append(rc)
                            if len(nonblank(bo)) < len(nonblank(ro)) or any(SKIP.match(x.strip()) for x in bo if x.strip()):
                                al, bad = align(bo, ro)       # 本文で間引いた組: 本文の行を記録の行へ対応させる
                                if al is None:
                                    fail = f'{bc} の出力「{bad}」が記録に対応しない'
                                    break
                                res.extend(al)
                            else:
                                res.extend(ro)
                        score = sum(1 for (bc, bo), (rc, ro) in zip(bg, seg) for x in bo if x in ro)
                        cand = (fail is None, score, title, res, fail)
                        if best is None or cand[:2] > best[:2]:
                            best = cand
                if best is None:
                    why = f'コマンド列が記録に見つからない: {bg[0][0]} …（{len(bg)} 組）'
                elif not best[0]:
                    why = f'「{best[2]}」: {best[4]}'
                else:
                    new_lines = list(lead) + best[3]
                    while new_lines and new_lines[-1] == '':
                        new_lines.pop()
                    src_title = best[2]
            else:
                # コンソールの画面などのブロック（"$ " 行なし）。いちばん良く対応する写しを探す
                # data-where の無い <pre>（打つコマンドの一覧・図）は記録ではないので見ない
                if not nonblank(lines) or 'data-where=' not in m.group(1):
                    out.append(m.group(0))
                    continue
                total += 1
                best = None
                for title, rl in recs:
                    al, bad = align(lines, rl)
                    if al is None:
                        continue
                    score = sum(1 for a, b in zip(lines, al) if a == b)
                    if best is None or score > best[0]:
                        best = (score, title, al)
                if best is None:
                    why = f'画面のブロックが記録に対応しない: {lines[0][:60]}'
                else:
                    new_lines, src_title = best[2], best[1]
            if new_lines is None:
                report.append(f'{f.name}: ✗ 置き換えない: {why}')
                out.append(m.group(0))
                continue
            new_body = html.escape('\n'.join(new_lines), quote=False)
            if new_body != m.group(2):
                changed += 1
                old = body.split('\n')
                ndiff = sum(1 for a, b in zip(old, new_lines) if a != b) + abs(len(old) - len(new_lines))
                report.append(f'{f.name}: 置き換え: {lines[0][:50]} …（「{src_title}」、{ndiff} 行）')
                out.append(m.group(1) + new_body + m.group(3))
            else:
                out.append(m.group(0))
        out.append(src[pos:])
        if WRITE:
            f.write_text(''.join(out), encoding='utf-8')
    for x in report:
        print(x)
    print(f'端末・画面ブロック {total} / 置き換え {changed} / 置き換えられない {sum(1 for x in report if "✗" in x)}'
          + ('（書き換えた）' if WRITE else '（--write で書き換える）'))


main()
