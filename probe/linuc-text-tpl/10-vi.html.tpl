<!doctype html>
<html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>10. :w! は、読み取り専用のファイルにも書く — 確かめて説明する LinuC 主題1.03</title>
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="/shared/style.css"></head>
<body data-draft="1" data-ch="10" data-theme="linuc-text">
<div class="wrap">
<nav class="top"><a href="/">トップ</a> › <a href="/linuc/">LinuC</a> › <a href="/linuc-text/theory/">理論編</a> › 第10章</nav>
<div class="draftbar compact">
<p><b>ドラフト</b>: このテーマは著者が読者として通していません。出力はすべて実機の記録ですが、導線の不備が残っている可能性があります。<a href="/linuc-text/theory/">詳しく</a></p>
</div>
<h1>10. :w! は、読み取り専用のファイルにも書く</h1>
<p class="lead"><code>chmod 444</code> で書き込みを禁止したファイルには、シェルから <code>&gt;&gt;</code> で1行足すこともできない。ところが vi で開いて <code>:w!</code> と打つと書き換わり、しかも権限は <code>444</code> のまま残る。vi は、同じキーの意味が<b>モード</b>で変わるエディタで、vi の中で打ったキーはシェルを通らない。そして、どのエディタを開くかは、環境変数 <code>EDITOR</code> で外から伝えるしかない。</p>
<div class="badges"><span>前提: 第1章（export）</span><span>前提: 檻が起動している</span><span>所要 25分</span><span class="impact-b">影響度 B</span><span>出題範囲 1.03.5（重要度2）</span><span>最終検証 2026-10-13</span></div>
<div class="goal"><h4>この章のゴール</h4>
<ul><li>vi のノーマルモード・挿入モード・コマンドラインモードを、<code>ESC</code> <code>i</code> <code>a</code> <code>o</code> <code>:</code> で行き来できる</li><li><code>h j k l</code>、<code>dd yy p</code>、<code>c d y</code>、<code>/</code> <code>?</code>、<code>:w!</code> <code>:q!</code> <code>:e!</code> <code>ZZ</code> の意味と結果を言える</li><li><code>EDITOR</code> で標準のエディタを変えられ、Ubuntu の既定が nano になる仕組みを説明できる</li></ul>
<div class="skip"><b>ここで覚えなくていいこと</b>: <code>~/.vimrc</code> の設定、ビジュアルモード、名前付きレジスタ（<code>"a</code>）、マクロ、<code>:s</code> による置換（中身は <code>sed</code> と同じ。第6章）、emacs のキー操作。vim のプラグインは試験に出ない。</div></div>

<h2 id="record">この章の記録のとり方</h2>
<div class="sgoal"><b>この節で分かること</b>: 対話的に使う vi を、どうやって記録に残したか。</div>
<p>vi は画面全体を使う対話的なプログラムなので、ほかの章のように「打って、出力を写す」ことができない。この章では、<b>本物の vim を端末（pty）の上で起動し、キーを1つずつ流し込み</b>、終わった後のファイルの中身を <code>cat</code> で記録した。<code>（打鍵: …）</code> の行が流し込んだキーで、<code>⏎</code> は <kbd>Enter</kbd>、<code>ESC</code> は <kbd>Esc</kbd> キーである。画面に出たエラーメッセージ（<code>E37</code> など）は、画面の記録から抜き出して載せた。</p>
<p>あなたが打つときは、<code>vim v1.txt</code> で開いて、同じキーを順に押せばよい。終わったら <code>cat</code> で同じ中身になっていることを確かめる。</p>
<pre><code>@@
$ cd ~/text
$ cat memo.txt
@@</code></pre>
<p class="detail">最初は <code>vim -es</code>（画面を使わない Ex モード）で記録しようとした。ところが Ex モードは設定ファイルを読まずに Vi 互換モードで動くため、後で見る <code>:w!</code> の結果が対話の vim と違った。だから対話の vim にキーを流し込む方法に変えている（最後の節に、その差の記録も載せた）。</p>

