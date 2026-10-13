"""linuc-boot の記録から、画面の写しの一部をそのまま（HTML エスケープして）取り出す。章の下書き用。"""
import pathlib as _pl, sys as _sys
_HERE = _pl.Path(__file__).resolve().parent
REPO = _HERE.parent.parent
_sys.path.insert(0, str(_HERE))

import html, pathlib, re
import os
LOGS = pathlib.Path(os.environ.get('BOOTLOGS', str(REPO / 'logs')))
HEAD = re.compile(r'^# --- 画面の写し(?:（見えている範囲）)?: (.*) ---$')

def records(chap):
    p = sorted(LOGS.glob(f'linuc-boot-{chap}-*.log'))
    out, cur = {}, None
    for path in p:
        for line in path.read_text(encoding='utf-8').split('\n'):
            m = HEAD.match(line)
            if m:
                cur = []; out[m.group(1)] = cur; continue
            if line == '# --- ここまで ---':
                cur = None; continue
            if cur is not None:
                cur.append(line.rstrip())
    for ls in out.values():
        while ls and (ls[-1] == '' or ls[-1] == '$'): ls.pop()
        while ls and ls[0] == '': ls.pop(0)
    return out

def chunk(chap, title, start=None, end=None, raw=False, tail=None, squeeze=False, stop_before=None):
    """start のコマンド行から、end のコマンドの出力の終わりまで（end を省くと最後まで）。
    tail=N なら最後の N 行だけ。squeeze なら空行の連続を1行にする（画面の写しの余白）。先頭の空のプロンプト（"$"）は落とす。"""
    ls = list(records(chap)[title])
    while ls and ls[0] in ('$', ''):
        ls.pop(0)
    if tail:
        ls = ls[-tail:]
    if squeeze:
        out = []
        for l in ls:
            if l == '' and out and out[-1] == '':
                continue
            out.append(l)
        ls = out
    i = 0
    if start is not None:
        i = next(k for k, l in enumerate(ls) if l == '$ ' + start)
    j = len(ls)
    if end is not None:
        e = next(k for k, l in enumerate(ls) if k >= i and l == '$ ' + end)
        j = next((k for k in range(e + 1, len(ls)) if ls[k].startswith('$ ')), len(ls))
    if stop_before is not None:   # stop_before のコマンド行（完全一致）の手前で終える
        j = next(k for k in range(i + 1, len(ls)) if ls[k] == '$ ' + stop_before)
    seg = ls[i:j]
    while seg and seg[-1] == '': seg.pop()
    t = '\n'.join(seg)
    return t if raw else html.escape(t, quote=False)

def pre(where, text):
    return f'<pre data-where="{where}"><code>{text}</code></pre>'


def lines_from(chap, title, first_regex, last_regex=None, raw=False):
    """写しの中で first_regex に合う最後の行から（同じ写しに何度も出るときは最後のもの）、last_regex に合う行まで（省くと最後まで）。"""
    ls = list(records(chap)[title])
    i = max(k for k, l in enumerate(ls) if re.search(first_regex, l))
    j = len(ls)
    if last_regex:
        j = next(k for k in range(i, len(ls)) if re.search(last_regex, ls[k])) + 1
    t = '\n'.join(ls[i:j])
    return t if raw else html.escape(t, quote=False)


def pick(chap, title, patterns, raw=False):
    """写しの行のうち、patterns（正規表現の並び）に順に合う最初の行だけを拾い、間を飛ばしたところに（略）を入れる。"""
    ls = list(records(chap)[title])
    out, k = [], 0
    for p in patterns:
        j = next(n for n in range(k, len(ls)) if re.search(p, ls[n]))
        if j > k and out:
            out.append('（略）')
        out.append(ls[j])
        k = j + 1
    t = '\n'.join(out)
    return t if raw else html.escape(t, quote=False)


def rhel_chunk(start, end, raw=False):
    """比べるための記録（logs/linuc-boot-rhel-compare.log。"$ " 行と出力だけの形）から、start のコマンドから end のコマンドの出力の終わりまで。
    コマンドの前に記録の道具が入れた空行（区切り）は落とす。"""
    ls = [l.rstrip() for l in (LOGS / 'linuc-boot-rhel-compare.log').read_text(encoding='utf-8').split('\n')]
    i = ls.index('$ ' + start)
    e = next(k for k in range(i, len(ls)) if ls[k] == '$ ' + end)
    j = next((k for k in range(e + 1, len(ls)) if ls[k].startswith('$ ') or ls[k].startswith('==========')), len(ls))
    seg = ls[i:j]
    out = [l for n, l in enumerate(seg) if not (l == '' and n + 1 < len(seg) and seg[n + 1].startswith('$ '))]
    while out and out[-1] == '':
        out.pop()
    t = '\n'.join(out)
    return t if raw else html.escape(t, quote=False)
