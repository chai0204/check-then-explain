<!doctype html>
<html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>5. uniq は隣どうししか比べない — 確かめて説明する LinuC 主題1.03</title>
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="/shared/style.css"></head>
<body data-draft="1" data-ch="5" data-theme="linuc-text">
<div class="wrap">
<nav class="top"><a href="/">トップ</a> › <a href="/linuc-text/">コマンドラインとテキスト処理</a> › <a href="/linuc-text/theory/">理論編</a> › 第5章</nav>
<div class="draftbar compact">
<p><b>ドラフト</b>: このテーマは著者が読者として通していません。出力はすべて実機の記録ですが、導線の不備が残っている可能性があります。<a href="/linuc-text/theory/#draft">詳しく</a></p>
</div>
<h1>5. uniq は隣どうししか比べない</h1>
<p class="lead"><code>fruits.txt</code> には <code>apple</code> が3行あるのに、<code>uniq</code> を通しても <code>apple</code> は2回出てくる。<code>uniq</code> は「直前の行と同じか」しか見ていない。この章のフィルタは、どれも<b>1行ずつ流れてくるものを、決まった規則で処理するだけ</b>で、ファイル全体を見渡してはいない。</p>
<details class="fold intro">
<summary>この章のゴールと前提<span class="hint">所要 20分</span></summary>
<div class="badges"><span>前提: 第4章</span><span>前提: 檻が起動している</span><span>所要 20分</span><span class="impact-b">影響度 B</span><span>出題範囲 1.03.2（重要度3）</span><span>最終検証 2026-10-13</span></div>
<div class="goal"><h4>この章のゴール</h4>
<ul><li><code>cut</code> で欄や文字を切り出し、区切り文字が連続したときに何が起きるかを説明できる</li><li><code>sort</code>（<code>-n -r -t -k -u -f</code>）と <code>uniq</code>（<code>-c -d -u</code>）を組み合わせて集計できる</li><li><code>tr</code> の置換・削除・圧縮と、<code>paste</code>（行で並べる）と <code>join</code>（キーで突き合わせる）の違いを言える</li></ul>
<div class="skip"><b>ここで覚えなくていいこと</b>: <code>sort -k2.3</code> のような文字位置の指定、<code>-s</code> <code>-b</code> <code>-g</code>、<code>join -o</code> による出力欄の指定、<code>tr</code> の文字クラス（<code>[:upper:]</code>）の全種類。<code>awk</code> は主題1.03 の範囲外なので、比べるために1か所だけ名前を出す。</div></div>
</details>

<h2 id="cut">欄を切り出す — cut</h2>
<div class="sgoal"><b>この節で分かること</b>: <code>cut</code> の区切り方と、区切り文字が続いたときの空の欄。</div>
<pre><code>@@
$ cd ~/text
$ cat scores.csv
$ cut -d, -f2 scores.csv
$ cut -d, -f2,4 scores.csv
$ cut -d, -f2- scores.csv
$ cut -c1-3 fruits.txt
@@</code></pre>
<p><code>-d</code> で区切り文字を決め、<code>-f</code> で何番目の欄かを選ぶ。<code>2,4</code> は2番目と4番目、<code>2-</code> は2番目から最後まで。<code>-c</code> は欄ではなく<b>文字の位置</b>で切る。区切り文字を指定しないと、既定は <b>TAB</b> である。</p>
<pre><code>@@
$ cat -A tabs.txt
$ cut -f2 tabs.txt
$ cut -d, -f2 tabs.txt
@@</code></pre>
<p>最後の行に注意する。<code>,</code> が1つも無い行は、<b>欄に分けられないので行ごとそのまま</b>出てきた（<code>-s</code> を付けると、こういう行を捨てる）。</p>
<p>次は、空白で桁をそろえた表である。</p>
<pre><code>@@
$ cat spaces.txt
$ cut -d" " -f2 spaces.txt | cat -A
$ cut -d" " -f4 spaces.txt
@@</code></pre>
<p>2番目の欄を取ったつもりが、3行とも空になった。<code>cut</code> の区切りは<b>1文字につき1回</b>で、<code>alice</code> の後ろの空白3つは「区切り・空の欄・区切り・空の欄・区切り」になる。だから4番目に <code>23</code> がある行と、空の行が混ざる。空白をまとめてから切ればそろう。</p>
<pre><code>@@
$ tr -s " " < spaces.txt
$ tr -s " " < spaces.txt | cut -d" " -f2
@@</code></pre>
<p class="detail">空白の数がそろっていない表は、連続した空白を1つの区切りとして扱う <code>awk '{print $2}'</code> のほうが向いている（主題1.03 の範囲外）。<code>cut</code> は「区切り文字がちょうど1つずつ入っている」データ向けの道具だ。</p>
<div class="analogy"><b>たとえ</b>: 列車の<b>連結器</b>を数えて何両目かを決めるのに近い。区切り文字が連結器で、その間が車両（欄）になる。
<br>ただし<b>崩れる点</b>: 実際の列車で連結器が2つ続くことは無いが、テキストではいくらでも続く。
<code>cut</code> はそのたびに「空の車両」を1両数えるので、見た目の列と番号がずれる。</div>

