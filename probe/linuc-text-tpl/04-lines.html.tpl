<!doctype html>
<html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>4. 1行とは、改行で終わっている範囲のこと — 確かめて説明する LinuC 主題1.03</title>
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="/shared/style.css"></head>
<body data-draft="1" data-ch="4" data-theme="linuc-text">
<div class="wrap">
<nav class="top"><a href="/">トップ</a> › <a href="/linuc/">LinuC</a> › <a href="/linuc-text/theory/">理論編</a> › 第4章</nav>
<div class="draftbar compact">
<p><b>ドラフト</b>: このテーマは著者が読者として通していません。出力はすべて実機の記録ですが、導線の不備が残っている可能性があります。<a href="/linuc-text/theory/">詳しく</a></p>
</div>
<h1>4. 1行とは、改行で終わっている範囲のこと</h1>
<p class="lead">画面では2行に見えるファイルを、<code>wc -l</code> は 1 と数える。<code>wc -l</code> が数えているのは「行」ではなく<b>改行文字の数</b>だからだ。この章のフィルタはどれも、テキストを行の集まりではなく<b>バイトの並び</b>として受け取り、改行文字を区切りとして扱っている。</p>
<div class="badges"><span>前提: 第1章</span><span>前提: 檻が起動している</span><span>所要 16分</span><span class="impact-b">影響度 B</span><span>出題範囲 1.03.2（重要度3）</span><span>最終検証 2026-10-13</span></div>
<div class="goal"><h4>この章のゴール</h4>
<ul><li><code>cat</code> <code>head</code> <code>tail</code> <code>wc</code> <code>nl</code> <code>od</code> <code>less</code> の役割と、試験に出るオプションを言える</li><li>「行」が改行文字で区切られていることを <code>od -c</code> で確かめられる</li><li>Windows の改行（CRLF）のファイルを、見た目ではなく中身で見分けられる</li></ul>
<div class="skip"><b>ここで覚えなくていいこと</b>: <code>od</code> の出力形式の全種類、<code>less</code> の設定（環境変数 <code>LESS</code>）、<code>tail -F</code> と <code>--pid</code>、<code>wc -L</code> の細部。文字コード（UTF-8 のバイト列の読み方）も扱わない。</div></div>

<h2 id="peek">先頭と末尾だけを見る</h2>
<div class="sgoal"><b>この節で分かること</b>: <code>cat</code> <code>head</code> <code>tail</code> の行の数え方。</div>
<pre><code>@@
$ cd ~/text
$ cat fruits.txt
$ cat -n fruits.txt
$ head -3 fruits.txt
$ tail -2 fruits.txt
$ tail -n +6 fruits.txt
$ head -n -5 fruits.txt
@@</code></pre>
<p><code>cat</code> はファイルの中身をそのまま流し、<code>-n</code> で行番号を付ける。<code>head</code> は先頭から、<code>tail</code> は末尾から数えて出す（指定しなければ10行）。<code>-3</code> は <code>-n 3</code> の短い書き方で、どちらでも同じ結果になる。</p>
<div class="scroll"><table>
<tr><th>書き方</th><th>意味</th></tr>
<tr><td><code>head -n 3</code> / <code>head -3</code></td><td>先頭の3行</td></tr>
<tr><td><code>head -n -5</code></td><td>最後の5行を<b>除いた</b>全部</td></tr>
<tr><td><code>tail -n 2</code> / <code>tail -2</code></td><td>末尾の2行</td></tr>
<tr><td><code>tail -n +6</code></td><td><b>6行目から</b>最後まで（見出し行を飛ばすときに使う。第5章）</td></tr>
<tr><td><code>head -c 12</code></td><td>先頭の12<b>バイト</b></td></tr>
<tr><td><code>tail -f</code></td><td>末尾を出したあと終わらず、追記されるたびに出し続ける（この章の最後）</td></tr>
</table></div>
<p><code>-c</code> は行ではなくバイトで数える。</p>
<pre><code>@@
$ head -c 12 fruits.txt
@@</code></pre>
<p><code>banana</code> と改行で7バイト、<code>apple</code> で5バイト、合わせて12バイトで止まった。最後に改行が無いので、端末では次のプロンプトが <code>apple</code> のすぐ後ろに続けて表示される。</p>
<div class="analogy"><b>たとえ</b>: 本の<b>最初の数ページ</b>（<code>head</code>）と<b>最後の数ページ</b>（<code>tail</code>）だけを立ち読みするのに近い。
<code>tail -n +6</code> は「6ページ目から最後まで」で、<code>head -n -5</code> は「最後の5ページを残して全部」だ。
<br>ただし<b>崩れる点</b>: 本のページは印刷で決まっているが、ここでの「行」は改行文字の位置で決まる。
改行の無い長い1行は、画面で何行に折り返されていても1行として数えられる。</div>

