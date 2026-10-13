<!doctype html>
<html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>7. ファイアウォールは、自分を締め出せる — 確かめて説明する LinuC 主題1.10</title>
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="/shared/style.css"></head>
<body data-draft="1" data-ch="7" data-theme="linuc-security">
<div class="wrap">
<nav class="top"><a href="/">トップ</a> › <a href="/linuc-security/">セキュリティ</a> › <a href="/linuc-security/theory/">理論編</a> › 第7章</nav>
<div class="draftbar compact">
<p><b>ドラフト</b>: このテーマは著者が読者として通していません。出力はすべて実機の記録ですが、導線の不備が残っている可能性があります。<a href="/linuc-security/theory/">詳しく</a></p>
</div>
<h1>7. ファイアウォールは、自分を締め出せる</h1>
<p class="lead"><code>iptables -L</code> が空だから無防備だ——とは限らない。この練習機で <code>firewalld</code> を動かすと、<code>iptables -L</code> は空っぽに見えるのに、通信は <code>firewalld</code> のルールで選り分けられている。見る道具を間違えると、守られているのに無防備に見える。そして管理用の <code>ssh</code> を巻き込むと、自分が締め出される。</p>
<div class="badges"><span>前提: 第6章まで読了</span><span>前提: 練習機が起動している</span><span>所要 18分</span><span class="impact-b">影響度 B</span><span>出題範囲 1.10.2（重要度3）</span><span>最終検証 2026-10-13</span></div>
<div class="goal"><h4>この章のゴール</h4>
<ul><li><code>iptables</code> と <code>firewalld</code> の関係と、状態をどこで見るかを説明できる</li><li><code>iptables</code> でポートを落とし、管理用の <code>ssh</code> を巻き込まない書き方ができる</li><li><code>firewall-cmd</code> の実行時の設定と <code>--permanent</code> の違いを言える</li></ul>
<div class="skip"><b>ここで覚えなくていいこと</b>: <code>nftables</code> のネイティブ構文、<code>iptables</code> の <code>nat</code>/<code>mangle</code> テーブル、<code>firewalld</code> のリッチルールや direct interface はレベル1では深追いしない。ここでは「落とす／通す」の基本と、2つの道具の関係だけを扱う。</div></div>

<h2 id="frontends">iptables -L が空でも、守られていることがある</h2>
<div class="sgoal"><b>この節で分かること</b>: 状態を見る道具を間違えると誤読すること。</div>
<p><code>firewalld</code> を起動して、<code>iptables -L</code> でファイアウォールの状態を見てみる。</p>
<div class="naive"><h4>ふつうこう考える</h4>
<p>Linux のファイアウォールといえば <code>iptables</code> だ。<code>iptables -L</code> を見て、ルールが空なら何も守っていない（素通し）ということだ。</p>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ sudo systemctl start firewalld; sleep 2; sudo firewall-cmd --state
$ sudo iptables -L INPUT -n ⟪k=1⟫
$ sudo iptables -S
@@</code></pre>
<div class="then"><b>だめな理由</b>: <code>firewalld</code> は <code>running</code>（動いている）のに、<code>iptables -L INPUT</code> は
<code>policy ACCEPT</code> でルールが1つも無く、<code>iptables -S</code> も3つのチェインの既定方針だけである。
<code>iptables</code> と <code>firewalld</code> は、どちらもカーネルのパケット選別の仕組み（<b>netfilter</b>）にルールを入れる道具で、
この練習機では <code>iptables</code> が nftables 版（<code>iptables-nft</code>）、<code>firewalld</code> も nftables を使う設定になっている。
<code>firewalld</code> は自分専用の表にルールを入れるので、<code>iptables -L</code> の見方には映らない。
だから「<code>iptables -L</code> が空＝無防備」は誤り。<code>firewalld</code> の状態は <code>firewall-cmd</code> で見る。</div></div>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ sudo grep '^FirewallBackend' /etc/firewalld/firewalld.conf
$ sudo iptables --version
@@</code></pre>
<p><code>FirewallBackend=nftables</code> と <code>iptables v1.8.10 (nf_tables)</code> がその組み合わせを示している。<code>iptables-legacy</code> を使う環境や、<code>firewalld</code> を <code>iptables</code> バックエンドで動かす環境では、<code>firewalld</code> のルールが <code>iptables -L</code> にも出る。<b>どの道具が、どの表にルールを入れたか</b>で見え方が変わるので、運用では道具を1つに決め、その道具で状態を見る。</p>
<div class="analogy"><b>たとえ</b>: <code>iptables</code> と <code>firewalld</code> は、同じ<b>配電盤</b>（netfilter）につながる2つの<b>操作卓</b>に近い。<code>firewalld</code> の卓で入れた設定は、<code>iptables</code> の卓の表示灯には出ない（この練習機の組み合わせでは）。
<br>ただし<b>崩れる点</b>: 配電盤は1つなので、両方の卓から同時にいじると、パケットは両方の設定を通ることになり、どちらで落ちたか分からなくなる。だから運用では操作卓を1つに決める。</div>