<h2 id="tr">文字を置き換える — tr</h2>
<div class="sgoal"><b>この節で分かること</b>: <code>tr</code> の3つの使い方と、ファイル名を受け取らないこと。</div>
<pre><code>@@
$ tr a-z A-Z < fruits.txt
$ tr -d "a" < fruits.txt
$ tr "," "\t" < scores.csv | cat -A | head -2
@@</code></pre>
<p><code>tr 集合1 集合2</code> は、集合1の文字を集合2の同じ位置の文字に置き換える。<code>-d</code> は削除、<code>-s</code> は同じ文字の連続を1つに縮める（前の節）。ここまで全部 <code>&lt;</code> で渡していることに注意する。</p>
<pre><code>@@
$ tr a-z A-Z fruits.txt; echo "exit=$?"
$ cat fruits.txt | tr a-z A-Z
@@</code></pre>
<p><code>tr</code> は<b>標準入力しか読まない</b>。ファイル名を書くと「余計な引数（extra operand）」として拒否される。<code>cut</code> や <code>sort</code> はファイル名を受け取れるが、<code>tr</code> だけは <code>&lt;</code> かパイプで渡す。試験でも「正しい書き方はどれか」の形で出る。</p>

<h2 id="sort">並べ替える — sort</h2>
<div class="sgoal"><b>この節で分かること</b>: 文字としての並びと数としての並び、欄を指定した並べ替え。</div>
<pre><code>@@
$ sort fruits.txt
$ sort -r fruits.txt
$ sort -f fruits.txt
@@</code></pre>
<p>大文字で始まる <code>Durian</code> が先頭に来た。この檻のロケール（言語と並び順の設定）は <code>C.UTF-8</code> で、文字コードの順（大文字が小文字より前）に並べる。<code>-f</code> は大文字と小文字を区別せずに並べる。</p>
<pre><code>@@
$ echo "B a A b" | tr " " "\n" | sort
$ locale | head -3
@@</code></pre>
<p class="detail">並び順はロケールで変わる。著者の母艦（glibc）で同じ4文字を並べると、<code>en_US.UTF-8</code> では <code>a A b B</code> と大文字と小文字が交互になり、<code>ja_JP.UTF-8</code> と <code>C.UTF-8</code> では <code>A B a b</code> だった。<code>sort</code> の結果が環境によって違うときは、まず <code>locale</code> を疑う。試験の例題は既定の並びを「文字コード順」と書いているが、それは C ロケール（この檻の <code>C.UTF-8</code> も同じ並び。<code>LC_ALL=C</code> でもそうなる）での話である。選択肢に「文字コード順」とあれば、それが想定された答えと読んでよい。</p>
<p>次は数を含む表である。見出し行は <code>tail -n +2</code>（2行目から。第4章）で外してから並べる。</p>
<pre><code>@@
$ tail -n +2 scores.csv | sort -t, -k4
$ tail -n +2 scores.csv | sort -t, -k4 -n
$ tail -n +2 scores.csv | sort -t, -k4 -nr
$ tail -n +2 scores.csv | sort -t, -k3,3 -k4,4nr
@@</code></pre>
<p><code>-t,</code> で区切り文字を <code>,</code> にし、<code>-k4</code> で4番目の欄から比べる。<code>-n</code> が無いと <b>文字として</b>比べるので、<code>100</code> が <code>72</code> より前に、<code>9</code> が最後に来た（1文字目の <code>1</code> &lt; <code>7</code> &lt; <code>8</code> &lt; <code>9</code> で決まる）。<code>-n</code> を付けると数として比べる。<code>-k3,3 -k4,4nr</code> は「3番目の欄だけで並べ、同じなら4番目を数の大きい順で」という意味である。</p>
<div class="scroll"><table>
<tr><th>オプション</th><th>意味</th></tr>
<tr><td><code>-n</code></td><td>数として比べる（無いと文字として比べる）</td></tr>
<tr><td><code>-r</code></td><td>逆順</td></tr>
<tr><td><code>-t 文字</code></td><td>欄の区切り文字（既定は空白の並び）</td></tr>
<tr><td><code>-k 2</code> / <code>-k 2,2</code></td><td>2番目の欄から行末まで / 2番目の欄だけで比べる</td></tr>
<tr><td><code>-u</code></td><td>並べた後、同じ行を1つにする</td></tr>
<tr><td><code>-f</code></td><td>大文字と小文字を区別しない</td></tr>
<tr><td><code>-o ファイル</code></td><td>結果をファイルに書く（入力と同じファイルでもよい。第7章）</td></tr>
</table></div>

