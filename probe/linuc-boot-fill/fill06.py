import pathlib as _pl, sys as _sys
_HERE = _pl.Path(__file__).resolve().parent
REPO = _HERE.parent.parent
_sys.path.insert(0, str(_HERE))
import sys
from bootlog import chunk, pre
CON = '外（lab@host）・練習機のコンソール'
P = str(REPO / 'public/linuc-boot/theory/06-target.html')
edit = chunk('06b', 'linux の行末に systemd.unit=rescue.target を足した（折り返す）', squeeze=True)
shell = chunk('06b', 'Enter を押した後（rescue.target の root のシェル）', tail=5)
longparam = f'''<p><b>長い語を足すとき</b>: <code>single</code> の代わりに <code>systemd.unit=rescue.target</code>（27 文字）を足すこともできる。
ただし、この練習機のコンソール（シリアル 80 桁）では、linux の行の2段目の残りは 20 桁ほどしかなく、長い語は右端の <code>\\</code> で次の段に折り返して表示される。</p>
<pre data-where="{CON}（GRUB の編集画面）"><code>{edit}</code></pre>
<p>行が二重に見えるのは、先に見た描き直しの乱れである。<code>Ctrl+X</code> で起動して Enter を押し、入った root のシェルで、カーネルが受け取った引数を確かめる。</p>
<pre data-where="{CON}（rescue.target の root のシェル）"><code>{shell}</code></pre>
<p>この回は、足した語がそのままカーネルに渡り（<code>/proc/cmdline</code> の最後。80 桁で折り返して表示されている）、rescue.target に入った。
折り返した画面では打ち間違えに気づきにくいので、長い語を足したら、入った後に <code>/proc/cmdline</code> で確かめる。この本の演習で短い語（<code>single</code>・<code>3</code>）を使うのはそのためである。</p>'''
BLOCKS = {'LONGPARAM': longparam}
if __name__ == '__main__':
    import bootfill
    bootfill.apply(P, BLOCKS)
    print('ok')