<h2 id="firewalld">firewalld は、再読み込みで実行時の設定が消える</h2>
<div class="sgoal"><b>この節で分かること</b>: <code>firewall-cmd</code> の実行時の設定と恒久的な設定。</div>
<p><code>firewalld</code> は「ゾーン」ごとに通すサービス／ポートを持つ。既定ゾーンと、その中身を見る。</p>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ sudo firewall-cmd --get-default-zone
$ sudo firewall-cmd --list-all
@@</code></pre>
<p>既定ゾーン <code>public</code> の <code>services</code> に <code>ssh</code> が<b>最初から入っている</b>。だから <code>firewalld</code> を起動しても管理用の <code>ssh</code> は通る（さきほど <code>iptables -L</code> が空でも <code>ssh</code> で入れていたのはこのため）。<code>http</code> を足してみる。</p>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ sudo firewall-cmd --add-service=http
$ sudo firewall-cmd --list-services
$ sudo firewall-cmd --reload
$ sudo firewall-cmd --list-services
@@</code></pre>
<p><code>--add-service</code> だけで足した <code>http</code> は、<code>--reload</code>（設定ファイルからの読み直し）で<b>消えた</b>。<code>--permanent</code> を付けない変更は<b>実行時の設定</b>だけに入り、再読み込みや再起動で失われる。恒久的にするには <code>--permanent</code> を付ける。ただし <code>--permanent</code> は設定ファイルにだけ書くので、<b>いまの動作には読み直すまで反映されない</b>。</p>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ sudo firewall-cmd --permanent --add-service=http
$ sudo firewall-cmd --list-services
$ sudo firewall-cmd --reload
$ sudo firewall-cmd --list-services
@@</code></pre>
<p>外すのは <code>--remove-service</code> で、これも <code>--permanent</code> の有無で同じ違いがある。元に戻して止めておく。</p>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ sudo firewall-cmd --permanent --remove-service=http
$ sudo firewall-cmd --reload
$ sudo firewall-cmd --list-services
$ sudo systemctl stop firewalld
@@</code></pre>
<div class="analogy"><b>たとえ</b>: <code>firewall-cmd</code> の実行時の設定は<b>ホワイトボードの貼り紙</b>、<code>--permanent</code> は<b>規則集の改訂</b>に近い。貼り紙はすぐ効くが、規則集から貼り直す（<code>--reload</code>）と剥がされる。規則集を直しても、貼り直すまで現場は変わらない。
<br>ただし<b>崩れる点</b>: 現場なら両方を同時に直せばよいと気づきやすいが、<code>firewall-cmd</code> はどちらに書いたかを表示しない。<code>--list-services</code> と <code>--permanent --list-services</code> を見比べないと分からない。</div>

