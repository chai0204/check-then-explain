import pathlib as _pl, sys as _sys
_HERE = _pl.Path(__file__).resolve().parent
REPO = _HERE.parent.parent
_sys.path.insert(0, str(_HERE))
import sys
from bootlog import chunk, pre, rhel_chunk
CON = '外（lab@host）・練習機のコンソール'
P = str(REPO / 'public/linuc-boot/theory/06-target.html')
from bootlog import records as _records
_r06 = _records('06')
edit = chunk('06', 'linux の行末に systemd.unit=rescue.target を足した（折り返す）', squeeze=True)
_edit_raw = chunk('06', 'linux の行末に systemd.unit=rescue.target を足した（折り返す）', raw=True).split('\n')
# 編集画面で、足した語のあたり（console=ttyS0,115200 の後ろと、その次の段）を拾う
_k = max(i for i, l in enumerate(_edit_raw) if 'console=ttyS0,115200' in l)
_typed = _edit_raw[_k].split('console=ttyS0,115200', 1)[1].strip().rstrip('│').rstrip('\\').strip() + _edit_raw[_k + 1].strip().strip('│').strip()
if 'Enter を押した後（rescue.target の root のシェル）' in _r06:
    shell = chunk('06', 'Enter を押した後（rescue.target の root のシェル）', tail=5)
    longparam = f'''<p><b>長い語を足すとき</b>: <code>single</code> の代わりに <code>systemd.unit=rescue.target</code>（27 文字）を足すこともできる。
試すなら、<code>single</code> のときと同じく端末2で <code>sudo reboot</code> を打ち、端末1の GRUB で足す。
ただし、この練習機のコンソール（シリアル 80 桁）では、linux の行の2段目の残りは 20 桁ほどしかなく、長い語は右端の <code>\\</code> で次の段に折り返して表示される。</p>
<pre data-where="{CON}（GRUB の編集画面）"><code>{edit}</code></pre>
<p>行が二重に見えるのは、先に見た描き直しの乱れである。<code>Ctrl+X</code> で起動して Enter を押し、入った root のシェルで、カーネルが受け取った引数を確かめる。</p>
<pre data-where="{CON}（rescue.target の root のシェル）"><code>{shell}</code></pre>
<p>この回は、足した語がそのままカーネルに渡り（<code>/proc/cmdline</code> の最後。80 桁で折り返して表示されている）、rescue.target に入った。確かめたら <code>exit</code> で抜ける（既定のターゲットまで起動が続く）。
折り返した画面では打ち間違えに気づきにくいので、長い語を足したら、入った後に <code>/proc/cmdline</code> で確かめる。この本の演習で短い語（<code>single</code>・<code>3</code>）を使うのはそのためである。</p>'''
else:
    result = chunk('06', 'rescue.target に入らなかった（足した語が崩れた可能性）', tail=8)
    longparam = f'''<p><b>長い語を足すとき</b>: <code>single</code> の代わりに <code>systemd.unit=rescue.target</code>（27 文字）を足すこともできる。
ただし、この練習機のコンソール（シリアル 80 桁）では、linux の行の2段目の残りは 20 桁ほどしかなく、長い語は右端の <code>\\</code> で次の段に折り返して表示される。
著者が <code>single</code> のときと同じ手順（端末2で <code>sudo reboot</code>、端末1の GRUB で足す）で打った記録を載せる。</p>
<pre data-where="{CON}（GRUB の編集画面。systemd.unit=rescue.target と打った後）"><code>{edit}</code></pre>
<p>打ったのは <code>systemd.unit=rescue.target</code> なのに、行末には <code>{_typed}</code> と、文字の順番が崩れて入っている。
80 桁で折り返すところで、GRUB の描き直しと入力がずれたためである（行が二重に見えるのも同じ描き直しの乱れ）。このまま <code>Ctrl+X</code> で起動すると、こうなった。</p>
<pre data-where="{CON}（起動した結果）"><code>{result}</code></pre>
<p>rescue.target には入らず、いつもどおり graphical.target まで起動して、ログインを待っている。崩れた語はどのプログラムにも通じないので、黙って無視された。
同じ操作で崩れずに渡り、rescue.target に入った回もあった（著者の別の記録）。崩れるかどうかは、毎回同じではない。
長い語を足したら、起動した後に <code>cat /proc/cmdline</code> で本当に渡ったかを確かめる。この本の演習で短い語（<code>single</code>・<code>3</code>）を使うのはそのためである。</p>'''
suloginrhel = f'''<p><b>本家の sulogin と比べる</b>: root がロックされていても聞かずに通すのは、Ubuntu が sulogin（util-linux）に入れている改造である。
本家の sulogin は、root がロックされているとシェルを渡さずに止まる。AlmaLinux 9.7 のコンテナで、root がロックされた状態（<code>*</code>）の sulogin を起動した記録を載せる。</p>
{pre('AlmaLinux 9.7 のコンテナ（比べるための記録。読者が打つものではない）', rhel_chunk("grep '^root:' /etc/shadow | cut -d: -f1,2", 'script -qec sulogin /dev/null < /dev/null'))}
<p>本家の sulogin でも、root にパスワードがあれば、それを聞いて確かめる。root がロックされたままシェルを渡させるには、<code>--force</code>（systemd では環境変数 <code>SYSTEMD_SULOGIN_FORCE=1</code>）が要る。
「パスワードを聞かずに root を渡す」のは、root がロックされた Ubuntu だけの振る舞いと覚えておく。</p>'''
BLOCKS = {'LONGPARAM': longparam, 'SULOGINRHEL': suloginrhel}
if __name__ == '__main__':
    import bootfill
    bootfill.apply(P, BLOCKS)
    print('ok')
