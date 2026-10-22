<!doctype html>
<html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>1. 引用符と変数は、コマンドに届く前に片づく — 確かめて説明する LinuC 主題1.03</title>
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="/shared/style.css"></head>
<body data-draft="1" data-ch="1" data-theme="linuc-text">
<div class="wrap">
<nav class="top"><a href="/">トップ</a> › <a href="/linuc-text/">コマンドラインとテキスト処理</a> › <a href="/linuc-text/theory/">理論編</a> › 第1章</nav>
<div class="draftbar compact">
<p><b>ドラフト</b>: このテーマは著者が読者として通していません。出力はすべて実機の記録ですが、導線の不備が残っている可能性があります。<a href="/linuc-text/theory/#draft">詳しく</a></p>
</div>
<h1>1. 引用符と変数は、コマンドに届く前に片づく</h1>
<p class="lead"><code>echo '$HOME'</code> は <code>$HOME</code> と出し、<code>echo "$HOME"</code> は <code>/home/lab</code> と出す。違いを作ったのは <code>echo</code> ではない。<code>echo</code> に渡る前に、シェルが引用符を読んで、消している。そして変数に入れた値は、言わなければ次に起動するプログラムに届かない。</p>
<details class="fold intro">
<summary>この章のゴールと前提<span class="hint">所要 15分</span></summary>
<div class="badges"><span>前提: 檻が起動している</span><span>前提: cd と ls が打てる</span><span>所要 15分</span><span class="impact-a">影響度 A</span><span>出題範囲 1.03.1（重要度4）</span><span>最終検証 2026-10-13</span></div>
<div class="goal"><h4>この章のゴール</h4>
<ul><li>シングルクォート・ダブルクォート・バックスラッシュで、<code>$</code> と空白と <code>*</code> の扱いがどう変わるかを言える</li><li>シェル変数と環境変数の違いを、<code>set</code> と <code>env</code> の出力の差で示せる</li><li><code>export</code>・<code>unset</code>・<code>変数=値 コマンド</code> がそれぞれどこまで効くかを言える</li></ul>
<div class="skip"><b>ここで覚えなくていいこと</b>: 配列、<code>${変数:-既定値}</code> のようなパラメータ展開、<code>declare</code> の各オプション、<code>readonly</code>、<code>printf</code> の書式。どれも主題1.06（シェルスクリプト）の側で扱う。ここで覚えるのは、引用符3種類の違いと、<code>set</code> / <code>env</code> / <code>export</code> / <code>unset</code> の役割だけでよい。</div></div>
</details>
<p>この章からは、檻の中の <code>~/text</code> で打つ。練習用のファイルが置いてあり、檻を起動し直すたびに元の中身に戻る。</p>