<h2 id="drop">iptables で落とし、22 は残す</h2>
<div class="sgoal"><b>この節で分かること</b>: ルールの足し方と、管理 <code>ssh</code> を守る書き方。</div>
<p><code>iptables</code> で直接 <code>2323</code> への接続を落とす。<code>INPUT</code> の既定方針（<code>policy ACCEPT</code>）はそのままに、<code>DROP</code> ルールを1本足す。<b>22 には触れない。</b></p>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ sudo iptables -L INPUT -n ⟪k=2⟫
$ sudo iptables -A INPUT -p tcp --dport 2323 -j DROP
$ sudo iptables -L INPUT -n --line-numbers
@@</code></pre>
<p><code>-A INPUT</code>（末尾に追加）で、<code>tcp</code> の宛先ポート <code>2323</code> を <code>DROP</code>（応答せずに捨てる）にした。効いているか確かめる。接続は応答なしでタイムアウトする（<code>rc=124</code>）。</p>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ timeout 3 bash -c '</dev/tcp/127.0.0.1/2323'; echo rc=$?
@@</code></pre>
<p>そして最も大事な確認——<b>管理用の <code>ssh</code>（22）がまだ生きているか</b>を、外の端末から見る。</p>
<pre data-where="外（lab@host）"><code>@@
$ vm ssh echo ssh_is_alive
@@</code></pre>
<p>通った。<code>2323</code> だけを落とし、<code>22</code> は残せている。もし <code>INPUT</code> の方針を <code>DROP</code> にしたり、<code>22</code> を巻き込むルールを書くと、<b>その瞬間に自分の <code>ssh</code> が切れて締め出される</b>（第6章の戻し方——<code>vm console</code> / <code>lab-guest</code> / <code>vm reset</code>——がここでも効く）。足したルールは消しておく。</p>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ sudo iptables -D INPUT -p tcp --dport 2323 -j DROP
$ sudo iptables -L INPUT -n ⟪k=3⟫
@@</code></pre>
<p>初期状態の違いも押さえる。この練習機の <code>iptables</code> は「既定は通し、落とすものを足す」状態から始まり、<code>firewalld</code> のゾーンは「許可したサービスだけ通す」状態から始まる。だが <code>iptables</code> も、先に <code>22</code> と確立済みの接続を通すルールを入れてから <code>-P INPUT DROP</code> にすれば、許可したものだけを通す形にできる（順番を逆にすると、その瞬間に締め出される）。<b>この <code>iptables</code> のルールは再起動で消える。</b>この練習機は保存と復元の仕組み（<code>iptables-save</code> と <code>netfilter-persistent</code> など）を入れていないので、恒久化には別の手当てが要る。</p>
<div class="analogy"><b>たとえ</b>: <code>iptables</code> のルールは、ホワイトボードに書いた<b>その場の申し送り</b>に近い。いまは効くが、停電（再起動）で消える。残したいなら台帳（<code>iptables-save</code> の出力）に書き写し、始業時に貼り直す仕掛けが要る。
<br>ただし<b>崩れる点</b>: 申し送りは消えても業務は続くが、ファイアウォールが消えると穴が開く。消えることを知らないと、再起動後に無防備になる。</div>

<div class="note try"><b>手を動かす</b>: 実践編の<a href="/linuc-security/practice/">演習05</a>は、<code>iptables</code> で <code>2323</code> を落としつつ <code>22</code> を残す課題である。判定は、<code>2323</code> を落とすルールがあること、<code>22</code> を落とすルールが無いこと、そして<b>外側から <code>ssh linuc</code> が実際に通ること</b>（自分を締め出していないこと）を確かめる。</div>

