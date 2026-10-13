import pathlib as _pl, sys as _sys
_HERE = _pl.Path(__file__).resolve().parent
REPO = _HERE.parent.parent
_sys.path.insert(0, str(_HERE))
import re, sys, html
from bootlog import chunk, pre
G = '練習機の中（student@linuc）'
G1 = '練習機の中（student@linuc）・端末1'
A = '外（lab@host）'
CON = '外（lab@host）・練習機のコンソール'
P = str(REPO / 'public/linuc-boot/theory/07-shutdown.html')

# 時刻なしの shutdown を打った時刻と、予約された時刻（本文で比べる）
t = chunk('07', '端末1: 予約する人', 'sudo shutdown', 'sudo shutdown', raw=True)
typed = re.search(r'\(Tue \d{4}-\d\d-\d\d (\d\d:\d\d:\d\d) JST\)', t).group(1)
at = re.search(r'power off at Tue \d{4}-\d\d-\d\d (\d\d:\d\d:\d\d) JST', t).group(1)

same = f'''{pre(G, chunk('07', '4つのコマンドの正体'))}
<p>4つとも <code>systemctl</code> へのシンボリックリンクである。<code>systemctl</code> は「どの名前で呼ばれたか」を見て、<code>halt</code> なら halt、<code>poweroff</code> なら poweroff として振る舞う。
SysV init の時代に別々のプログラムだった名前を、互換のために残している。だから <code>systemctl halt</code> と <code>halt</code>、<code>systemctl poweroff</code> と <code>poweroff</code> は同じことをする。</p>
<div class="analogy"><b>たとえ</b>: 4つのコマンドは、1人の係員が<b>4つの窓口の名札</b>を付け替えているのに近い。「停止」の窓口に座れば停止の受付を、「再起動」の窓口なら再起動の受付をする。
<br>ただし<b>崩れる点</b>: 人は名札を替えても同じ人だと分かるが、コマンドの名前だけを見ても、それが同じプログラムかは分からない。<code>ls -l</code> でリンク先を見て初めて分かる。</div>'''

schedule = f'''<p>端末を2つ使う。端末2で練習機に入って待っておき、端末1で停止を予約する。</p>
{pre(G + '・端末1（予約する人）', chunk('07', '端末1: 予約する人', 'sudo shutdown -h +30 "メンテナンスのため停止します"', 'ls -l /run/nologin'))}
<p><code>shutdown</code> は止めたのではなく、<b>予約</b>した。予約を持っているのは systemd-logind で、<code>/run/systemd/shutdown/scheduled</code> に時刻（1970年からのマイクロ秒）・種類・文が書かれている。
<code>-h</code> の種類は <code>poweroff</code>（電源を切る）になった。文は UTF-8 のバイト列を <code>\\x..</code> で書き並べた形で保存されている。</p>
<p>この時点で、端末2には何も届いていなかった。続けて予約を取り消し、今度は時刻を付けずに打つ。</p>
{pre(G + '・端末1（予約する人）', chunk('07', '端末1: 予約する人', 'sudo shutdown -c', 'cat /run/nologin'))}
<p><b>時刻を付けない <code>shutdown</code> は「いますぐ」ではなく「1分後」</b>だった（{typed} に打って、予約は {at}）。
今度はすぐに知らせ（Broadcast message）が出て、さらに <code>/run/nologin</code> が作られた。残り 5 分を切ると作られるファイルで、これがある間、一般ユーザは新しくログインできない。外から試す。</p>
{pre(A, chunk('07', '予約が5分以内に迫っているとき、外から入ろうとする'))}
<p>練習機の sshd は、パスワードも鍵も確かめる前に <code>/run/nologin</code> の文を見せて、接続を閉じた。取り消して、全員に文を送る <code>wall</code> も試す。</p>
{pre(G + '・端末1（予約する人）', chunk('07', '端末1: 取り消して、wall を送る'))}
<p>入って待っていた端末2の画面には、こう届いていた。</p>
{pre(G + '・端末2（入って待っていた人）', chunk('07', '端末2: 入って待っていた人の画面'))}
<p>30 分後の予約（とその文）は、予約した時点では端末2に届いていない。logind は残り時間に応じて間を置いて知らせるので、遠い予約ほど、最初の知らせは後になる。
すぐ知らせたいなら <code>wall</code> を自分で打つ。</p>
<div class="scroll"><table>
<tr><th>書き方</th><th>意味</th></tr>
<tr><td><code>shutdown -h now</code></td><td>いますぐ止める（Ubuntu では電源を切る。<code>-P</code> と同じ）</td></tr>
<tr><td><code>shutdown -h +30 "文"</code></td><td>30 分後に止める予約。文はログイン中の端末に届く</td></tr>
<tr><td><code>shutdown -r 23:00</code></td><td>23 時に再起動する予約</td></tr>
<tr><td><code>shutdown -H now</code></td><td>止めるが、電源は切らない（halt）</td></tr>
<tr><td><code>shutdown -c</code></td><td>予約を取り消す</td></tr>
<tr><td><code>shutdown</code>（時刻なし）</td><td>1 分後に電源を切る</td></tr>
</table></div>'''

