import pathlib as _pl, sys as _sys
_HERE = _pl.Path(__file__).resolve().parent
REPO = _HERE.parent.parent
_sys.path.insert(0, str(_HERE))
import re, sys
from bootlog import chunk, pre
T1 = '端末1（外から ssh linuc で入る）'
T2 = '練習機の中（student@linuc）・端末2（様子を見る）'
G2 = '練習機の中（student@linuc）'
P = str(REPO / 'public/linuc-boot/theory/09-hup.html')

jobs = f'''<p>端末を2つ使う。端末1は、外（lab@host）から <code>ssh linuc</code> で練習機に入り、入ったり切ったりする係。端末2は、練習機に入ったまま様子を見る係にする。</p>
<p>端末1で練習機に入り、<code>sleep 300</code>（300 秒待つだけのコマンド）を打って、終わる前に <code>Ctrl+Z</code> を押す。</p>
{pre(T1, chunk('09', 'フォアグラウンドとバックグラウンド', 'sleep 300', 'exit'))}
<p>打ったコマンドが終わるまでプロンプトが戻らない状態を<b>フォアグラウンド</b>、プロンプトが戻って、裏で動き続けている状態を<b>バックグラウンド</b>と呼ぶ。シェルはそれぞれを<b>ジョブ</b>として番号（<code>[1]</code>）で管理する。</p>
<div class="scroll"><table>
<tr><th>操作</th><th>何が起きたか（上の記録）</th></tr>
<tr><td><code>Ctrl+Z</code></td><td>端末が TSTP（20番）を送り、<code>sleep</code> は止まった（<code>Stopped</code>、<code>ps</code> の状態は <code>T</code>）。終わったのではない</td></tr>
<tr><td><code>jobs</code></td><td>このシェルのジョブの一覧。<code>-l</code> で PID も出る。<code>+</code> は今のジョブ（番号を省いたときの相手）、<code>-</code> はその前のもの</td></tr>
<tr><td><code>bg</code></td><td>止めたジョブを、バックグラウンドで再開した（<code>[1]+ sleep 300 &amp;</code>）</td></tr>
<tr><td><code>fg</code></td><td>バックグラウンドのジョブを、フォアグラウンドに戻した。ここで <code>Ctrl+C</code>（INT、2番）を押して終わらせた</td></tr>
<tr><td>末尾の <code>&amp;</code></td><td>はじめからバックグラウンドで起動する（次の節）</td></tr>
</table></div>
<p>ジョブが複数あるときは、番号で選ぶ。端末2（練習機の中）で試す。</p>
{pre(T2, chunk('09', 'fg 2 と fg %1'))}
<p><code>fg 2</code> は2番のジョブ（<code>sleep 702</code>）を、<code>fg %1</code> は1番のジョブを前に戻した。番号の前の <code>%</code> は付けても付けなくてもよい（<code>bg</code> も同じ）。
<code>kill %1</code> のように、ジョブ番号は <code>kill</code> にも渡せるが、そのときは <code>%</code> が要る（<code>%</code> を付けないと PID の意味になる）。
ジョブはシェルごとの番号で、別の端末のシェルからは見えない（そちらでは PID を使う）。</p>
<div class="analogy"><b>たとえ</b>: 端末は、<b>1本しかないマイク</b>に近い。フォアグラウンドのジョブだけがマイクを持っていて、あなたのキー入力を受け取れる。
バックグラウンドのジョブはマイクを持たずに作業を続け、<code>Ctrl+Z</code> はマイクを持っている者の作業を凍らせる。
<br>ただし<b>崩れる点</b>: マイクを持っていなくても、バックグラウンドのジョブは端末に文字を出せる。入力は受け取れないのに出力はできるので、前で打っているコマンドの表示に割り込んで混ざることがある。
この章の <code>nohup</code> の案内が、プロンプトの後ろに出たのもそのためである。</div>'''

