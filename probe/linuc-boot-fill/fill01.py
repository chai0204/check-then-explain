import pathlib as _pl, sys as _sys
_HERE = _pl.Path(__file__).resolve().parent
REPO = _HERE.parent.parent
_sys.path.insert(0, str(_HERE))
import re, sys
from bootlog import chunk, pre, pick, lines_from
A2 = '外（lab@host）・端末2'
T1 = '外（lab@host）・端末1（練習機のコンソール）'
P = str(REPO / 'public/linuc-boot/theory/01-virsh.html')

grub_con = pick('01', 'GRUB の間に shutdown を送った後のコンソール', [
    r'^\$ virsh start linuc --console$', r"^Domain 'linuc' started$",
    r'The highlighted entry will be executed automatically in', r'^Begin: Running /scripts/init-bottom',
    r'^Welcome to Ubuntu', r'Reached target graphical\.target', r'^Ubuntu 24\.04\.5 LTS linuc ttyS0$'])
def login_part(title):
    """コンソールでログインしたところ（案内の行 → student → Password: → …）から最後まで。
    ログインの案内（linuc login:）が描き直しで消えて「student」だけが残ることがあるので、手前の案内の行から取る。"""
    import html as _h
    from bootlog import records
    ls = list(records('01')[title])
    k = max(i for i, l in enumerate(ls) if re.search(r'(^|login: )student$', l) and i + 1 < len(ls) and ls[i + 1] == 'Password:')
    while k > 0 and not ls[k].startswith('Ubuntu 24.04'):
        k -= 1
    return _h.escape('\n'.join(ls[k:]), quote=False)
journal_agent = login_part('前の起動の止まり方（virsh shutdown をそのまま打った）')
journal_acpi = login_part('前の起動の止まり方（--mode acpi）')
GLITCH = ('（シリアルの画面は描き直しで行が欠けることがあり、下の記録では <code>linuc login:</code> の案内が消えて、打った <code>student</code> だけが残っている）'
          if '\nstudent\nPassword:' in journal_agent else '')