<h2 id="mode">モードを切り替える</h2>
<div class="sgoal"><b>この節で分かること</b>: 同じキーが、モードによって命令にも文字にもなること。</div>
<div class="scroll"><table>
<tr><th>モード</th><th>キーの扱い</th><th>入り方</th><th>抜け方</th></tr>
<tr><td>ノーマルモード（コマンドモード）</td><td>キーが<b>命令</b>になる（<code>dd</code> で行を消す）</td><td>起動した直後 / <code>ESC</code></td><td><code>i</code> <code>a</code> <code>o</code> などで挿入、<code>:</code> でコマンドライン</td></tr>
<tr><td>挿入モード</td><td>キーが<b>文字</b>として入る</td><td><code>i</code> <code>a</code> <code>o</code> <code>O</code> <code>c</code> など</td><td><code>ESC</code></td></tr>
<tr><td>コマンドラインモード</td><td>画面の最下行に命令を打つ（<code>:wq</code>）</td><td><code>:</code>（探すときは <code>/</code> <code>?</code>）</td><td><kbd>Enter</kbd> で実行 / <code>ESC</code> で取り消し</td></tr>
</table></div>
<pre><code>@@
$ cp memo.txt v5.txt
$ vim v5.txt
$ cat v5.txt
$ cp memo.txt v6.txt
$ vim v6.txt
$ cat v6.txt
$ cp memo.txt v7.txt
$ vim v7.txt
$ cat v7.txt
$ cp memo.txt v8.txt
$ vim v8.txt
$ cat v8.txt
@@</code></pre>
<p>開いた直後、カーソルは1行目の先頭にある。<code>o</code> は今の行の<b>下</b>に、<code>O</code> は<b>上</b>に新しい行を開いて挿入モードに入る。<code>i</code> はカーソルの<b>前</b>に、<code>a</code> は<b>後ろ</b>に文字を入れる（<code>a</code> の後の <code>-</code> が <code>a</code> と <code>pple</code> の間に入った）。どれも <code>ESC</code> でノーマルモードに戻り、<code>:wq</code> で保存して終わる。</p>
<div class="analogy"><b>たとえ</b>: テレビのリモコンの<b>入力切替</b>に近い。同じ数字ボタンが、ふだんはチャンネルを変え、文字入力の画面では文字を打つ。
<br>ただし<b>崩れる点</b>: リモコンなら画面にいまの入力モードが出るが、vi のノーマルモードは何も表示しない（挿入モードのときだけ最下行に <code>-- INSERT --</code> と出る）。
迷ったら <code>ESC</code> を押してノーマルモードに戻るのが決まりで、何度押しても害は無い。</div>

<h2 id="edit">動く・消す・写す・貼る</h2>
<div class="sgoal"><b>この節で分かること</b>: ノーマルモードの命令と、<code>d</code> <code>y</code> <code>p</code> <code>c</code> の関係。</div>
<pre><code>@@
$ cp memo.txt v1.txt
$ vim v1.txt
$ cat v1.txt
$ cp memo.txt v2.txt
$ vim v2.txt
$ cat v2.txt
$ cp memo.txt v3.txt
$ vim v3.txt
$ cat v3.txt
$ cp memo.txt v4.txt
$ vim v4.txt
$ cat v4.txt
@@</code></pre>
<p><code>j</code> で1行下へ動き、<code>dd</code> でその行を消した。<code>yy</code> は行を写し（yank）、<code>p</code> は今の行の下に貼る（put）。3つ目は <code>dd</code> で消した <code>banana</code> を、<code>p</code> で <code>cherry</code> の下に貼って、2行を入れ替えた。<code>dd</code> は「消す」ではなく<b>切り取り</b>で、消した行は覚えられている。<code>G</code> は最後の行へ、<code>k</code> は1行上へ、<code>P</code>（大文字）は今の行の上に貼る。</p>
<pre><code>@@
$ cp memo.txt v12.txt
$ vim v12.txt
$ cat v12.txt
$ cp memo.txt v13.txt
$ vim v13.txt
$ cat v13.txt
$ cp memo.txt v14.txt
$ vim v14.txt
$ cat -A v14.txt
$ cp memo.txt v15.txt
$ vim v15.txt
$ cat v15.txt
$ cp memo.txt v16.txt
$ vim v16.txt
$ cat v16.txt
$ cp memo.txt v11.txt
$ vim v11.txt
$ cat v11.txt
@@</code></pre>
<p><code>l</code> は右、<code>h</code> は左、<code>$</code> は行末へ動き、<code>x</code> は1文字消す。<code>d</code> <code>y</code> <code>c</code> は、後ろに<b>動きのキー</b>を続けると、そこまでを相手にする。<code>d$</code> は行末まで消し（空の行が残った）、<code>yw</code> は1単語を写す（<code>P</code> で前に貼ったので <code>bananabanana</code>）。<code>2dd</code> は2行まとめて消す。<code>cw</code> は単語を消して挿入モードに入る（change）。</p>
<div class="scroll"><table>
<tr><th>キー</th><th>意味</th></tr>
<tr><td><code>h</code> <code>j</code> <code>k</code> <code>l</code></td><td>左・下・上・右へ1つ</td></tr>
<tr><td><code>gg</code> / <code>G</code> / <code>$</code> / <code>0</code></td><td>最初の行 / 最後の行 / 行末 / 行頭</td></tr>
<tr><td><code>dd</code> / <code>2dd</code> / <code>dw</code> / <code>d$</code></td><td>1行 / 2行 / 1単語 / 行末までを切り取る</td></tr>
<tr><td><code>yy</code> / <code>yw</code></td><td>1行 / 1単語を写す（コピー）</td></tr>
<tr><td><code>p</code> / <code>P</code></td><td>切り取り・写したものを後ろ（下）/ 前（上）に貼る</td></tr>
<tr><td><code>cw</code> / <code>c$</code></td><td>1単語 / 行末までを消して挿入モードへ</td></tr>
<tr><td><code>x</code> / <code>u</code></td><td>1文字消す / 直前の変更を取り消す</td></tr>
</table></div>
<div class="analogy"><b>たとえ</b>: <code>dd</code> と <code>p</code> は、ワープロの<b>切り取りと貼り付け</b>に近い。<code>yy</code> はコピーである。
<br>ただし<b>崩れる点</b>: vi の切り取り置き場（無名レジスタ）は1つで、次に <code>dd</code> や <code>yy</code> をすると黙って上書きされる。
OS のクリップボードとも別物で、ほかのアプリには貼れない。2行を別々の場所へ移したいなら、1行ずつ「切り取り→貼り付け」を終えてから次へ進む。</div>