exit_ = f'''<div class="naive"><h4>ふつうこう考える</h4>
<p>末尾に <code>&amp;</code> を付けてバックグラウンドで動かしたジョブは、ログアウトすると一緒に消える。だから、ログアウトした後も動かし続けたいなら <code>nohup</code> が要る。</p>
{pre(T1, chunk('09', '& で動かして exit', 'sleep 1001 &', 'exit'))}
{pre(T2, chunk('09', '別の端末から見る（exit の後）'))}
<div class="then"><b>だめな理由</b>: <code>exit</code> でログアウトしても、<code>sleep 1001</code> は消えずに動いている。
bash は、自分が終わるときにジョブへ SIGHUP（1番、「端末が無くなった」という合図）を配るかどうかを <code>huponexit</code> という設定で決めていて、これが <code>off</code> だった（Ubuntu の既定）。
自分から <code>exit</code> したときは、ジョブに合図は届かない。</div></div>
<p>今度は、回線が切れたときを再現する。ssh は、行の先頭で <code>~.</code>（チルダ、ピリオドの順）を打つと、その場で接続を切る。<code>~.</code> は画面に出ないので、<code>Enter</code> を押してから打つ。相手から見ると、回線が突然切れたのと同じである。</p>
{pre(T1, chunk('09', '& で動かして ~.（切断）', 'sleep 1002 &'))}
{pre(T2, chunk('09', '別の端末から見る（切断の後）'))}
<p><code>sleep 1002</code> は消えた（<code>sleep 1001</code> だけが残っている）。回線が切れると、練習機の sshd はログインに使っていた端末（擬似端末）を閉じ、ログインしていたシェルに SIGHUP が届く。
bash は SIGHUP を受け取ると、自分のジョブにも SIGHUP を配ってから終わる。<code>sleep</code> は SIGHUP を無視していないので、既定の動き（終了）で終わった。
「ログアウトするとジョブが消える」と言われるのは、端末のウィンドウを閉じる・回線が切れるといった、<b>この経路</b>のことである。</p>
<div class="note"><b>試験との関係</b>: 試験の例題では「ログアウトすると、<code>&amp;</code> のジョブにも HUP が送られて止まる」と説明されることがある。
bash の既定（<code>huponexit</code> が off）では、上で見たとおり <code>exit</code> では送らず、回線が切れたときに送る。どちらの説明でも、
「ログアウトした後も実行を続けるには」と問われたら、答えは <code>nohup</code>（と、端末ごと残す <code>screen</code>・<code>tmux</code>）である。</div>
<div class="analogy"><b>たとえ</b>: <code>&amp;</code> のジョブは、部屋（シェル）に残した作業員に近い。<code>exit</code> は、あなたが静かに部屋を出ることで、作業員には何も言わないので作業は続く。
切断は、建物の回線が切れて<b>非常放送</b>（SIGHUP）が流れることで、作業員はふつう放送を聞いて帰る。
<br>ただし<b>崩れる点</b>: 建物の停電なら作業そのものができなくなるが、練習機は止まっていない。消えたのは「つながっていた端末」だけで、作業員を帰らせたのは停電ではなく、シェルが流した放送のほうである。
放送を聞かない作業員（次の節の <code>nohup</code>）は、端末が消えた後も仕事を続ける。</div>'''

nohup = f'''<p><code>nohup</code> を付けて起動し、同じように <code>~.</code> で切断する。</p>
{pre(T1, chunk('09', 'nohup で動かして ~.', 'nohup sleep 1003 &'))}
{pre(T2, chunk('09', '別の端末から見る（nohup の後）'))}
<p><code>sleep 1003</code> は切断の後も残った。<code>nohup</code> は、SIGHUP を無視する設定にしてから、指定したコマンドを起動する。
<code>SigIgn</code> の右端（1番、HUP）が立っているのがその印で（第8章の読み方）、無視の設定は起動したコマンドに引き継がれる。だから SIGHUP が届いても何も起きない。</p>
<p><code>nohup</code> はもう1つ、出力の行き先も変える。端末が消えた後に端末へ書こうとすると困るので、出力を <code>nohup.out</code>（カレントディレクトリ。書けなければホームディレクトリ）に足していく。
<code>sleep</code> は何も出さないので 0 バイトのままで、ファイルは本人しか読めない形（<code>-rw-------</code>）で作られた。
なお、<code>nohup</code> の案内（<code>nohup: ignoring input and appending output to 'nohup.out'</code>）は、バックグラウンドのジョブが出すので、プロンプトの後ろに出ることがある。<code>Enter</code> を押せば新しいプロンプトが出る。</p>
<p><code>nohup</code> は SIGHUP を無視させるだけで、ジョブを端末から切り離すわけではない。末尾の <code>&amp;</code> を付けなければ、<code>nohup</code> を付けてもフォアグラウンドで動き、プロンプトは戻らない。</p>'''