<h2 id="quote">引用符は、シェルへの指示である</h2>
<div class="sgoal"><b>この節で分かること</b>: <code>echo</code> が受け取る前に、シェルが何をしているか。</div>
<pre><code>@@
$ cd ~/text
$ echo $HOME
$ echo '$HOME'
$ echo "$HOME"
$ echo \$HOME
@@</code></pre>
<p>4回とも打ったのは <code>echo</code> で、<code>echo</code> は受け取った文字をそのまま出すだけのコマンドである。出力が違うのは、<b>受け取ったものが違うから</b>だ。</p>
<ul>
<li><code>'$HOME'</code>（シングルクォート）: 中の文字に一切手を付けない。<code>echo</code> は <code>$HOME</code> という5文字を受け取った</li>
<li><code>"$HOME"</code>（ダブルクォート）: <code>$</code> で始まるもの（変数と <code>$(...)</code>）と、バッククォート <code>`...`</code> だけは置き換える。<code>echo</code> は <code>/home/lab</code> を受け取った</li>
<li><code>\$</code>（バックスラッシュ）: 直後の1文字だけ、特別な意味を消す</li>
</ul>
<p>どの場合も、<code>echo</code> には引用符そのものは届いていない。引用符は<b>シェルへの指示</b>で、読まれたあと消される。<code>$(...)</code> と <code>`...`</code>（コマンド置換）も同じ規則に従う。</p>
<pre><code>@@
$ echo "私は $(whoami) です"
$ echo '私は $(whoami) です'
$ echo "私は `whoami` です"
@@</code></pre>
<p>シェルが片づけるものは、変数だけではない。空白と <code>*</code> もそうである。</p>
<pre><code>@@
$ echo a     b
$ echo "a     b"
$ msg="a     b"
$ echo $msg
$ echo "$msg"
$ echo *.csv
$ echo "*.csv"
@@</code></pre>
<p>引用符の無い <code>a     b</code> は、シェルが空白で区切って <code>a</code> と <code>b</code> の2つの引数にした。<code>echo</code> は引数を空白1つでつないで出すので、5つあった空白が1つになる。変数を引用符なしで書いた <code>echo $msg</code> も同じで、<b>変数を展開した後にもう一度区切られる</b>。<code>*.csv</code> は、シェルが <code>~/text</code> の中のファイル名に置き換えてから <code>echo</code> に渡した（第9章で、これが <code>grep</code> を壊すところを見る）。</p>
<div class="scroll"><table>
<tr><th>書き方</th><th><code>$変数</code>・<code>$(...)</code>・<code>`...`</code></th><th>空白で区切る</th><th><code>*</code> をファイル名にする</th></tr>
<tr><td><code>'...'</code> シングルクォート</td><td>しない</td><td>しない</td><td>しない</td></tr>
<tr><td><code>"..."</code> ダブルクォート</td><td>する</td><td>しない</td><td>しない</td></tr>
<tr><td>引用符なし</td><td>する</td><td>する</td><td>する</td></tr>
<tr><td><code>\</code> の直後の1文字</td><td colspan="3">その1文字だけ、特別な意味を消す（<code>\$</code> <code>\"</code> <code>\*</code> <code>\ </code>）</td></tr>
</table></div>
<p><code>echo</code> 自身のオプションも2つ押さえる。<code>-e</code> は <code>\t</code>（タブ）や <code>\n</code>（改行）を解釈させ、<code>-n</code> は最後の改行を付けない。</p>
<pre><code>@@
$ echo -e 'a\tb'
$ echo 'a\tb'
$ echo -n "改行なし"; echo "←ここまでが1行"
@@</code></pre>
<div class="analogy"><b>たとえ</b>: 通訳に渡す原稿の書き込みに近い。
「ここは訳さずに原文のまま読んで」と囲んだ部分がシングルクォート、
「固有名詞だけ置き換えて、区切りは変えないで」と囲んだ部分がダブルクォートである。
<br>ただし<b>崩れる点</b>: 通訳は囲みの印に気づいた相手に「ここは原文です」と言い添えることがあるが、
シェルは印（引用符）を読んだら消してから渡す。<code>echo</code> は、自分の引数が引用符で囲まれていたかどうかを知る手段を持たない。</div>
<div class="quiz"><b>確認</b>
<p>変数 <code>HOME</code> の値が <code>/home/lab</code> のとき、<code>echo '$HOME' "$HOME"</code> の出力はどれか。</p>
<p>A. <code>$HOME $HOME</code>　B. <code>$HOME /home/lab</code>　C. <code>/home/lab /home/lab</code>　D. <code>'$HOME' "/home/lab"</code></p>
<details><summary>答え</summary>
<p>B。シングルクォートの中は展開されず、ダブルクォートの中の <code>$HOME</code> は展開される。
引用符そのものは <code>echo</code> に届かないので D にはならない。</p></details></div>