<h2 id="search">探す — / と ?</h2>
<div class="sgoal"><b>この節で分かること</b>: 下向きと上向きの検索。</div>
<pre><code>@@
$ cp memo.txt v9.txt
$ vim v9.txt
$ cat v9.txt
$ cp memo.txt v10.txt
$ vim v10.txt
$ cat v10.txt
@@</code></pre>
<p><code>/an</code> は今の位置から<b>下向き</b>に <code>an</code> を探し、最初に見つかった <code>banana</code> の2文字目に移った（そこで <code>x</code> を押したので <code>bnana</code>）。<code>?an</code> は<b>上向き</b>に探す。最後の行（<code>G</code>）から上へ探すと、<code>banana</code> の<b>後ろのほうの</b> <code>an</code> に当たった（<code>banna</code>）。<code>n</code> で同じ向きに次を、<code>N</code> で逆向きに探す。探す文字列は正規表現である（第9章）。</p>

<h2 id="quit">保存して終わる、保存せずに終わる</h2>
<div class="sgoal"><b>この節で分かること</b>: <code>:q</code> が断られる場面と、<code>!</code> の意味。</div>
<pre><code>@@
$ cp memo.txt q1.txt
$ vim q1.txt
$ cat q1.txt
$ cp memo.txt q2.txt
$ vim q2.txt
$ cat q2.txt
$ cp memo.txt v17.txt
$ vim v17.txt
$ cat v17.txt
@@</code></pre>
<p>変更した後の <code>:q</code> は <code>E37: No write since last change (add ! to override)</code>（保存していない変更がある。<code>!</code> を付ければ押し通す）で断られた。<code>:q!</code> で変更を捨てて終わったので、ファイルは元のまま。<code>:e!</code> は最後に保存した状態から読み直す（2行消した変更が捨てられた）。<code>ZZ</code> は「保存して終わる」で、<code>:wq</code> と同じ結果になった。</p>
<div class="scroll"><table>
<tr><th>打つもの</th><th>意味</th></tr>
<tr><td><code>:w</code> / <code>:w ファイル名</code></td><td>保存する / 別の名前で保存する</td></tr>
<tr><td><code>:q</code></td><td>終わる（保存していない変更があると断られる）</td></tr>
<tr><td><code>:q!</code></td><td>変更を捨てて終わる</td></tr>
<tr><td><code>:wq</code> / <code>ZZ</code></td><td>保存して終わる（<code>ZZ</code> は変更があるときだけ書く）</td></tr>
<tr><td><code>:e!</code></td><td>変更を捨て、最後に保存した状態を読み直す</td></tr>
<tr><td><code>:w!</code></td><td>読み取り専用でも押し通して保存する（次の節）</td></tr>
</table></div>