<h2 id="uniq">重複を数える — uniq</h2>
<div class="sgoal"><b>この節で分かること</b>: <code>uniq</code> が何と何を比べているか。</div>
<div class="naive"><h4>ふつうこう考える</h4>
<p><code>uniq</code> は重複した行を取り除くコマンドだ。<code>fruits.txt</code> に通せば、<code>apple</code> も <code>banana</code> も1回ずつになるはずだ。</p>
<pre><code>@@
$ uniq fruits.txt
@@</code></pre>
<div class="then"><b>だめな理由</b>: <code>banana</code> も <code>apple</code> も2回ずつ残った。消えたのは、4行目と5行目に<b>続けて</b>並んでいた <code>apple</code> の片方だけである。
<code>uniq</code> は1行読むたびに<b>直前の1行とだけ</b>比べ、同じなら出さない。離れた場所にある同じ行は、別の行として通す。
ファイル全体で重複を消すには、先に <code>sort</code> で同じ行を隣どうしに集める。</div></div>
<pre><code>@@
$ sort fruits.txt | uniq
$ sort fruits.txt | uniq -c
$ sort fruits.txt | uniq -c | sort -rn
$ sort fruits.txt | uniq -d
$ sort fruits.txt | uniq -u
$ sort -u fruits.txt
@@</code></pre>
<p><code>-c</code> は何行まとめたかを左に付け、<code>-d</code> は重複していた行だけ、<code>-u</code> は1回しか出てこなかった行だけを出す。<code>sort | uniq -c | sort -rn</code> は「出現回数の多い順」の定番で、ログの集計で何度も使う。<code>sort -u</code> は <code>sort | uniq</code> と同じ結果になる。</p>
<div class="analogy"><b>たとえ</b>: 列に並んだ人を前から順に数える<b>点呼係</b>に近い。この係は「前の人と同じ名前か」だけを見て、同じなら人数を足す。
名前順に並び替えてもらってから数えれば、全員の人数が正しく出る。
<br>ただし<b>崩れる点</b>: 人の点呼係なら列全体を見渡して「さっきもいたな」と気づけるが、<code>uniq</code> は直前の1行しか覚えていない。
覚えていないので気づきようがない。</div>

