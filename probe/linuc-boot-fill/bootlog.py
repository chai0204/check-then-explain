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

def chunk(chap, title, start=None, end=None, raw=False, tail=None, squeeze=False):
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
    seg = ls[i:j]
    while seg and seg[-1] == '': seg.pop()
    t = '\n'.join(seg)
    return t if raw else html.escape(t, quote=False)

def pre(where, text):
    return f'<pre data-where="{where}"><code>{text}</code></pre>'