tmux = f'''<p><code>nohup</code> は「合図を無視させる」方法だった。もう1つの方法は、端末そのものを練習機の中に残しておくことである。
1つの端末の中で複数の端末を動かし、それを切り離して残しておけるソフトを<b>端末多重化</b>（ターミナルマルチプレクサ）と呼び、<code>tmux</code> と <code>screen</code> がある。</p>
<p>端末1で練習機に入り、<code>tmux new -s work</code> を打つ。画面が tmux の中に切り替わり、下端に <code>[work]</code> で始まる帯が出る。そこで <code>lab-count</code>（1秒ごとに数を数える）を打ち、数え始めたら <code>Ctrl+B</code> を押してから <code>d</code> を押す。
画面は元に戻り、<code>[detached (from session work)]</code> と出る。そのまま <code>~.</code> で切断する。</p>
{pre(T1, chunk('09', 'tmux の中で動かし、切り離してから ~.', 'tmux new -s work'))}
{pre(T2, chunk('09', '別の端末から見る（tmux）'))}
<p>セッション <code>work</code> は残っていて、<code>lab-count</code> も動いている。端末1でもう一度練習機に入り、<code>tmux attach -t work</code> で戻る。</p>
<pre data-where="{T1}（tmux attach -t work で戻った画面）"><code>{chunk('09', 'tmux attach -t work（戻った）', squeeze=True)}</code></pre>
<p>切り離して、回線まで切っていた間も、<code>lab-count</code> は数え続けていた。戻った画面には、その間の表示がそのまま残っている。
tmux の中のプログラムは、あなたの ssh のシェルではなく、練習機の中で動き続ける tmux（の server）の子として動いているので、回線が切れても SIGHUP は届かない。
<code>Ctrl+C</code> で <code>lab-count</code> を止め、tmux の中のシェルを <code>exit</code> で終えると、セッションも終わる（<code>[exited]</code>）。</p>
{pre(T1, chunk('09', 'tmux に戻って終わらせる', 'tmux attach -t work'))}
<p><code>screen</code> も同じことをする。切り離すキーは <code>Ctrl+A</code> を押してから <code>d</code> である。</p>
{pre(T1, chunk('09', 'screen の中で動かし、切り離してから ~.', 'screen -S job'))}
{pre(T2, chunk('09', '別の端末から見る（screen）と後片付け'))}
<div class="scroll"><table>
<tr><th>すること</th><th>tmux</th><th>screen</th></tr>
<tr><td>名前を付けて始める</td><td><code>tmux new -s 名前</code></td><td><code>screen -S 名前</code></td></tr>
<tr><td>切り離す（中は動いたまま）</td><td><code>Ctrl+B</code> → <code>d</code></td><td><code>Ctrl+A</code> → <code>d</code></td></tr>
<tr><td>一覧</td><td><code>tmux ls</code></td><td><code>screen -ls</code></td></tr>
<tr><td>戻る</td><td><code>tmux attach -t 名前</code></td><td><code>screen -r 名前</code></td></tr>
</table></div>
<div class="analogy"><b>たとえ</b>: <code>nohup</code> は、作業員に<b>耳栓</b>をさせて放送が聞こえないようにすること。tmux と screen は、<b>作業部屋ごと練習機の中に移して</b>、あなたは窓から覗いているだけにすることに近い。窓（ssh）が割れても、部屋は無事である。
<br>ただし<b>崩れる点</b>: 本物の窓なら、見ていなかった間の出来事は見えない。tmux は画面の中身ごと持っているので、戻った人は、離れていた間に画面に出たものを続きから見られる。
<code>nohup</code> にはこれが無く、出力は <code>nohup.out</code> というファイルに溜まるだけである。</div>'''

BLOCKS = {'JOBS': jobs, 'EXIT': exit_, 'NOHUP': nohup, 'TMUX': tmux}
if __name__ == '__main__':
    import bootfill
    bootfill.apply(P, BLOCKS)
    print('ok')