halt = f'''<div class="naive"><h4>ふつうこう考える</h4>
<p><code>halt</code> は「システムを止める」コマンドだ。止まったのだから、電源も切れているはずだ。外から見れば、仮想マシンは <code>shut off</code> になっているだろう。</p>
{pre(G1, chunk('07', '端末1: sudo halt'))}
{pre(CON, chunk('07', 'halt の後のコンソール', tail=5))}
{pre(A, chunk('07', '外から見た halt の後', 'virsh domstate linuc --reason', 'virsh domstate linuc --reason'))}
<div class="then"><b>だめな理由</b>: 練習機の中では systemd が後片付けを終え、カーネルが <code>System halted</code> と書いて止まった。それでも外から見ると <code>running</code> のままで、
10 秒待っても変わらない。<b><code>halt</code> は CPU を止める（何もしない状態で待たせる）だけで、電源を切る指示は出さない</b>。
電源を切るのは別の動き（ACPI でハードウェアに「切って」と頼む）で、それをするのが <code>poweroff</code> である。
昔の機械では halt の後に人が電源スイッチを切った。仮想マシンでは、外から <code>virsh destroy</code> で切るしかない。</div></div>
{pre(A, chunk('07', '外から見た halt の後', 'virsh destroy linuc', 'virsh start linuc'))}
<p>同じことを <code>poweroff</code> で行う。</p>
{pre(G1, chunk('07', '端末1: sudo poweroff'))}
{pre(CON, chunk('07', 'poweroff の後のコンソール', tail=5))}
{pre(A, chunk('07', 'poweroff の後'))}
<p>最後の行が <code>reboot: Power down</code> に変わり、外から見た状態も <code>shut off (shutdown)</code>（中から止まった）になった。
<code>halt</code> と <code>poweroff</code> の違いは、止まる最後に電源を切るよう頼むかどうかだけである。前の節で見たとおり、Ubuntu の <code>shutdown -h</code> は poweroff として予約された（<code>MODE=poweroff</code>）。
止めるだけにしたいときは <code>shutdown -H</code>、電源まで切るなら <code>shutdown -P</code> と書き分けられる。</p>
<div class="analogy"><b>たとえ</b>: <code>halt</code> は、店の<b>閉店作業を終えて照明を落とした</b>状態に近い。店は営業していないが、建物の電気（電源）は来たままである。<code>poweroff</code> はブレーカーまで落とす。
<br>ただし<b>崩れる点</b>: 店なら照明が消えていれば外から「閉まった」と分かるが、仮想マシンは halt した後も外からは <code>running</code> にしか見えない。
中で何が起きたかは、コンソールの最後の1行（<code>System halted</code>）を見ないと分からない。</div>'''