<h2 id="join">2つの表をつなぐ — paste と join</h2>
<div class="sgoal"><b>この節で分かること</b>: 行の位置でつなぐ <code>paste</code> と、キーで突き合わせる <code>join</code> の違い。</div>
<pre><code>@@
$ cat names.txt
$ cat mails.txt
$ paste names.txt mails.txt
$ paste -d, names.txt mails.txt
$ paste -s -d, fruits.txt
@@</code></pre>
<p><code>paste</code> は2つのファイルを<b>行の位置で</b>横に並べる（間は TAB、<code>-d</code> で変えられる）。2行目どうしの <code>2 Suzuki</code> と <code>3 takahashi@...</code> は別の人なのに、同じ行に並んだ。<code>paste</code> は中身を見ていない。<code>-s</code> は1つのファイルの行を横1行につなぐ。</p>
<pre><code>@@
$ join names.txt mails.txt
$ join -a1 names.txt mails.txt
$ join -v1 names.txt mails.txt
@@</code></pre>
<p><code>join</code> は先頭の欄（キー）が<b>同じ行どうし</b>を突き合わせる。両方にある 1 と 3 だけが出た。<code>-a1</code> は1つ目のファイルにしか無い行も出し、<code>-v1</code> は1つ目にしか無い行<b>だけ</b>を出す。</p>
<p><code>join</code> には前提がある。両方のファイルがキーで<b>並べ替え済み</b>であることだ。</p>
<pre><code>@@
$ sort -r names.txt > /tmp/names-r.txt; cat /tmp/names-r.txt
$ join /tmp/names-r.txt mails.txt; echo "exit=$?"
@@</code></pre>
<p>逆順に並べたファイルでは、警告を出しながら途中まで突き合わせて、1件しか結べなかった。<code>join</code> も <code>uniq</code> と同じで、ファイル全体を見ずに<b>先頭から順に進む</b>ので、並びが崩れていると相手を見落とす。</p>
<div class="analogy"><b>たとえ</b>: <code>paste</code> は2枚の名簿を<b>上から同じ高さで</b>ホチキス留めすること、<code>join</code> は<b>出席番号で突き合わせて</b>1枚に書き写すことに近い。
<br>ただし<b>崩れる点</b>: 人が突き合わせるなら番号順になっていなくても探せるが、<code>join</code> は両方を上から同時に読み進めるだけなので、
番号順に並んでいない名簿では相手を飛ばしてしまう。</div>
<div class="quiz"><b>確認</b>
<p><code>:</code> 区切りの <code>/etc/passwd</code> から、1番目（ユーザ名）と7番目（ログインシェル）の欄だけを取り出すコマンドはどれか。</p>
<p>A. <code>cut -f1,7 /etc/passwd</code>　B. <code>cut -d: -f1,7 /etc/passwd</code>　C. <code>cut -c1,7 /etc/passwd</code>　D. <code>cut -d: -f1-7 /etc/passwd</code></p>
<details><summary>答え</summary>
<p>B。A は区切り文字が既定の TAB のままなので、<code>:</code> しかない行は丸ごと出る（実測の <code>cut -d, -f2 tabs.txt</code> と同じ）。
C は1文字目と7文字目、D は1〜7番目の全部になる。</p></details></div>
<div class="quiz"><b>確認</b>
<p>ファイル <code>ip.txt</code>（1行に IP アドレスが1つ）で、出現回数の多い IP アドレスから順に、回数付きで表示したい。正しいものはどれか。</p>
<p>A. <code>uniq -c ip.txt | sort -rn</code>　B. <code>sort ip.txt | uniq -c | sort -rn</code>　C. <code>sort -rn ip.txt | uniq -c</code>　D. <code>sort -u ip.txt | uniq -c</code></p>
<details><summary>答え</summary>
<p>B。A は <code>sort</code> を先にしていないので、離れた場所にある同じ IP が別々に数えられる。
D は先に重複を消してしまうので、全部 1 になる。</p></details></div>
<div class="quiz"><b>確認</b>
<p><code>tr a-z A-Z memo.txt</code> がエラーになった。理由と、正しい書き方を答えよ。</p>
<details><summary>答え</summary>
<p><code>tr</code> はファイル名を受け取らず、標準入力だけを読むため（実測は <code>tr: extra operand ‘fruits.txt’</code>）。
<code>tr a-z A-Z &lt; memo.txt</code> または <code>cat memo.txt | tr a-z A-Z</code> と書く。</p></details></div>
<div class="note try"><b>手を動かす</b>:
実践編の<a href="/linuc-text/practice/">演習03</a>は、アクセスログのステータスコードを数えて多い順に並べる課題である。
判定は答えのファイルの中身をログと突き合わせるので、<code>sort</code> を抜くと「同じステータスが何行にも分かれている」と観測される。</div>

<h2 id="wrap">この章で分かったこと</h2>
<div class="goal"><h4>持ち帰ってほしいこと</h4><ul><li><code>uniq</code> は直前の行とだけ比べる。全体の重複を数えるなら <code>sort | uniq -c | sort -rn</code></li><li><code>cut -d 文字 -f 番号</code>。区切りは1文字ごとなので、空白が続くと空の欄ができる（<code>tr -s</code> でまとめる）。既定の区切りは TAB</li><li><code>sort</code> は既定で文字として比べる。数なら <code>-n</code>、逆順は <code>-r</code>、欄は <code>-t</code> と <code>-k</code></li><li><code>tr</code> は標準入力しか読まない。置換・<code>-d</code> 削除・<code>-s</code> 圧縮</li><li><code>paste</code> は行の位置で並べ、<code>join</code> はキーで突き合わせる。<code>join</code> は両方が並べ替え済みであることが前提</li></ul></div>
<div class="verified"><b>検証環境</b>: イメージ ghcr.io/chai0204/lab-linuc:text-1.0.1@sha256:be6456726a12d28311a0d10b518939a3dd43642a49647edc37d12ba374bec63d / Ubuntu 24.04.5 LTS / bash 5.2.21 / coreutils 9.4 / grep 3.11 / sed 4.9 / findutils 4.9.0 / vim 9.1.0016 / nano 7.2 / less 590 / man-db 2.12.0 / apt snapshot 20260929T000000Z / docker 29.8.0・amd64 で検証 / 検証日 2026-10-13</div>
<nav class="pager"><a href="/linuc-text/theory/04-lines">← 4. 1行とは、改行で終わっている範囲のこと</a><a href="/linuc-text/theory/06-sed">次: 6. sed は書き換えた結果を見せるだけ →</a></nav>
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
