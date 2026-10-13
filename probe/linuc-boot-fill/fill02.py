import pathlib as _pl, sys as _sys
_HERE = _pl.Path(__file__).resolve().parent
REPO = _HERE.parent.parent
_sys.path.insert(0, str(_HERE))
import sys
from bootlog import chunk, pre
A = '外（lab@host）'
P = str(REPO / 'public/linuc-boot/theory/02-ssh.html')
sshopt = f'''<p>ここまで <code>ssh linuc</code> の1語で済んでいたのは、外の <code>~/.ssh/config</code> に、つなぎ先・ポート・ユーザが書いてあるからである。同じことをオプションで書くと、こうなる。</p>
{pre(A, chunk('02b', 'ssh の -i・-p・-l'))}
<div class="scroll"><table>
<tr><th>オプション</th><th>意味</th><th><code>~/.ssh/config</code> での書き方</th></tr>
<tr><td><code>-i ファイル</code></td><td>使う<b>秘密鍵</b>を指定する（<code>-v</code> の <code>Offering public key</code> の行末の <code>explicit</code> は「指定された鍵」の印）</td><td><code>IdentityFile</code></td></tr>
<tr><td><code>-p ポート</code></td><td>接続先のポート。省くと 22 番（上の最後の行は 22 番に断られた）</td><td><code>Port</code></td></tr>
<tr><td><code>-l ユーザ</code></td><td>ログインするユーザ。<code>ユーザ@ホスト</code> と書いても同じ</td><td><code>User</code></td></tr>
</table></div>
<p>紛らわしいのは <code>-i</code> である。<code>ssh -i</code> に渡すのは<b>秘密鍵</b>（<code>id_rsa</code>）で、<code>ssh-copy-id -i</code> に渡すのは相手に写す<b>公開鍵</b>（<code>id_rsa.pub</code>）だった。
どちらも「鍵の組（identity）」を指す同じ文字だが、使う側が違うので、渡すファイルが違う。</p>'''
BLOCKS = {'SSHOPT': sshopt}
if __name__ == '__main__':
    import bootfill
    bootfill.apply(P, BLOCKS)
    print('ok')