<h2 id="count">wc が数えているもの</h2>
<div class="sgoal"><b>この節で分かること</b>: <code>wc</code> の3つの数と、行の終わりが何で決まるか。</div>
<pre><code>@@
$ wc fruits.txt
$ wc -l fruits.txt
$ wc -w -c fruits.txt
$ wc -l < fruits.txt
$ cat fruits.txt | wc -l
@@</code></pre>
<p><code>wc</code> は左から<b>行数・単語数・バイト数</b>を出す。<code>-l</code> <code>-w</code> <code>-c</code> で1つずつ選べる。<code>wc -l &lt; fruits.txt</code> と <code>cat ... | wc -l</code> ではファイル名が出ない。リダイレクトとパイプでは、ファイルを開いたのはシェル（や <code>cat</code>）で、<code>wc</code> は名前を受け取っていない。<code>wc</code> に届いたのは中身だけだ（第7章・第8章）。</p>
<div class="naive"><h4>ふつうこう考える</h4>
<p><code>wc -l</code> は行の数を数える。画面に2行出るファイルなら 2 と出るはずだ。</p>
<pre><code>@@
$ cat notail.txt
$ wc -l notail.txt
@@</code></pre>
<div class="then"><b>だめな理由</b>: 2行見えるのに 1 と数えた。<code>wc -l</code> が数えているのは<b>改行文字（LF、<code>\n</code>）の個数</b>である。
このファイルは最後の行の後ろに改行が無いので、改行は1つしかない。
<code>cat</code> の直後にプロンプトが <code>second line</code> の後ろへ続けて出たのも、同じ理由だ。
中身をバイトで見ると分かる。</div></div>
<pre><code>@@
$ od -c notail.txt
$ cat -A notail.txt
$ echo >> notail.txt; wc -l notail.txt
@@</code></pre>
<p><code>od -c</code> はバイトを1文字ずつ並べる。<code>\n</code> は <code>first line</code> の後ろに1つだけで、<code>second line</code> の後ろには無い。<code>cat -A</code> は改行の位置に <code>$</code> を出すので、2行目の行末に <code>$</code> が無い。<code>echo &gt;&gt;</code> で改行を1つ足すと、2 と数えた。</p>
<div class="analogy"><b>たとえ</b>: 文章の文の数を<b>句点（。）の数で数える</b>のに近い。最後の文に句点を打ち忘れると、その文は数に入らない。
<br>ただし<b>崩れる点</b>: 人が数えるなら句点が無くても文だと分かるが、<code>wc -l</code> は中身を読まずに句点だけを数える。
「文らしいかどうか」は一切見ない。</div>