shutdown = f'''<p>起動し終わった練習機を止める。端末1は <code>Ctrl+]</code> でコンソールから抜けておき、端末2で打つ。</p>
{pre(A2, chunk('01', 'virsh shutdown（起動し終わってから）'))}
<p><code>virsh shutdown</code> の直後はまだ <code>running</code> で、十数秒たってから <code>shut off</code> になった。返事も「止めた」ではなく「止めている途中」（<code>is being shutdown</code>）である。
<code>virsh shutdown</code> は、仮想マシンを止めるのではなく、<b>中の OS に「止まってほしい」と頼む</b>。頼み方は2つあり、
練習機の中のゲストエージェント（さっき <code>guest-ping</code> に答えた案内役）がつながっていればエージェントに頼み、つながっていなければ ACPI の電源ボタンを押して知らせる。
どちらで頼まれたかは、受け取った OS の記録に残る。次の起動のときに読む。</p>
<div class="naive"><h4>ふつうこう考える</h4>
<p><code>virsh shutdown</code> は仮想マシンを止めるコマンドだ。時間がかかるのは OS の後片付けのせいで、
起動の途中（GRUB のメニューが出ている間）に打てば、片付けるものも無いのですぐ止まるはずだ。</p>
<p>端末1で <code>virsh start linuc --console</code> を打つ。GRUB のメニューが出たら、数え下げ（10 秒）が終わる前に、端末2で <code>virsh shutdown linuc</code> を打つ。</p>
<pre data-where="{T1}"><code>{grub_con}</code></pre>
{pre(A2 + '（端末1に GRUB のメニューが出ている間に打つ）', chunk('01', 'GRUB の間に virsh shutdown を送った'))}
{pre(A2 + '（ログインの案内が出て、さらに 20 秒待った後）', chunk('01', 'ログインの案内が出た後'))}
<div class="then"><b>だめな理由</b>: 止まらなかった。GRUB のメニューはそのまま数え下げを終え、Ubuntu が最後まで起動して、ログインを待っている。
GRUB の間は、練習機の中にまだ OS もゲストエージェントもいない。エージェントがつながっていないので、<code>virsh shutdown</code> は <b>ACPI の電源ボタンを押して</b>頼んだ。
押されたことを受け取って「では止まろう」と決めるのは中の OS（Linux の systemd-logind）で、GRUB のメニューにはボタンを聞く者がいない。
聞く者がいない間に押されたボタンは、誰にも届かずに消えた（著者は4回試して4回とも同じだった）。
<b>止めるかどうかを決めていたのは、virsh ではなく受け取る側だった。</b>
（状態の理由が <code>booted</code> ではなく <code>unpaused</code> なのは、<code>--console</code> を付けて起動すると、virsh がいったん一時停止の状態で起動し、
コンソールをつないでから動かすため。起動の最初の表示を取りこぼさないための工夫で、ここでの話とは関係ない。）</div></div>
<p>では、最初の <code>virsh shutdown</code>（起動し終わってから打ったもの）は、どう頼まれたのか。端末1のコンソールでログインし、1つ前の起動の記録（<code>journalctl -b -1</code>）を読む{GLITCH}。</p>
<pre data-where="{T1}"><code>{journal_agent}</code></pre>
<p>1つ前の起動では、ゲストエージェント（<code>qemu-ga</code>）が <code>guest-shutdown</code> の頼みを受け取り、systemd-logind が「ハイパーバイザーに頼まれた停止」として止めていた。
電源ボタンの記録は無い。頼み方を ACPI の電源ボタンに決めたいときは <code>--mode acpi</code> を付ける。端末1を <code>Ctrl+D</code> でログアウトしてから、端末2で打つ。</p>
{pre(A2, chunk('01', 'virsh shutdown --mode acpi'))}
<p>練習機の電源が切れると、端末1のコンソールは自動で外の端末に戻る（<code>$</code> が出る）。端末1で <code>virsh start linuc --console</code> をもう一度打ち、<code>login:</code> が出たらログインして、同じように読む。</p>
<pre data-where="{T1}"><code>{journal_acpi}</code></pre>
<p>今度は systemd-logind が「電源ボタンが短く押された」（<code>Power key pressed short.</code>）と受け取って、止まった。
頼み方は違っても、<b>止めると決めたのは、どちらも中の OS（systemd-logind）</b>である。</p>
<div class="scroll"><table>
<tr><th>書き方</th><th>頼み方</th></tr>
<tr><td><code>virsh shutdown linuc</code></td><td>ゲストエージェントがつながっていればエージェント、いなければ ACPI の電源ボタン（libvirt が選ぶ）</td></tr>
<tr><td><code>virsh shutdown --mode agent linuc</code></td><td>ゲストエージェントだけ（つながっていなければ失敗する）</td></tr>
<tr><td><code>virsh shutdown --mode acpi linuc</code></td><td>ACPI の電源ボタンだけ</td></tr>
</table></div>
<p>受け取る側に決めさせずに止める方法が1つだけある。電源を抜くことである。端末1は <code>Ctrl+D</code> と <code>Ctrl+]</code> で外に戻り、動いたままの練習機に対して端末2で打つ。</p>
{pre(A2, chunk('01', 'virsh destroy'))}
<p><code>destroy</code> は名前に反して何も壊さない（定義もディスクも残る）。QEMU のプロセスを終わらせる、つまり<b>電源コードを抜く</b>。
中の OS は止まる準備をする暇が無いので、書きかけのデータは失われうる。何が起きるかは第7章で確かめる。</p>
<div class="scroll"><table>
<tr><th>コマンド</th><th>誰に届くか</th><th>中の OS が断れるか</th></tr>
<tr><td><code>virsh start</code></td><td>ハイパーバイザー（QEMU のプロセスを起動する）</td><td>— （まだ OS がいない）</td></tr>
<tr><td><code>virsh shutdown</code></td><td>中の OS（ゲストエージェント、いなければ ACPI の電源ボタン）</td><td>断れる・受け取る者がいなければ届かない</td></tr>
<tr><td><code>virsh reboot</code></td><td>中の OS（同じく、ゲストエージェントか ACPI）</td><td>断れる</td></tr>
<tr><td><code>virsh suspend</code> / <code>resume</code></td><td>ハイパーバイザー（仮想の CPU を止める / 動かす。次の節）</td><td>断れない（止められたことにも気づかない）</td></tr>
<tr><td><code>virsh destroy</code></td><td>ハイパーバイザー（QEMU のプロセスを終わらせる）</td><td>断れない（電源を抜く）</td></tr>
<tr><td><code>virsh console</code></td><td>仮想のシリアルポート</td><td>— （画面とキーボードをつなぐだけ）</td></tr>
</table></div>
<div class="analogy"><b>たとえ</b>: <code>virsh shutdown</code> は、建物の中の人に<b>「閉めてください」と頼む</b>ことに近い。館内電話（ゲストエージェント）がつながっていれば電話で、
つながっていなければ非常ボタン（ACPI の電源ボタン）を押して知らせる。<code>virsh destroy</code> は<b>建物の電気を落とす</b>ことである。
<br>ただし<b>崩れる点</b>: 実物の電源ボタンは押し続けると（4秒ほどで）強制的に電源が切れるが、<code>virsh shutdown</code> は何秒待っても強制には変わらない。
強制したければ、人が自分で <code>destroy</code> を打つ。</div>'''