<h2 id="readonly">読み取り専用のファイルを、:w! で書く</h2>
<div class="sgoal"><b>この節で分かること</b>: <code>!</code> が押し通しているものと、ファイルの権限との関係。</div>
<div class="naive"><h4>ふつうこう考える</h4>
<p><code>chmod 444</code> で、誰も書けないようにした。シェルから追記できないのだから、vi で開いても保存はできないはずだ。</p>
<pre><code>@@
$ cp memo.txt ro.txt; chmod 444 ro.txt
$ stat -c "%A %s %n" ro.txt
$ echo kiwi >> ro.txt; echo "exit=$?"
$ vim ro.txt
$ cat ro.txt
$ stat -c "%A %s %n" ro.txt
@@</code></pre>
<div class="then"><b>だめな理由</b>: <code>:w</code> は <code>E45: 'readonly' option is set (add ! to override)</code> で断られたが、<code>:w!</code> は書けた。
<code>apple</code> の行が消え、大きさが 25 から 19 バイトに変わったのに、権限は <code>-r--r--r--</code> のままである。
このファイルの持ち主は <code>lab</code> 自身で、持ち主はいつでも権限を変えられる。vim は <code>!</code> を付けられると書き込みを押し通し、
<b>書き終えたファイルに元の権限（444）を付け直す</b>（どう書いたかは次の記録で確かめる）。<code>444</code> は「うっかり書かない」ための印で、持ち主に対する鍵ではない。
シェルの <code>&gt;&gt;</code> は権限を変えようとしないので、そのまま断られた。</div></div>
<p>「どう書いたか」は i ノード番号で分かる。ハードリンク（同じ実体に付いた2つ目の名前。第6章）がある場合と比べた。</p>
<pre><code>@@+
$ cp memo.txt ro3.txt; chmod 444 ro3.txt
$ ls -i ro3.txt
$ vim ro3.txt
$ ls -i ro3.txt
$ stat -c "%A %s %n" ro3.txt
$ cp memo.txt ro4.txt; chmod 444 ro4.txt; ln ro4.txt ro4-link.txt
$ ls -i ro4.txt ro4-link.txt
$ vim ro4.txt
$ ls -i ro4.txt ro4-link.txt
$ stat -c "%A %s %n" ro4.txt ro4-link.txt
@@</code></pre>
<p>ハードリンクの無い <code>ro3.txt</code> は i ノード番号が変わった（番号そのものは環境ごとに違う。見るのは変わったかどうか）。vim は元のファイルを脇へ退避して<b>新しいファイルを書き</b>、元と同じ権限を付けている。ハードリンクのある <code>ro4.txt</code> は番号が変わらず、もう1つの名前 <code>ro4-link.txt</code> からも書き換えた中身（19 バイト）が見える。こちらは同じ実体を<b>その場で書き換え</b>ていて、そのために一時的に書き込み権を足し、書き終えてから元の権限に戻している。どちらで書くかは、vim の設定 <code>backupcopy</code>（既定は <code>auto</code>）がファイルの状況を見て決める。</p>
<p>Ex モード（<code>vim -es</code>）で同じことをすると、結果が変わった。</p>
<pre><code>@@
$ cp memo.txt ro2.txt; chmod 444 ro2.txt
$ vim -es -c "normal! dd" -c "w!" -c q ro2.txt; echo "exit=$?"
$ cat ro2.txt
$ vim -es -N -c "normal! dd" -c "w!" -c q ro2.txt; echo "exit=$?"
$ cat ro2.txt
@@</code></pre>
<p><code>vim -es</code> は設定ファイルを読まないので、昔の vi に合わせた<b>互換モード</b>で動く。互換モードでは「読み取り専用のファイルは <code>:w!</code> でも上書きしない」という設定（<code>cpoptions</code> の <code>W</code>）が入っていて、書かずに失敗した。<code>-N</code>（互換モードを切る）を付けると書けた（Ex モードはカーソルが最後の行から始まるので、消えたのは <code>date</code>）。<b>同じ <code>:w!</code> でも、設定で振る舞いが変わる</b>。この章の記録を対話の vim でとり直したのは、このためである。</p>
<p>もう1つ、対話の vim で気づきにくい振る舞いがある。開いたファイルの<b>前回のカーソル位置</b>を覚えていて、次に開いたときにそこへ戻る。</p>
<pre><code>@@
$ vim v1.txt ⟪k=2⟫
$ cat /tmp/pos.txt
$ grep -n -A3 "jump to the last known cursor" /usr/share/vim/vim91/defaults.vim
@@</code></pre>
<p><code>v1.txt</code> は前の節で <code>j dd</code> をして2行目で閉じたファイルで、開き直すとカーソルは2行目から始まった（開いた直後の行番号をファイルに書き出して確かめた）。Ubuntu の vim は、設定ファイルが無いと <code>defaults.vim</code> を読み、この振る舞いを入れる。2回目に開いたファイルで打ち始めるときは、まず <code>gg</code> で1行目へ移るとよい。</p>
<div class="analogy"><b>たとえ</b>: 自分の部屋のドアに<b>「立入禁止」の札</b>を掛けておくのに近い。他人には効くが、部屋の主は札を外して入り、出るときに掛け直せる。
<code>:w!</code> はその「外して入って掛け直す」を、vim が代わりにやっている。
<br>ただし<b>崩れる点</b>: 札を外して入るのは、ハードリンクがあってその場で書き換えるときだけである。ハードリンクが無ければ vim は、
隣に同じ部屋を建てて中身を移し、同じ札を掛けて元の部屋を取り壊す（i ノード番号が変わる）。どちらの場合も権限は元どおりなので、
<code>ls -l</code> の権限の欄には書き換えた跡が残らない。変わったのは中身・大きさ・更新時刻と、建て替えたときは i ノード番号である。</div>