<h2 id="bytes">見た目が同じ2つのファイル</h2>
<div class="sgoal"><b>この節で分かること</b>: <code>od</code> の読み方と、改行コードの違いの見分け方。</div>
<pre><code>@@
$ cat unix.txt
$ cat win.txt
$ wc -c unix.txt win.txt
@@</code></pre>
<p>表示は同じなのに、大きさが2バイト違う。</p>
<pre><code>@@
$ od -c unix.txt
$ od -c win.txt
$ cat -A win.txt
@@</code></pre>
<p><code>win.txt</code> は各行の終わりが <code>\r\n</code>（CR と LF の2バイト）になっている。Windows のメモ帳などが書く<b>改行コード</b>で、CRLF と呼ぶ。Linux の道具は LF だけを行の区切りとして扱うので、CR は<b>行の最後の文字</b>として残る。<code>cat -A</code> では <code>^M</code> と見える。この CR が残ったままだと、第9章で見るように <code>grep 'line1$'</code>（行末が line1）が当たらなくなる。</p>
<p><code>od</code> の左端の数字は、その行の先頭が何バイト目かを<b>8進数</b>で表す（<code>0000014</code> は12、<code>0000016</code> は14）。オプションで形式を変えられる。</p>
<pre><code>@@
$ od -An -tx1 unix.txt
$ od -t x1 -A d unix.txt
@@</code></pre>
<div class="scroll"><table>
<tr><th>書き方</th><th>意味</th></tr>
<tr><td><code>od -c</code></td><td>1バイトずつ文字で（<code>\n</code> <code>\r</code> <code>\t</code> などの記号を使う）</td></tr>
<tr><td><code>od -t x1</code> / <code>-tx1</code></td><td>1バイトずつ16進数で（<code>0a</code> が LF、<code>0d</code> が CR）</td></tr>
<tr><td><code>od -A d</code> / <code>-A n</code></td><td>左端の位置を10進数で / 出さない</td></tr>
<tr><td><code>cat -A</code></td><td>行末に <code>$</code>、TAB を <code>^I</code>、CR を <code>^M</code> と見せる</td></tr>
</table></div>
<div class="analogy"><b>たとえ</b>: タイプライターの<b>改行レバー</b>に近い。CR（carriage return）は印字位置を左端へ戻す動き、LF（line feed）は紙を1行送る動きで、
Windows はファイルに両方を書き、Linux は LF だけを書く。
<br>ただし<b>崩れる点</b>: タイプライターは両方の動きをしないと次の行の左端に打てない。Linux のファイルには LF しか書かれていないのに画面では左端から次の行が始まるのは、
端末へ出すときにカーネルの端末ドライバ（<code>onlcr</code> という設定）が LF の前に CR を足しているからだ。
ファイルの中の CR は、画面ではカーソルを左端へ戻すだけで何も表示されないので、見えない1文字としてファイルに残り続ける。</div>

<h2 id="nl">行に番号を振る</h2>
<div class="sgoal"><b>この節で分かること</b>: <code>nl</code> と <code>cat -n</code> の違い。</div>
<pre><code>@@
$ cat blank.txt
$ nl blank.txt
$ cat -n blank.txt
$ nl -b a blank.txt
$ nl -w 2 -s ": " fruits.txt
@@</code></pre>
<p><code>nl</code> は既定で<b>空行に番号を振らない</b>。<code>third</code> は3行目なのに番号は 2 になった。<code>cat -n</code> と同じように全行へ振るには <code>-b a</code>（body の行を all）を付ける。<code>-w</code> は番号の桁数、<code>-s</code> は番号と本文の間に入れる文字である。</p>