destroy = f'''<p>今度は、正しく止めずに電源を抜く。練習機の中でファイルを1つ書き、数秒のうちに外から <code>virsh destroy</code> する。</p>
{pre(G1, chunk('07b', '端末1: 書いてすぐに電源を抜かれる'))}
{pre(A, chunk('07b', '外: 動いている練習機を destroy して、また起動する'))}
<p>起動し直したら、もう一度入って、同じ場所を見る。</p>
{pre(G, chunk('07b', '電源を抜かれた次の起動'))}
<p>2つのことが起きている。1つ目に、起動の途中（initramfs の中）で <code>fsck</code> がルートのファイルシステムを調べ、<code>recovering journal</code>（ジャーナルを再生した）と書いている。
ext4 は、書き換えの予定を先に<b>ジャーナル</b>という控えに書いてから、本体を書き換える。途中で電源が切れても、次の起動で控えを読み直せば、ファイルシステムを壊れていない状態に戻せる。
正しく止めたときは止める前に書き終えているので、この作業は要らない（第5章の起動では <code>clean</code> とだけ出ていた）。
なお、この記録の時刻は UTC（日本時間の 9 時間前）で書かれている。initramfs の中では、まだタイムゾーンの設定を読んでいないからである。</p>
<p>2つ目に、電源を抜く数秒前に書いた <code>memo.txt</code> は、ファイルごと残っていなかった。ファイルシステムが守ったのは「壊れていない」ことで、「書いたものが残る」ことではない。
書いた中身はすぐにはディスクに書かれず、しばらくメモリの上に置かれてから、まとめて書き出される。その前に電源が消えれば、書いたつもりのものは無かったことになる。
<code>shutdown</code> や <code>poweroff</code> が止まる前にしていたのは、この書き出しと、各サービスの後片付けである。</p>
<div class="analogy"><b>たとえ</b>: 正しい停止は、閉店のあとで<b>帳簿を締めて金庫にしまう</b>ことに近い。電源を抜くのは、営業中に停電することである。
翌朝、帳簿の控え（ジャーナル）を見れば、最後に締めたところまでは戻せる。
<br>ただし<b>崩れる点</b>: 店なら、停電の直前に書いた注文のメモも、紙として机の上に残っている。コンピュータでは、書いたつもりのものはまだメモリの上にあり、紙（ディスク）に写す前だった。
「書いた」と「残った」が別の出来事であるところが、人の感覚とずれる。</div>'''

_ra = chunk('07b', 'reboot の後', raw=True).split('\n')
_k = next(i for i, l in enumerate(_ra) if l.startswith('$ last -x'))
REBOOT_AFTER = html.escape('\n'.join(_ra[:_k + 6] + ['（略）']), quote=False)   # last -x の出力は上の5行だけ見せる
reboot = f'''<p>最後に再起動する。<code>/proc/sys/kernel/random/boot_id</code> は起動のたびに作り直される乱数で、この値が変われば、間に再起動があったと分かる。</p>
{pre(G1, chunk('07b', 'sudo reboot'))}
{pre(G, REBOOT_AFTER)}
<p><code>boot_id</code> が変わった。<code>last -x</code> は、ログインの記録から起動（<code>reboot</code>）と停止（<code>shutdown</code>）の行を出す。1行が1回の起動か停止で、新しいものが上に並ぶ。
正しく止めた起動は、その上に <code>shutdown</code> の行が付く。電源を抜かれた起動には <code>shutdown</code> の行が無く、<code>reboot</code> の行が2つ続いている（上から3行目と4行目）。
後から「この機械は正しく止められていたか」を調べるときの手がかりになる（6行目より下は、それまでに何回起動し直したかで人ごとに変わるので略した）。</p>
<p><code>reboot</code> も、これまでの3つと同じく <code>systemctl</code> へのリンクで、<code>shutdown -r now</code> と同じことをする。再起動の前に、ログイン中の端末へ知らせが届き、接続が閉じられた。</p>'''

BLOCKS = {'SAME': same, 'SCHEDULE': schedule, 'HALT': halt, 'DESTROY': destroy, 'REBOOT': reboot}
if __name__ == '__main__':
    import bootfill
    bootfill.apply(P, BLOCKS)
    print('ok', typed, at)
