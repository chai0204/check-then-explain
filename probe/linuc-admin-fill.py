#!/usr/bin/env python3
"""章のひな形（probe/linuc-admin-tpl/NN-*.html）の @@ 行を、probe の記録（logs/linuc-admin-probe.log）から埋めて
public/linuc-admin/theory/ に書き出す。端末表示を手で写さないための道具（写し間違いを構造的に無くす）。

ひな形の書き方（行頭が @@ の行だけが置き換わる。ほかの行はそのまま出る）:
  @@ <コマンド>                     → "$ <コマンド>" と、記録にあるその出力を全部
  @@ <コマンド>  ## noout           → "$ <コマンド>" だけ（出力は出さない）
  @@ <コマンド>  ## outonly         → 出力だけ
  @@ <コマンド>  ## lines=3-8       → 出力の3〜8行目だけ（前後を削ったら "..." を入れる）
  @@ <コマンド>  ## grep=正規表現   → 出力のうち一致する行だけ（間を削ったら "..."）
  @@ <コマンド>  ## n=2             → 記録の中で2回目に出てくるものを使う
  @@ <コマンド>  ## sub             → 記録の "$ " 行に部分文字列として含まれるものを使う（`a; b` を本文で分けて見せるとき）
  @@note <部分文字列> => <注記>      → 直前に出した行のうち、部分文字列を含む最後の行の末尾に "   ← 注記"
  @@rhel <コマンド>                  → 比較の記録（logs/linuc-admin-rhel-compare.log。AlmaLinux 9.7）から同じように埋める
コマンドは記録の "$ " 行と完全一致で探す。前回見つけた位置より後ろから探し、無ければ先頭から探す。
"""
import html
import pathlib
import re
import sys

# 使い方: probe を取り直したら  python3 probe/linuc-admin-fill.py  で、章と実践編の入口を記録から作り直す。
#         そのあと node tools/logcheck.mjs linuc-admin --strict で照合する（本文の文章は手で書いたまま変わらない）。
HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent
LOG = REPO / 'logs' / 'linuc-admin-probe.log'
TPL = HERE / 'linuc-admin-tpl'
OUT = REPO / 'public' / 'linuc-admin' / 'theory'


def parse_log(text):
    recs, cur = [], None
    for line in text.split('\n'):
        if line.startswith('$ '):
            if cur:
                recs.append(cur)
            cur = [line[2:], []]
        elif line.startswith('==========') or line.startswith('##########'):
            if cur:
                recs.append(cur)
            cur = None
        elif cur is not None:
            cur[1].append(line)
    if cur:
        recs.append(cur)
    out = []
    for c, o in recs:
        while o and o[-1].strip() == '':
            o.pop()
        out.append((c, [l.rstrip() for l in o]))
    return out


RECS = parse_log(LOG.read_text(encoding='utf-8'))
RHEL_LOG = REPO / 'logs' / 'linuc-admin-rhel-compare.log'
RECS_RHEL = parse_log(RHEL_LOG.read_text(encoding='utf-8')) if RHEL_LOG.exists() else []
cursor = 0
errors = []


def find(cmd, nth=None, sub=False, recs=None):
    global cursor
    if recs is not None:   # 比較の記録は、カーソルを持たずに完全一致の n 番目（既定は最初）を使う
        hits = [(c, o) for c, o in recs if c == cmd]
        if len(hits) < (nth or 1):
            errors.append(f'比較の記録に無いコマンド: {cmd}')
            return None
        return hits[(nth or 1) - 1]
    # sub: 記録では `a; b` と1回で打ったものを、本文で b だけ見せるとき（照合ツールと同じく部分一致で探す）
    idx = [i for i, (c, _) in enumerate(RECS) if (cmd in c if sub else c == cmd)]
    if not idx:
        errors.append(f'記録に無いコマンド: {cmd}')
        return None
    if nth:
        i = idx[nth - 1]
    else:
        after = [i for i in idx if i >= cursor]
        i = after[0] if after else idx[0]
        if not after:
            print(f'  注意: 前方に無いので先頭から: {cmd}', file=sys.stderr)
    cursor = i + 1
    return RECS[i]


def esc(s):
    return html.escape(s, quote=False)


def select(out, opts):
    if 'lines' in opts:
        a, b = (int(x) for x in opts['lines'].split('-'))
        sel = out[a - 1:b]
        if a > 1:
            sel = ['...'] + sel
        if b < len(out):
            sel = sel + ['...']
        return sel
    if 'grep' in opts:
        rx = re.compile(opts['grep'])
        res, last = [], -2
        for i, l in enumerate(out):
            if rx.search(l):
                if i != last + 1:
                    res.append('...') if (res or i > 0) else None
                res.append(l)
                last = i
        if last != len(out) - 1 and res:
            res.append('...')
        return res
    return out


def process(text):
    lines_out = []
    for line in text.split('\n'):
        if line.startswith('@@note '):
            m = re.match(r'@@note (.+?) => (.+)$', line)
            sub, note = m.group(1), m.group(2)
            for k in range(len(lines_out) - 1, -1, -1):
                if html.unescape(lines_out[k]).find(sub) >= 0:
                    lines_out[k] = lines_out[k] + '   ← ' + note
                    break
            else:
                errors.append(f'注記の相手が見つからない: {sub}')
            continue
        rhel = line.startswith('@@rhel ')
        if line.startswith('@@ ') or rhel:
            body = line[7:] if rhel else line[3:]
            opts = {}
            if '  ## ' in body:
                body, o = body.split('  ## ', 1)
                for tok in o.split():
                    if '=' in tok:
                        k, v = tok.split('=', 1)
                        opts[k] = v
                    else:
                        opts[tok] = True
            cmd = body.rstrip()
            rec = find(cmd, int(opts['n']) if 'n' in opts else None, sub=('sub' in opts),
                       recs=(RECS_RHEL if rhel else None))
            if rec is None:
                lines_out.append('$ ' + esc(cmd) + '   ← ★記録に無い')
                continue
            if 'outonly' not in opts:
                lines_out.append('$ ' + esc(cmd))
            if 'noout' not in opts:
                for l in select(rec[1], opts):
                    lines_out.append(esc(l))
            continue
        lines_out.append(line)
    res = '\n'.join(lines_out)
    # ひな形では <code> の直後と </code> の直前で改行しているので、そこを詰める（pre の先頭に空行を出さない）
    res = re.sub(r'(<pre\b[^>]*><code>)\n', r'\1', res)
    res = re.sub(r'\n(</code></pre>)', r'\1', res)
    return res


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    only = sys.argv[1:] or None
    for t in sorted(TPL.glob('*.html')):
        if only and not any(t.name.startswith(o) for o in only):
            continue
        res = process(t.read_text(encoding='utf-8'))
        # 00- で始まるひな形は実践編の入口（public/linuc-admin/index.html）。記録の先頭（環境・ログイン）を使うので最初に処理される
        dest = (OUT.parent / 'index.html') if t.name.startswith('00-') else (OUT / t.name)
        dest.write_text(res, encoding='utf-8')
        print(f'書いた: {dest}')
    if errors:
        print('\n'.join('✗ ' + e for e in errors))
        sys.exit(1)


main()