<h2 id="less">less と tail -f</h2>
<div class="sgoal"><b>この節で分かること</b>: 画面を開く <code>less</code> が、パイプの途中では何をするか。追記を見張る <code>tail -f</code> の終わり方。</div>
<p><code>less ファイル</code> は、長いファイルを1画面ずつ見るページャで、<code>man</code> の画面と同じ操作で動く（第3章の表）。<kbd>q</kbd> で閉じ、<kbd>/</kbd> で探し、<kbd>G</kbd> で末尾へ行く。出力の行き先が端末でないときは、画面を開かず、受け取ったものをそのまま流す。</p>
<pre><code>@@
$ less fruits.txt | head -3
$ seq 1 100 | less | tail -2
@@</code></pre>
<p><code>tail -f</code> はファイルの末尾を出したあと終わらずに待ち、追記された行を出し続ける。ログを見張るときに使い、<kbd>Ctrl</kbd>+<kbd>C</kbd> で止める。ここでは <code>timeout 2</code> で2秒後に止めた。</p>
<pre><code>@@
$ printf "line %s\n" 1 2 3 > /tmp/watch.log
$ timeout 2 tail -f /tmp/watch.log; echo "exit=$?"
@@</code></pre>
<p>終了コード <code>124</code> は、<code>timeout</code> が時間切れで止めたという意味で、<code>tail -f</code> が自分からは終わらなかったことを示す。待っている間に別のプロセスが追記すると、その行がすぐに出る。</p>
<pre><code>@@
$ (sleep 1; echo "あとから追記した行" >> /tmp/watch.log) | timeout 3 tail -n 1 -f /tmp/watch.log; echo "exit=$?"
@@</code></pre>
<p class="detail">この1行は「1秒後に追記する」処理と <code>tail -f</code> を同時に動かすために、パイプでつないでいる（<code>tail</code> はファイル名を渡されているので、パイプから来るものは読まない）。端末を2つ開けるなら、片方で <code>tail -f</code>、もう片方で <code>echo ... &gt;&gt;</code> と打てば同じことが起きる。</p>
<div class="quiz"><b>確認</b>
<p><code>printf 'a\nb' &gt; f.txt</code> を実行した後、<code>wc -l f.txt</code> の出力はどれか。</p>
<p>A. <code>0 f.txt</code>　B. <code>1 f.txt</code>　C. <code>2 f.txt</code>　D. <code>3 f.txt</code></p>
<details><summary>答え</summary>
<p>B。<code>wc -l</code> は改行文字の数を数える。<code>b</code> の後ろに改行が無いので、改行は1つ。
実測の <code>notail.txt</code> も同じで、改行を足すと 2 になった。</p></details></div>
<div class="quiz"><b>確認</b>
<p>ファイル <code>app.log</code> の最後の10行を表示し、その後も追記されるたびに表示し続けるコマンドはどれか。</p>
<p>A. <code>head -f app.log</code>　B. <code>tail -n +10 app.log</code>　C. <code>tail -f app.log</code>　D. <code>less -10 app.log</code></p>
<details><summary>答え</summary>
<p>C。<code>tail -f</code> は自分では終わらない（実測では <code>timeout</code> に止められて終了コード 124）。
B は「10行目から最後まで」を出して終わる。</p></details></div>
<div class="quiz"><b>確認</b>
<p>空行を含むファイルで、空行にも行番号を付けて表示したい。<code>nl</code> に付けるオプションはどれか。また、同じことをする <code>cat</code> のオプションは何か。</p>
<details><summary>答え</summary>
<p><code>nl -b a</code>。<code>nl</code> は既定（<code>-b t</code>）では空行を数えない。<code>cat -n</code> は空行にも番号を付ける。</p></details></div>
<div class="note try"><b>手を動かす</b>:
実践編の<a href="/linuc-text/">演習03</a>は、30行のアクセスログを集計する課題である。
集計を組む前に <code>head -3</code> と <code>wc -l</code> で中身と行数を確かめておくと、結果が合っているかを自分で判断できる。</div>

<h2 id="wrap">この章で分かったこと</h2>
<div class="goal"><h4>持ち帰ってほしいこと</h4><ul><li>行は改行文字（LF）で区切られている。<code>wc -l</code> は改行の数を数えるので、最後に改行の無い行は数えない</li><li><code>head -n 3</code> / <code>tail -n 2</code> / <code>tail -n +6</code>（6行目から）/ <code>head -n -5</code>（最後の5行以外）/ <code>-c</code> はバイト</li><li><code>wc</code> は行・単語・バイト。リダイレクトで渡すとファイル名を知らない</li><li><code>od -c</code> と <code>cat -A</code> で、見えない文字（<code>\r</code> <code>\t</code>、最後の改行の有無）が見える。CRLF は <code>\r\n</code></li><li><code>nl</code> は空行を飛ばす（<code>-b a</code> で全行）。<code>less</code> は端末以外へはそのまま流す。<code>tail -f</code> は終わらずに追記を待つ</li></ul></div>
<div class="verified"><b>検証環境</b>: イメージ ghcr.io/chai0204/lab-linuc:text-1.0.1@sha256:be6456726a12d28311a0d10b518939a3dd43642a49647edc37d12ba374bec63d / Ubuntu 24.04.5 LTS / bash 5.2.21 / coreutils 9.4 / grep 3.11 / sed 4.9 / findutils 4.9.0 / vim 9.1.0016 / nano 7.2 / less 590 / man-db 2.12.0 / apt snapshot 20260929T000000Z / docker 29.8.0・amd64 で検証 / 検証日 2026-10-13</div>
<nav class="pager"><a href="/linuc-text/theory/03-man">← 3. man が説明しているのは、打ったものと別物のことがある</a><a href="/linuc-text/theory/05-columns">次: 5. uniq は隣どうししか比べない →</a></nav>
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
