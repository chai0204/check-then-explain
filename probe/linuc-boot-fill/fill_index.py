import pathlib as _pl, sys as _sys
_HERE = _pl.Path(__file__).resolve().parent
REPO = _HERE.parent.parent
_sys.path.insert(0, str(_HERE))
import sys
from bootlog import chunk
P = str(REPO / 'public/linuc-boot/practice/index.html')
env = f'''<pre data-where="外（lab@host）"><code>{chunk('00', 'lab env（練習機が動いているとき）')}</code></pre>'''
BLOCKS = {'LAB_ENV': env}
if __name__ == '__main__':
    import bootfill, re
    s = open(P, encoding='utf-8').read()
    if '<!-- LAB_ENV -->' in s:   # 初回だけ: 置き場所の印を、作り直せる形の印にそろえる
        s = s.replace('<!-- LAB_ENV -->', '<!-- LAB_ENV_BLOCK -->')
        open(P, 'w', encoding='utf-8').write(s)
    bootfill.apply(P, BLOCKS)
    print('ok')