<h2 id="nano">nano — 画面にキーが書いてあるエディタ</h2>
<div class="sgoal"><b>この節で分かること</b>: nano の基本操作と、vi との違い。</div>
<pre><code>@@
$ cp memo.txt n1.txt
$ nano n1.txt
$ cat n1.txt
$ cp memo.txt n2.txt
$ nano n2.txt
$ cat n2.txt
@@</code></pre>
<p>nano にはモードが無く、打った文字はそのまま入る。命令は <kbd>Ctrl</kbd> との組み合わせ（画面では <code>^K</code> のように書く）で、画面の下2行に主なキーの一覧が出ている。1つ目は <code>^K</code> で1行目を切り取り、<code>^O</code>（書き出し）で保存してから <code>^X</code> で終えた。2つ目は <code>^W</code> で <code>cherry</code> を探して切り取り、保存せずに <code>^X</code> を押したので「保存するか」と聞かれ、<code>y</code> と <kbd>Enter</kbd> で保存した。</p>
<div class="scroll"><table>
<tr><th>キー</th><th>意味</th></tr>
<tr><td><code>^O</code></td><td>書き出す（保存）。ファイル名を聞かれるので <kbd>Enter</kbd></td></tr>
<tr><td><code>^X</code></td><td>終わる（未保存なら保存するか聞かれる）</td></tr>
<tr><td><code>^W</code></td><td>探す</td></tr>
<tr><td><code>^K</code> / <code>^U</code></td><td>行を切り取る / 貼り付ける</td></tr>
<tr><td><code>^G</code></td><td>ヘルプ</td></tr>
</table></div>
<p>emacs も代表的なエディタで、nano と同じくモードが無く、<kbd>Ctrl</kbd> と <kbd>Alt</kbd>（Meta）の組み合わせで操作する（<code>C-x C-s</code> で保存、<code>C-x C-c</code> で終了）。大きなパッケージなので、この檻には入れていない。</p>