<h2 id="export">変数は、言わなければ子に渡らない</h2>
<div class="sgoal"><b>この節で分かること</b>: シェル変数と環境変数の違いと、<code>export</code> が何をするか。</div>
<p><code>child.sh</code> は、変数 <code>GREETING</code> の中身を表示するだけのスクリプトである。<code>bash child.sh</code> と打つと、今のシェルとは別の bash が起動してこれを読む。</p>
<div class="naive"><h4>ふつうこう考える</h4>
<p>変数に値を入れたのだから、そのあと起動するスクリプトからも見えるはずだ。
同じ端末で、同じユーザが、続けて打っているのだから。</p>
<pre><code>@@
$ cat child.sh
$ GREETING=hello
$ echo "$GREETING"
$ bash child.sh
@@</code></pre>
<div class="then"><b>だめな理由</b>: 今のシェルの中では <code>hello</code> なのに、スクリプトからは空に見える。
<code>bash child.sh</code> で動いたのは<b>新しく作られた別のプロセス</b>（子プロセス）で、
親のシェルが持っている変数を勝手には受け取らない。
<code>GREETING=hello</code> が作ったのは、そのシェルの中だけで使える<b>シェル変数</b>である。
子に写しが渡るのは、<b>環境変数</b>という印の付いた変数だけで、その印を付けるのが <code>export</code> だ。</div></div>
<pre><code>@@
$ export GREETING
$ bash child.sh
$ env | grep GREETING
$ set | grep "^GREETING="
@@</code></pre>
<p><code>export</code> した後は子から見える。<code>env</code> は環境変数だけを、<code>set</code> はシェル変数と環境変数の両方（と関数）を出す。片方にしか出ない変数を作ると、違いがはっきりする。</p>
<pre><code>@@
$ LOCAL_ONLY=here
$ set | grep "^LOCAL_ONLY="
$ env | grep "^LOCAL_ONLY="; echo "exit=$?"
$ export -p | grep GREETING
@@</code></pre>
<p><code>env</code> は1行も出さず、<code>grep</code> が「見つからない」（終了コード 1）を返した。<code>export -p</code> は環境変数の一覧を <code>declare -x</code> の形で出す。<code>-x</code> が「子に渡す」印である。</p>
<p>既定で入っている変数にも、両方の種類がある。<code>PATH</code> は環境変数で、<code>HISTSIZE</code>（履歴の件数。第2章）は <code>~/.bashrc</code> が作ったシェル変数だ。</p>
<pre><code>@@
$ env | grep -c "^PATH="
$ set | grep -c "^PATH="
$ set | grep -c "^HISTSIZE="
$ env | grep -c "^HISTSIZE="
$ echo $SHLVL; bash -c "echo \$SHLVL"
@@</code></pre>
<p class="detail">どちらになるかはディストリビューションの設定で決まる。RHEL 系（AlmaLinux など）では <code>/etc/profile</code> が <code>HISTSIZE</code> を <code>export</code> しているので、<code>env</code> にも出る。試験の例題で <code>export</code> の一覧に <code>HISTSIZE</code> が並んでいるのは、そのためである。</p>
<p><code>SHLVL</code> は「シェルが何段入れ子になっているか」を数える環境変数で、子の bash では 2 になった。<code>bash -c</code> や <code>bash child.sh</code> が別のプロセスであることが、ここでも見える。</p>
<div class="scroll"><table>
<tr><th>コマンド</th><th>やること</th><th>出すもの・効く範囲</th></tr>
<tr><td><code>変数=値</code></td><td>シェル変数を作る・書き換える</td><td>このシェルの中だけ</td></tr>
<tr><td><code>export 変数</code> / <code>export 変数=値</code></td><td>環境変数にする（子に渡す印を付ける）</td><td>以後に起動する子プロセスすべて</td></tr>
<tr><td><code>unset 変数</code></td><td>変数を消す</td><td>シェル変数でも環境変数でも消える</td></tr>
<tr><td><code>set</code></td><td>引数なしなら一覧を出す</td><td>シェル変数・環境変数・関数のすべて</td></tr>
<tr><td><code>env</code> / <code>printenv</code></td><td>引数なしなら一覧を出す（<code>printenv 名前</code> は1つだけ）</td><td>環境変数だけ</td></tr>
<tr><td><code>export -p</code></td><td>一覧を出す</td><td>環境変数だけ（<code>declare -x</code> の形）</td></tr>
</table></div>
<div class="analogy"><b>たとえ</b>: 部署異動するときの<b>引き継ぎ書類</b>に近い。
自分の机のメモ（シェル変数）は自分しか読まないが、引き継ぎ書類に書いたもの（環境変数）は、
新しく来た人（子プロセス）が最初に1部ずつ受け取る。<code>export</code> は「これを書類に載せる」という指示である。
<br>ただし<b>崩れる点</b>: 書類は渡した後で書き直せば相手に伝えられるが、環境変数は<b>起動の瞬間の写し</b>しか渡らない。
動いている子に後から値を伝える手段は無いし、子が書き換えた値が親に戻ることもない。</div>