autostart = f'''{pre('外（lab@host）', chunk('01', '自動起動の印と、もう一度電源を入れる'))}
<p>自動起動の印は、定義へのシンボリックリンク1本である。libvirt は自分が起動したとき（実機ならホストの起動時、この檻ではコンテナの起動時）にこのディレクトリを見て、
印の付いた仮想マシンの電源を入れる。本当にそうなるかは第3章で、コンテナを止めて起動し直して確かめる。</p>
<p>電源を入れたまま、仮想の CPU だけを止めることもできる。</p>
{pre('外（lab@host）', chunk('01', '一時停止と再開'))}
<p><code>virsh suspend</code> で <code>paused (user)</code>（人が一時停止した）になり、<code>virsh resume</code> で動き出した。止めている間もメモリの中身はそのままで、
中の OS から見ると時間が飛んだだけである。止められたことを断ることも、気づくこともできない。</p>
<p>コンソールは<b>1人分しか無い</b>。試す。外の窓をもう1つ開き（<code>docker exec -it lab-linuc-boot bash -l</code>）、<code>virsh console linuc</code> でつなぐ。
つながったら <code>Ctrl+]</code> を押さずに、<b>その窓を閉じる</b>（端末のウィンドウやタブを閉じる）。それから端末1で <code>virsh console linuc</code> を打つ。</p>
{pre('外（lab@host）・端末1', chunk('01', 'コンソールの取り合い'))}
<p>窓を閉じても、外のコンテナの中では古い <code>virsh console</code> が「つながっている」と言い張っている。<code>--force</code> で奪えば入れる（抜けるのは <code>Ctrl+]</code>）。
抜けるときは窓を閉じずに <code>Ctrl+]</code> で抜ける習慣にしておけば、こうはならない。</p>
<div class="analogy"><b>たとえ</b>: コンソールは、サーバ室に1台だけある<b>保守用の端末</b>に近い。誰かが座っていれば、次の人は座れない。
<br>ただし<b>崩れる点</b>: 実物の端末なら席を立てば空くが、<code>virsh console</code> は窓を閉じても「座っている」記録が残る。
空いているかどうかを決めているのは、端末を閉じた人ではなく、コンソールを持っている側（libvirt）である。</div>'''

consolelogin = f'''<pre data-where="{T1}"><code>{lines_from('01', 'コンソールでログインして、Ctrl+D で出る', r'^linuc login: student$')}</code></pre>'''
BLOCKS = {'SHUTDOWN': shutdown, 'AUTOSTART': autostart, 'CONSOLELOGIN': consolelogin}
if __name__ == '__main__':
    import bootfill
    bootfill.apply(P, BLOCKS)
    print('ok')