<h2 id="editor">標準のエディタを切り替える — EDITOR</h2>
<div class="sgoal"><b>この節で分かること</b>: プログラムが「どのエディタを開くか」をどこで決めているか。</div>
<p><code>crontab -e</code>、<code>visudo</code>、<code>sudoedit</code>、<code>less</code> の <kbd>v</kbd>、bash の <code>fc</code> などは、途中でエディタを開く。どれを開くかは、たいてい環境変数 <code>VISUAL</code> か <code>EDITOR</code> を見て決める。見る順番はプログラムごとに違い、<code>sensible-editor</code> は <code>VISUAL</code> → <code>EDITOR</code> の順、bash の <code>fc</code> は <code>FCEDIT</code> → <code>EDITOR</code> の順（<code>VISUAL</code> は見ない）である。何も設定していないときに何が開くかは、OS が決めている。</p>
<pre><code>@@
$ ls -l /usr/bin/vi /etc/alternatives/vi
$ ls -l /usr/bin/editor /etc/alternatives/editor
$ update-alternatives --display editor | head -4
$ update-alternatives --display editor | grep priority
$ editor --version | head -1
$ echo "[$EDITOR]"
@@</code></pre>
<p><code>vi</code> も <code>editor</code> も、<code>/etc/alternatives/</code> を経由したシンボリックリンクだった（Debian 系の「代替」の仕組み）。<code>vi</code> の実体は vim で、<code>editor</code> は nano を指している。nano の優先度（40）が vim（30）より高いからだ。Debian 系のプログラムは、<code>EDITOR</code> が空だと <code>/usr/bin/editor</code> を開くので、<b>この檻では何も設定しなければ nano が開く</b>（昔ながらの Unix の既定は vi）。</p>
<p>ここで第1章の話がそのまま効く。<code>sensible-editor</code> は Debian 系で「その人の標準のエディタ」を開くプログラムで、<code>VISUAL</code> → <code>EDITOR</code> の順に見る。<code>--version</code> を渡すと、起動したエディタが名乗る。</p>
<pre><code>@@
$ EDITOR=vi sensible-editor --version | head -1
$ EDITOR=nano sensible-editor --version | head -1
$ EDITOR=vi
$ bash -c "sensible-editor --version" < /dev/null | head -1
$ export EDITOR
$ bash -c "sensible-editor --version" | head -1
$ env | grep "^EDITOR="
$ unset EDITOR
$ command -v emacs; echo "exit=$?"
@@</code></pre>
<p><code>EDITOR=vi</code> とだけ打った後の子プロセス（<code>bash -c</code>）は nano を開いた。シェル変数のままでは子に届かないからだ。<code>export</code> した後は vim を開いた。だから標準のエディタを切り替えるときは <code>export EDITOR=vi</code>（nano にするなら <code>export EDITOR=nano</code>、emacs を入れてあれば <code>export EDITOR=emacs</code>）と書き、ずっと使うなら <code>~/.bashrc</code> にも書いておく。システム全体の既定を変えるのは <code>update-alternatives --config editor</code>（root が要る）である。<code>command -v emacs</code> が何も出さず終了コード 1 になったのは、この檻に emacs が無いからだ。</p>
<p>見る順番も確かめておく。<code>VISUAL</code> と <code>EDITOR</code> の両方があると、<code>sensible-editor</code> は <code>VISUAL</code> を使う。</p>
<pre><code>@@+
$ VISUAL=nano EDITOR=vi sensible-editor --version < /dev/null | head -1
@@</code></pre>
<p>ここまで <code>&lt; /dev/null</code> を付けてきたのには理由がある。<code>VISUAL</code> も <code>EDITOR</code> も無く、<code>~/.selected_editor</code> も無いとき、標準入力が端末だと <code>sensible-editor</code> は、エディタを開く前に選択画面（<code>select-editor</code>）を出す。端末の上で打った記録で見る（プロンプトは <code>$ </code> にそろえてある）。</p>
<pre><code>{{SESSION+ 2-12}}
...
{{SESSION+ 58-65}}</code></pre>
<p>選んだものは <code>~/.selected_editor</code> に保存され、以後は（<code>VISUAL</code> と <code>EDITOR</code> が無ければ）<code>/usr/bin/editor</code> より優先される。標準入力を端末から外した <code>&lt; /dev/null</code> でも vim が開くようになった。ファイルを消すと元に戻る（この檻はホームディレクトリをボリュームに置いていないので、起動し直しても消える）。</p>
<p>もう1つの落とし穴は <code>sudo</code> である。<code>sudo</code> はコマンドを root で動かす前に、環境変数を入れ直す（<code>env_reset</code>）。Ubuntu の既定の <code>/etc/sudoers</code> では、<code>EDITOR</code> を引き継ぐ行（<code>env_keep</code>）はコメントになっている。</p>
<pre><code>@@+
$ sudo grep -n -E "env_reset|EDITOR" /etc/sudoers
$ export EDITOR=vi
$ sudo env | grep "^EDITOR="; echo "exit=$?"
$ sudo EDITOR=vi env | grep "^EDITOR="
$ unset EDITOR
@@</code></pre>
<p><code>export</code> した <code>EDITOR</code> は、<code>sudo</code> の先のプログラム（ここでは <code>env</code>）に届かなかった。だから <code>sudo visudo</code> のエディタを変えるなら、<code>sudo EDITOR=nano visudo</code> のように <code>sudo</code> の後ろで渡す（この檻の <code>lab</code> は sudo で何でも実行できる設定なので、こう渡せる）。<code>sudoedit</code> は sudo を呼んだ人の <code>SUDO_EDITOR</code> <code>VISUAL</code> <code>EDITOR</code> を見てエディタを選ぶので、<code>export</code> だけで効く。</p>
<div class="analogy"><b>たとえ</b>: 出前を頼むときの<b>「いつもの店」のメモ</b>に近い。メモ（<code>EDITOR</code>）があればその店に、無ければ町内会が決めた既定の店（<code>/usr/bin/editor</code>）に頼む。
<br>ただし<b>崩れる点</b>: 家族なら台所のメモを見に行けるが、子プロセスが見られるのは、生まれたときに手渡された写し（環境変数）だけである。
冷蔵庫に貼っただけのメモ（シェル変数）は、子には見えない。</div>
<div class="quiz"><b>確認</b>
<p>vi で編集中、変更を保存せずに終了するコマンドはどれか。</p>
<p>A. <code>:wq</code>　B. <code>:q!</code>　C. <code>ZZ</code>　D. <code>:w!</code></p>
<details><summary>答え</summary>
<p>B。<code>:wq</code> と <code>ZZ</code> は保存して終わる。<code>:w!</code> は（読み取り専用でも）押し通して保存し、終わらない。
変更がある状態の <code>:q</code> は <code>E37</code> で断られる。</p></details></div>
<div class="quiz"><b>確認</b>
<p>vi のノーマルモードで、カーソルのある行をコピーし、その下に貼り付けるキー操作を答えよ。また、挿入モードからノーマルモードに戻るキーは何か。</p>
<details><summary>答え</summary>
<p><code>yy</code> の後に <code>p</code>（実測の <code>v2.txt</code> で <code>apple</code> が2行になった）。挿入モードから戻るのは <code>ESC</code>。
上に貼るなら <code>P</code>。切り取って移すなら <code>dd</code> と <code>p</code>。</p></details></div>
<div class="quiz"><b>確認</b>
<p>vi で編集中の変更をすべて捨て、ファイルを最後に保存した状態から読み直すコマンドはどれか。</p>
<p>A. <code>:q!</code>　B. <code>:e!</code>　C. <code>:w!</code>　D. <code>u</code></p>
<details><summary>答え</summary>
<p>B。<code>:e!</code> は vi を開いたまま、保存済みの内容を読み直す（実測の <code>q2.txt</code> は2行消した後でも元のまま）。
<code>:q!</code> は捨てて終わる。<code>u</code> は直前の1つの変更だけを取り消す。</p></details></div>
<div class="quiz"><b>確認</b>
<p><code>crontab -e</code> で起動するエディタを nano にしたい。bash で設定する方法を答えよ。また、<code>sudo visudo</code> で nano を使うにはどうするか（Ubuntu の既定の sudoers の場合）。</p>
<details><summary>答え</summary>
<p><code>export EDITOR=nano</code>（<code>VISUAL</code> を先に見るプログラムもあるので、両方設定してもよい）。
ずっと使うなら <code>~/.bashrc</code> に書く。<code>export</code> を付けないと子プロセスに渡らず、実測では既定の nano（この檻の場合）が開いた。
<code>sudo visudo</code> には、export した <code>EDITOR</code> は届かない。sudo が環境変数を入れ直す（<code>env_reset</code>）からで、実測でも <code>sudo env</code> に <code>EDITOR</code> は無かった。
<code>sudo EDITOR=nano visudo</code> のように、sudo の後ろで渡す。</p></details></div>
<div class="note try"><b>手を動かす</b>:
実践編の<a href="/linuc-text/">演習08</a>は、vi で TODO ファイルを指定どおりに4か所直す課題で、判定は保存されたファイルの中身を読む。
<a href="/linuc-text/">演習01</a>は <code>EDITOR</code> を vi にして子プロセスに渡す課題で、判定が実際に <code>sensible-editor</code> を起動して、どのエディタが名乗るかを見る。</div>