<h2 id="scope">1回だけ渡す・空にして起動する・消す</h2>
<div class="sgoal"><b>この節で分かること</b>: コマンドの前に書く <code>変数=値</code> と、<code>env</code> と <code>unset</code> が効く範囲。</div>
<pre><code>@@
$ GREETING=bye bash child.sh
$ echo "$GREETING"
$ env GREETING=env-bye bash child.sh
$ env -i bash child.sh
@@</code></pre>
<p>コマンドの前に <code>変数=値</code> を並べると、<b>そのコマンドにだけ</b>環境変数として渡る。シェルの <code>GREETING</code> は <code>hello</code> のまま変わっていない。<code>env 変数=値 コマンド</code> も同じことをする別の書き方で、<code>env -i</code> は環境変数を<b>全部空にして</b>から起動する。</p>
<pre><code>@@
$ unset GREETING
$ echo "[$GREETING]"
$ bash child.sh
@@</code></pre>
<p>ここで、この章の要点がもう一度出てくる。</p>
<pre><code>@@
$ X=1 echo "[$X]"
$ X=1; echo "[$X]"
@@</code></pre>
<p>1行目は空になった。<code>X=1 echo ...</code> の <code>X=1</code> は「<code>echo</code> の環境に渡す」という意味で、<code>"[$X]"</code> の展開は<b>それより前に</b>シェルが済ませている。<code>echo</code> が受け取ったのはすでに <code>[]</code> だった。2行目は <code>;</code> で区切ったので、<code>X=1</code> が先に終わってから <code>echo</code> の行が展開された。</p>
<div class="analogy"><b>たとえ</b>: 宅配便の箱に貼る<b>1回限りの付箋</b>に近い。<code>GREETING=bye bash child.sh</code> は、
その1箱にだけ「中身は bye」と付箋を貼って送る。手元の台帳（シェル変数）は書き換えない。
<br>ただし<b>崩れる点</b>: 付箋は箱を詰める前でも後でも貼れるが、シェルは<b>先に箱の中身（引数）を詰め終えてから</b>付箋を貼る。
だから <code>X=1 echo "[$X]"</code> の引数には付箋の値が間に合わない。</div>
<p><code>set</code> にはもう1つ役目がある。シェルの動き方（オプション）の切り替えだ。<code>set -o</code> で今の状態が見られる。<code>noclobber</code>（第7章）と <code>xtrace</code> は、名前を知っておく価値がある。</p>
<pre><code>@@
$ set -o | grep -E "^(noclobber|xtrace|history) "
$ bash -x child.sh
@@</code></pre>
<p><code>xtrace</code>（<code>set -x</code>、<code>bash -x</code>）は、<b>シェルが組み立て終えたコマンド</b>を <code>+</code> を付けて表示する。<code>$GREETING</code> が展開された後の文字列が見える。この章で言ってきたことが、そのまま画面に出ている。</p>
<div class="quiz"><b>確認</b>
<p>シェル変数 <code>FOO</code> を、このシェルから起動するコマンドでも参照できるようにするコマンドはどれか。</p>
<p>A. <code>set FOO</code>　B. <code>export FOO</code>　C. <code>env FOO</code>　D. <code>unset FOO</code></p>
<details><summary>答え</summary>
<p>B。<code>export</code> がシェル変数に「子に渡す」印を付けて環境変数にする。
<code>set</code> は一覧の表示（とオプションの切り替え）、<code>env</code> は環境変数の一覧の表示か、環境を変えてコマンドを起動するもの、<code>unset</code> は削除である。</p></details></div>
<div class="quiz"><b>確認</b>
<p>変数 <code>X</code> が未定義のとき、<code>X=1 echo "[$X]"</code> の出力は何か。</p>
<details><summary>答え</summary>
<p><code>[]</code>。<code>"[$X]"</code> はコマンドを起動する前にシェルが展開するので、その時点で <code>X</code> は空である。
<code>X=1</code> は <code>echo</code> の環境に入るが、<code>echo</code> は環境変数を読まない。
<code>X=1; echo "[$X]"</code> と <code>;</code> で区切れば <code>[1]</code> になる。</p></details></div>
<div class="quiz"><b>確認</b>
<p>環境変数だけを一覧表示するコマンドを2つ挙げよ。シェル変数も含めて表示するのはどれか。</p>
<details><summary>答え</summary>
<p>環境変数だけ: <code>env</code>（引数なし）、<code>printenv</code>（引数なし）、<code>export -p</code>（<code>declare -x</code> も同じ一覧を出す）。このうち2つを挙げれば正解。シェル変数も含めるのは <code>set</code>（引数なし）。
実測では <code>LOCAL_ONLY=here</code> が <code>set</code> にだけ出て、<code>env</code> には出なかった。</p></details></div>
<div class="note try"><b>手を動かす</b>:
実践編の<a href="/linuc-text/practice/">演習01</a>は、エディタの指定（<code>EDITOR</code>）を子プロセスに渡す課題である。
判定は <code>lab check</code> 自身が子プロセスとして見えた値で行うので、<code>export</code> を忘れると必ず鳴る。</div>

