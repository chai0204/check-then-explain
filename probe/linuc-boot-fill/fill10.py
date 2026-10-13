import pathlib as _pl, sys as _sys
_HERE = _pl.Path(__file__).resolve().parent
REPO = _HERE.parent.parent
_sys.path.insert(0, str(_HERE))
import re, sys
from bootlog import chunk, pre
G = '練習機の中（student@linuc）'
A = '外（lab@host）'
P = str(REPO / 'public/linuc-boot/theory/10-x11.html')

none = f'''<p>練習機の中で、X の部品があるかを確かめる。</p>
{pre(G, chunk('10', '練習機の中（X は入っていない）'))}
<p><code>DISPLAY</code> は空で、<code>startx</code> も、X サーバー（<code>Xorg</code>）も、<code>xauth</code> も、<code>xterm</code> も入っていない（<code>command -v</code> は1つも見つけられず、終了コード 1）。
GUI のログイン画面を出すディスプレイマネージャ（<code>display-manager.service</code>）も無い。第4章で見たとおり、練習機はクラウド用の最小構成で、デスクトップのパッケージを入れていない。</p>
<p>それでも sshd は、X11 の転送を受け付ける設定（<code>x11forwarding yes</code>）になっている。<b>受け付ける設定があることと、受け付けたものを処理する部品があることは、別のこと</b>である。次の節で、その差がそのまま断られ方に出る。</p>'''

sshx = f'''<div class="naive"><h4>ふつうこう考える</h4>
<p><code>ssh -X</code> を付ければ、相手の計算機の GUI アプリを手元に出せる。相手（サーバー）の sshd が X11 の転送を許していれば、つながるはずだ。</p>
{pre(A, chunk('10', '外から ssh -X', 'echo "DISPLAY=[$DISPLAY]"', "ssh -v -X linuc true 2>&1 | grep -iE 'x11|display'"))}
<div class="then"><b>だめな理由</b>: 練習機の sshd は X11 の転送を許している（前の節の <code>x11forwarding yes</code>）のに、相手の側に <code>DISPLAY</code> は作られなかった。
断ったのは手元の ssh で、<code>-v</code> の表示が「X11 の転送を頼まれたが、<code>DISPLAY</code> が無い」と言っている。
<code>ssh -X</code> は「相手のアプリの描画を、<b>手元の X サーバー</b>まで運ぶ通り道を作ってほしい」という頼みである。手元に X サーバーが無ければ（<code>DISPLAY</code> が空なら）、運ぶ先が無いので、頼み自体を出さない。</div></div>
<p>手元に X サーバーがある振りをして、<code>DISPLAY=:0</code> を付けて打つ。</p>
{pre(A, chunk('10', '外から ssh -X', 'DISPLAY=:0 ssh -X linuc \'echo DISPLAY=[$DISPLAY]\'', "DISPLAY=:0 ssh -v -X linuc true 2>&1 | grep -iE 'x11|xauth'"))}
<p>今度は手元の ssh が頼みを送り、相手の sshd が「xauth が無いので X11 を転送できない」と断った（<code>Remote:</code> で始まる行は、相手から届いた知らせ）。
手元の側にも <code>xauth</code> が無いので、ssh は本物の合い言葉の代わりに偽物（<code>fake authentication data</code>）を作って送っていた。</p>
<p><code>ssh -X</code> が通るには、手元の X サーバー（<code>DISPLAY</code>）、手元と相手の <code>xauth</code>、相手の sshd の許可（<code>X11Forwarding yes</code>）が揃っている必要がある。
揃っていれば、相手の側に <code>DISPLAY=localhost:10.0</code> のような値が作られ、そこに描いたものが ssh の中を通って手元の X サーバーに届く。どれか1つでも欠ければ、受け取った側が通り道を作らない。</p>
<div class="analogy"><b>たとえ</b>: <code>ssh -X</code> は、遠くの工場（相手）に「できた製品（絵）は、うちの店（手元の X サーバー）に届けてくれ」と<b>配送先を伝える</b>頼みに近い。
店が無ければ届け先を書けないので、頼みを出せない（手元の ssh が断った）。伝票を書く道具（<code>xauth</code>）が工場に無ければ、工場が引き受けない（相手の sshd が断った）。
<br>ただし<b>崩れる点</b>: 本物の配送なら、届け先の店が閉まっていても荷物は先に出せる。X の絵は、届け先の X サーバーとつながったまま1枚ずつやり取りして描くので、届け先が無いまま描き始めることはできない。</div>'''

BLOCKS = {'NONE': none, 'SSHX': sshx}
if __name__ == '__main__':
    import bootfill
    bootfill.apply(P, BLOCKS)
    print('ok')