<h2 id="spine">この10章を1本にする</h2>
<div class="sgoal"><b>この節で分かること</b>: 10章で確かめたことが、1つの事実から出ていたこと。</div>
<p>この主題で何度も出てきた驚きを並べ直す。どれも「<b>コマンドが受け取ったのは何か</b>」と問えば説明がつく。</p>
<div class="scroll"><table>
<tr><th>章</th><th>驚いたこと</th><th>コマンドが受け取ったもの</th><th>先に片づけたのは</th></tr>
<tr><td>1</td><td><code>echo '$HOME'</code> が <code>$HOME</code> と出る / <code>X=1 echo "[$X]"</code> が空</td><td>展開を済ませた後の文字列</td><td>シェル（引用符・変数）</td></tr>
<tr><td>2</td><td>目の前の <code>hello.sh</code> が見つからない</td><td>（起動されなかった）</td><td>シェル（<code>PATH</code> の探索）</td></tr>
<tr><td>3</td><td><code>echo --version</code> が <code>--version</code> と出る</td><td>（組み込みが先に答えた）</td><td>シェル（組み込みコマンド）</td></tr>
<tr><td>4</td><td><code>wc -l &lt; file</code> にファイル名が出ない</td><td>中身だけ（名前は知らない）</td><td>シェル（リダイレクト）</td></tr>
<tr><td>5</td><td><code>tr</code> にファイル名を渡すと拒否される</td><td>標準入力だけを読む作り</td><td>シェルに <code>&lt;</code> で渡してもらう</td></tr>
<tr><td>6</td><td><code>sed</code> ではファイルが変わらない</td><td>読むためのファイル名</td><td>書き先を決めるのは <code>-i</code> かシェル</td></tr>
<tr><td>7</td><td><code>2&gt;&amp;1 &gt; f</code> でエラーが画面に残る / <code>sort f &gt; f</code> が空になる</td><td>配線済みの口</td><td>シェル（左から順に配線）</td></tr>
<tr><td>8</td><td>空白入りの名前が <code>xargs</code> で割れる</td><td>区切られた後の引数</td><td><code>xargs</code>（とシェルのコマンド置換）</td></tr>
<tr><td>9</td><td><code>grep a* fruits.txt</code> が何も出さない</td><td>ファイル名に置き換わったパターン</td><td>シェル（ワイルドカード）</td></tr>
<tr><td>10</td><td><code>EDITOR=vi</code> だけでは nano が開く</td><td>起動時に渡された環境変数の写し</td><td>シェル（<code>export</code> したものだけ渡す）</td></tr>
</table></div>
<div class="goal">
<p><b>コマンドが受け取るのは、シェルが組み立て終えた後の文字列だけである。</b>
引用符・変数・ワイルドカード・リダイレクト・パイプは、コマンドが動き出す前にシェルが片づけている。</p>
<p>vi は、この事実のちょうど裏側にいる。vi の中で打ったキーはシェルを通らないので、<code>*</code> も <code>$</code> も <code>|</code> もただの文字として入る。
そのかわり、vi を<b>どれにするか</b>は、シェルが起動のときに渡す環境変数でしか伝えられない。第1章の <code>export</code> に戻ってきた。</p>
</div>