<h2 id="wrap">この章で分かったこと</h2>
<div class="goal"><h4>持ち帰ってほしいこと</h4><ul><li>引用符はシェルへの指示で、読まれたあと消える。コマンドに届くのは展開した後の文字列だけ</li><li><code>'...'</code> は何も展開しない。<code>"..."</code> は <code>$</code>（変数・<code>$(...)</code>）と <code>`...`</code> を展開し、空白で区切らず、<code>*</code> も展開しない。引用符なしは展開して、空白で区切って、<code>*</code> もファイル名にする</li><li><code>変数=値</code> はシェル変数。子プロセスに渡すには <code>export</code> して環境変数にする</li><li><code>set</code> は全部、<code>env</code> と <code>export -p</code> は環境変数だけを出す。<code>unset</code> で消す</li><li><code>変数=値 コマンド</code> はそのコマンドにだけ渡す。ただし引数の展開はその前に済んでいる</li></ul></div>
<div class="verified"><b>検証環境</b>: イメージ ghcr.io/chai0204/lab-linuc:text-1.0.1@sha256:be6456726a12d28311a0d10b518939a3dd43642a49647edc37d12ba374bec63d / Ubuntu 24.04.5 LTS / bash 5.2.21 / coreutils 9.4 / grep 3.11 / sed 4.9 / findutils 4.9.0 / vim 9.1.0016 / nano 7.2 / less 590 / man-db 2.12.0 / apt snapshot 20260929T000000Z / docker 29.8.0・amd64 で検証 / 検証日 2026-10-13</div>
<nav class="pager"><a href="/linuc-text/theory/">← 理論編 目次</a><a href="/linuc-text/theory/02-path">次: 2. コマンドを探すのはシェルで、カレントは探さない →</a></nav>
<section id="comments">
<h2>コメント</h2>
<p class="detail">不具合でも感想でも、一言で構いません。GitHub アカウントでそのまま書けます。<br>   <b>本文と違う出力が出た場合</b>は <a href="https://github.com/chai0204/check-then-explain/issues/new/choose">Issue</a> のほうが、添える情報が決まっているので速く直せます。</p>
<div id="giscus"></div>
</section>
<footer><a href="/">トップ</a> · <a href="/linuc-text/">コマンドラインとテキスト処理</a> · <a href="/linuc-text/theory/">理論編 目次</a> · <a href="/linuc-text/practice/">実践編</a> · <a href="/linuc-text/theory/glossary">用語辞書</a></footer>
</div>
<script src="/shared/site.js"></script>
<script src="/linuc-text/chapters.js"></script>
<script src="/linuc-text/theory/terms.js"></script>
<script src="/shared/theory.js"></script>
<script src="/shared/comments.js"></script>
</body></html>