<div class="quiz"><b>確認</b>
<p>この練習機で <code>firewalld</code> が <code>running</code> なのに、<code>iptables -L INPUT</code> は <code>policy ACCEPT</code> でルールが空だった。このホストは無防備か。</p>
<details><summary>答え</summary>
<p>無防備とは限らない。<code>firewalld</code>（nftables バックエンド）は自分専用の表にルールを入れるので、<code>iptables-nft</code> の <code>iptables -L</code> には映らない。
状態は <code>firewall-cmd --list-all</code> などで見る。どの道具がルールを入れたかに合わせて、見る道具を選ぶ。</p></details></div>
<div class="quiz"><b>確認</b>
<p><code>firewall-cmd --add-service=http</code> を実行したら Web が見えるようになった。翌日サーバを再起動したら見えなくなった。なぜか。どうすればよかったか。</p>
<details><summary>答え</summary>
<p><code>--permanent</code> を付けない変更は実行時の設定だけで、再読み込み（<code>--reload</code>）や再起動で消えるから。
<code>firewall-cmd --permanent --add-service=http</code> で恒久化し、<code>firewall-cmd --reload</code> でいまの動作にも反映する（または両方の形で1回ずつ打つ）。</p></details></div>
<div class="quiz"><b>確認</b>
<p><code>iptables</code> で <code>2323</code> を落としたい。自分はいま <code>ssh</code>（22）で入っている。やってはいけないのはどれか。</p>
<p>ア <code>iptables -A INPUT -p tcp --dport 2323 -j DROP</code>　イ 22 を通すルールより先に <code>iptables -P INPUT DROP</code>（方針を DROP に）　ウ 22 と確立済みの接続を通すルールを入れてから方針を DROP に</p>
<details><summary>答え</summary>
<p><b>イ</b>。22 や確立済みの接続を通す手当てより先に方針を <code>DROP</code> にすると、その瞬間に自分の <code>ssh</code> が切れて締め出される。
<code>2323</code> だけを落とすア、順番を守るウは安全。締め出しても <code>vm console</code> / <code>lab-guest</code> で戻せる。</p></details></div>

<h2 id="wrap">この章で分かったこと</h2>
<div class="goal"><h4>持ち帰ってほしいこと</h4><ul>
<li><code>iptables</code> と <code>firewalld</code> はどちらもカーネルの netfilter にルールを入れる道具。この練習機（iptables-nft と nftables バックエンド）では <code>firewalld</code> のルールは <code>iptables -L</code> に映らない</li>
<li>状態は、ルールを入れた道具で見る（<code>firewalld</code> なら <code>firewall-cmd</code>）。道具は1つに決める</li>
<li><code>firewall-cmd --add-service</code>／<code>--remove-service</code> は実行時だけ。<code>--permanent</code> は設定ファイルだけで、<code>--reload</code> まで反映されない</li>
<li><code>iptables -A INPUT ... -j DROP</code> で落とす。管理用の 22 を巻き込まない（通すルールより先に方針を DROP にしない）</li>
<li><code>iptables</code> のルールは再起動で消える。恒久化には保存と復元の仕掛けが要る</li>
</ul></div>
<div class="verified"><b>検証環境</b>: イメージ ghcr.io/chai0204/lab-linuc:security-1.0.1@sha256:31b5b127298fad0e2ee33f368852d2be236b65338727d7f34d8e0d1d8485fde0 / 練習機 Ubuntu 24.04.5 LTS・カーネル 6.8.0-142-generic / iptables 1.8.10 (nf_tables) / firewalld 2.1.1（FirewallBackend=nftables）/ apt snapshot 20260929T000000Z / 外側 docker 29.8.0・amd64（KVM なしの TCG エミュレーション）/ 練習機の中の操作は対話のログインシェル（端末 80 桁）で記録 / 検証日 2026-10-13</div>
<nav class="pager"><a href="/linuc-security/theory/06-services">← 6. シャドウと、使っていないサービスを止める</a><a href="/linuc-security/theory/08-crypto">次: 8. 鍵は、持ち主で非対称になっている →</a></nav>
<section id="comments">
<h2>コメント</h2>
<p class="detail">不具合でも感想でも、一言で構いません。GitHub アカウントでそのまま書けます。<br>   <b>本文と違う出力が出た場合</b>は <a href="https://github.com/chai0204/check-then-explain/issues/new/choose">Issue</a> のほうが、添える情報が決まっているので速く直せます。</p>
<div id="giscus"></div>
</section>
<footer><a href="/">トップ</a> · <a href="/linuc-security/">セキュリティ</a> · <a href="/linuc-security/theory/">理論編 目次</a> · <a href="/linuc-security/practice/">実践編</a> · <a href="/linuc-security/theory/glossary">用語辞書</a></footer>
</div>
<script src="/linuc-security/chapters.js"></script>
<script src="/linuc-security/theory/terms.js"></script>
<script src="/shared/theory.js"></script>
<script src="/shared/comments.js"></script>
</body></html>