<h2 id="wrap">この章で分かったこと</h2>
<div class="goal"><h4>持ち帰ってほしいこと</h4><ul><li>vi はモードで同じキーの意味が変わる。<code>i</code> <code>a</code> <code>o</code> <code>O</code> で挿入、<code>ESC</code> でノーマル、<code>:</code> でコマンドライン</li><li><code>h j k l</code> で動く。<code>dd</code> は切り取り、<code>yy</code> は写し、<code>p</code> / <code>P</code> で貼る。<code>c</code> <code>d</code> <code>y</code> は動きのキーと組み合わせる（<code>cw</code> <code>d$</code> <code>yw</code>）</li><li><code>/</code> は下向き、<code>?</code> は上向きに探す。<code>n</code> で次</li><li><code>:q!</code> は捨てて終わる、<code>:e!</code> は読み直す、<code>ZZ</code> は保存して終わる。<code>:w!</code> は持ち主なら読み取り専用のファイルにも書き、権限は 444 のまま（ハードリンクが無ければ新しいファイルとして書くので i ノード番号が変わる）</li><li>nano は <code>^O</code> 保存、<code>^X</code> 終了。標準のエディタは <code>export EDITOR=…</code> で変える（<code>VISUAL</code> を先に見るプログラムもある。sudo を通すなら <code>sudo EDITOR=… コマンド</code>）。Ubuntu の既定は <code>/usr/bin/editor</code>（alternatives）経由で nano</li></ul></div>
<div class="verified"><b>検証環境</b>: イメージ ghcr.io/chai0204/lab-linuc:text-1.0.1@sha256:__DIGEST__ / Ubuntu 24.04.5 LTS / bash 5.2.21 / coreutils 9.4 / grep 3.11 / sed 4.9 / findutils 4.9.0 / vim 9.1.0016 / nano 7.2 / less 590 / man-db 2.12.0 / apt snapshot 20260929T000000Z / docker 29.8.0・amd64 で検証 / 検証日 2026-10-13</div>
<nav class="pager"><a href="/linuc-text/theory/09-regex">← 9. . は何にでも当たる1文字</a><a href="/linuc-text/">次: 実践編（演習8本） →</a></nav>
<section id="comments">
<h2>コメント</h2>
<p class="detail">不具合でも感想でも、一言で構いません。GitHub アカウントでそのまま書けます。<br>   <b>本文と違う出力が出た場合</b>は <a href="https://github.com/chai0204/check-then-explain/issues/new/choose">Issue</a> のほうが、添える情報が決まっているので速く直せます。</p>
<div id="giscus"></div>
</section>
<footer><a href="/">トップ</a> · <a href="/linuc/">LinuC 出題範囲マップ</a> · <a href="/linuc-text/theory/">理論編 目次</a> · <a href="/linuc-text/theory/glossary">用語辞書</a></footer>
</div>
<script src="/linuc-text/chapters.js"></script>
<script src="/linuc-text/theory/terms.js"></script>
<script src="/shared/theory.js"></script>
<script src="/shared/comments.js"></script>
</body></html>
