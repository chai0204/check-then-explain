import pathlib as _pl, sys as _sys
_HERE = _pl.Path(__file__).resolve().parent
REPO = _HERE.parent.parent
_sys.path.insert(0, str(_HERE))
import sys
from bootlog import chunk, pre, rhel_chunk
A = '外（lab@host）'
P = str(REPO / 'public/linuc-boot/theory/02-ssh.html')
sshopt = f'''<p>ここまで <code>ssh linuc</code> の1語で済んでいたのは、外の <code>~/.ssh/config</code> に、つなぎ先・ポート・ユーザが書いてあるからである。同じことをオプションで書くと、こうなる。</p>
{pre(A, chunk('02', 'ssh の -i・-p・-l', 'cat ~/.ssh/config', 'ssh -l student 127.0.0.1 hostname'))}
<div class="scroll"><table>
<tr><th>オプション</th><th>意味</th><th><code>~/.ssh/config</code> での書き方</th></tr>
<tr><td><code>-i ファイル</code></td><td>使う<b>秘密鍵</b>を指定する（<code>-v</code> の <code>Offering public key</code> の行末の <code>explicit</code> は「指定された鍵」の印）</td><td><code>IdentityFile</code></td></tr>
<tr><td><code>-p ポート</code></td><td>接続先のポート。省くと 22 番（上の最後の行は 22 番に断られた）</td><td><code>Port</code></td></tr>
<tr><td><code>-l ユーザ</code></td><td>ログインするユーザ。<code>ユーザ@ホスト</code> と書いても同じ</td><td><code>User</code></td></tr>
</table></div>
<p>紛らわしいのは <code>-i</code> である。どちらも「鍵の組（identity）」を指す文字で、<code>ssh -i</code> には<b>秘密鍵</b>のファイルを渡す。
<code>ssh-copy-id -i</code> には、この章では <code>id_rsa.pub</code> を渡したが、<code>.pub</code> を付けずに渡してもよい。</p>
{pre(A, chunk('02', 'ssh の -i・-p・-l', 'ssh-copy-id -i ~/.ssh/id_rsa linuc', 'ssh-copy-id -i ~/.ssh/id_rsa linuc'))}
<p>名前が <code>.pub</code> で終わっていなければ <code>.pub</code> を足して読むので、相手に送られるのは常に<b>公開鍵</b>である（<code>Source of key(s)</code> の行）。
ここでは同じ鍵が既に名簿にあったので、何も足さなかった。</p>'''
_man = chunk('02', 'authorized_keys が他人に書けると、鍵は使われない', "ssh linuc \"man ssh | grep -B2 -A2 'group-writable'\"", "ssh linuc \"man ssh | grep -B2 -A2 'group-writable'\"", raw=True)
TROFF = ('（<code>troff:</code> で始まる行は、端末を持たない ssh の中で man が文章を整形したときの警告で、中身とは関係ない。）' if 'troff:' in _man else '')
modesubuntu = f'''<p>group に書ける（<code>664</code>）ようにしても、鍵で入れた。<code>student</code> グループのメンバー欄は空で、書けるのは本人だけである。
ただし、これを許すのは <b>Debian / Ubuntu の sshd の改造</b>で、練習機の <code>man ssh</code> にも「本人だけのグループなら group に書けてもよい」という但し書きがある。</p>
{pre(A, chunk('02', 'authorized_keys が他人に書けると、鍵は使われない', "ssh linuc \"man ssh | grep -B2 -A2 'group-writable'\"", "ssh linuc \"man ssh | grep -B2 -A2 'group-writable'\""))}
<p>{TROFF}本家の OpenSSH にはこの改造が無く、グループが本人だけでも、group に書けるだけで断る。比べるために、AlmaLinux 9.7 のコンテナで同じことをした記録を載せる。</p>
{pre('AlmaLinux 9.7 のコンテナ（比べるための記録。読者が打つものではない）', rhel_chunk('chmod 664 /home/alice/.ssh/authorized_keys; ls -l /home/alice/.ssh/authorized_keys; getent group alice', "su - alice -c 'ssh -o BatchMode=yes localhost echo 鍵で入れた'"))}
<p>試験では「<code>authorized_keys</code> は group にも other にも書けてはいけない（<code>600</code> にする）」と答える。</p>'''
BLOCKS = {'SSHOPT': sshopt, 'MODESUBUNTU': modesubuntu}
if __name__ == '__main__':
    import bootfill
    bootfill.apply(P, BLOCKS)
    print('ok')
