<!doctype html>
<html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>2. 「ロックした」は「無効化した」ではない — 確かめて説明する LinuC 主題1.10</title>
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="/shared/style.css"></head>
<body data-draft="1" data-ch="2" data-theme="linuc-security">
<div class="wrap">
<nav class="top"><a href="/">トップ</a> › <a href="/linuc/">LinuC</a> › <a href="/linuc-security/theory/">理論編</a> › 第2章</nav>
<div class="draftbar compact">
<p><b>ドラフト</b>: このテーマは著者が読者として通していません。出力はすべて実機の記録ですが、導線の不備が残っている可能性があります。<a href="/linuc-security/theory/">詳しく</a></p>
</div>
<h1>2. 「ロックした」は「無効化した」ではない</h1>
<p class="lead">退職者のアカウントを止めるとき、まず思いつくのは <code>passwd -l</code>（ロック）である。ところがロックしても、SSH 鍵を登録している相手はそのまま入れてしまう。パスワードをロックしたのに、である。鍵が効くのは、ロックが止めたのが「パスワードという1つの入口」だけだからだ。</p>
<div class="badges"><span>前提: 第1章まで読了</span><span>前提: 練習機が起動している</span><span>所要 16分</span><span class="impact-b">影響度 B</span><span>出題範囲 1.10.1（重要度3）</span><span>最終検証 2026-10-13</span></div>
<div class="goal"><h4>この章のゴール</h4>
<ul><li><code>passwd -S</code> と <code>chage -l</code> が別のものを見ていることを説明できる</li><li>パスワードのロックとアカウントの有効期限の違いを言える</li><li><code>/etc/shadow</code> の主要なフィールド（ロックの <code>!</code>、有効期限の列）を読める</li></ul>
<div class="skip"><b>ここで覚えなくていいこと</b>: PAM モジュール（<code>pam_faillock</code> など）によるログイン失敗ロックや、パスワードの複雑さ要件（<code>pam_pwquality</code>）はレベル1の範囲外である。ここでは <code>passwd</code>・<code>usermod</code>・<code>chage</code> の3つと <code>/etc/shadow</code> だけを扱う。</div></div>

<h2 id="two">passwd はパスワード、chage はアカウント</h2>
<div class="sgoal"><b>この節で分かること</b>: 2つのコマンドが見ている対象の違い。</div>
<p>退職者 <code>olduser</code> がまだ生きている。2つのコマンドで状態を見る。</p>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ sudo passwd -S olduser ⟪k=1⟫
$ sudo chage -l olduser
@@</code></pre>
<p><code>passwd -S</code> の2列目の <code>P</code> が「パスワードが使える（Password）」の意味である（ロックされていれば <code>L</code>、パスワード未設定なら <code>NP</code>）。<code>chage -l</code> は<b>エージング</b>（期限）を並べる。最終変更日（<code>Last password change</code>）は作った日の日付で、パスワードの有効期限・猶予・<b>アカウントの有効期限</b>（<code>Account expires</code>）は <code>never</code>（無期限）になっている。<code>passwd</code> はパスワードという鍵の話、<code>chage</code> はその期限とアカウントの寿命の話で、見ているものが違う。</p>
<div class="analogy"><b>たとえ</b>: <code>passwd</code> は玄関の<b>鍵</b>の話、<code>chage</code> は<b>賃貸契約そのもの</b>の話に近い。鍵を1本交換しても契約は生きているし、契約が切れれば鍵が何本あっても入れない。
<br>ただし<b>崩れる点</b>: 家の鍵は1種類だが、Linux のアカウントにはパスワード・SSH 鍵など複数の入口がある。だから「鍵1本」を止めても塞ぎきれない。</div>

<h2 id="lock">ロックしても、鍵では入れてしまう</h2>
<div class="sgoal"><b>この節で分かること</b>: <code>passwd -l</code> が止めるのはパスワードだけだということ。</div>
<p>この <code>olduser</code> に SSH 公開鍵を登録する（退職前に鍵で入っていた、という設定である）。実際に鍵で入れることを確かめる。</p>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_demo
$ sudo install -d -m 700 -o olduser -g olduser /home/olduser/.ssh
$ sudo install -m 600 -o olduser -g olduser ~/.ssh/id_demo.pub /home/olduser/.ssh/authorized_keys
$ ssh -i ~/.ssh/id_demo -o BatchMode=yes -o StrictHostKeyChecking=accept-new olduser@localhost id
@@</code></pre>
<div class="naive"><h4>ふつうこう考える</h4>
<p>退職者を止めるなら <code>passwd -l</code> でパスワードをロックすればよい。ロックすれば、もうこのアカウントでは入れないはずだ。</p>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ sudo passwd -l olduser
$ sudo passwd -S olduser ⟪k=2⟫
$ sudo grep '^olduser:' /etc/shadow | cut -c1-20
$ ssh -i ~/.ssh/id_demo -o BatchMode=yes olduser@localhost id
@@</code></pre>
<div class="then"><b>だめな理由</b>: <code>passwd -S</code> は <code>L</code>（ロック済み）になり、<code>/etc/shadow</code> のパスワード欄の先頭にも <code>!</code> が付いた。
それでも<b>鍵では入れたまま</b>（<code>uid=1001(olduser)</code> が出ている）。
<code>passwd -l</code> がしたのは、パスワード欄の先頭に <code>!</code> を足して「このハッシュと一致するパスワードは存在しない」状態にしただけである。
公開鍵認証はパスワード欄を見ないので、素通りする。<code>man passwd</code> にも、これはアカウントを無効化しない（鍵などでは入れる）と書いてある。</div></div>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ man 1 passwd | grep -A3 'does not disable'
@@</code></pre>

<h2 id="expire">無効化は、有効期限で行う</h2>
<div class="sgoal"><b>この節で分かること</b>: アカウントそのものを止める方法と、どこで拒否されるか。</div>
<p>全部の入口を塞ぐには、<b>アカウントの有効期限</b>を過去にする。<code>man passwd</code> が勧めているとおり <code>usermod --expiredate 1</code>（<code>-e 1</code>）を使う。期限は <code>/etc/shadow</code> の8列目（1970-01-01 からの日数）に入る。</p>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ sudo usermod -e 1 olduser
$ sudo chage -l olduser | grep 'Account expires'
$ sudo grep '^olduser:' /etc/shadow | cut -d: -f8
$ ssh -i ~/.ssh/id_demo -o BatchMode=yes olduser@localhost id; echo rc=$? ⟪k=1⟫
@@</code></pre>
<p>今度は入れない（<code>Your account has expired</code>、<code>rc=255</code>）。ただし鍵の確認で弾かれたのではない。<code>sshd</code> は PAM を使う設定（<code>UsePAM yes</code>）なので、<b>鍵の認証が通った後で、PAM のアカウント検査（<code>pam_unix</code>）が期限切れを見て拒否する</b>。ログにそう残る。</p>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ sudo journalctl --no-pager -n 30 | grep -o 'pam_unix(sshd:account).*' | tail -1
@@</code></pre>
<p>期限の日付で指定するなら <code>chage -E 2020-01-01 olduser</code> でも同じである。シェルを <code>/usr/sbin/nologin</code> にする止め方もあるので、効く範囲を比べておく。</p>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ sudo usermod -e '' olduser
$ sudo usermod -s /usr/sbin/nologin olduser
$ ssh -i ~/.ssh/id_demo -o BatchMode=yes olduser@localhost id; echo rc=$? ⟪k=2⟫
$ ssh -i ~/.ssh/id_demo -o BatchMode=yes -f -N -L 18080:127.0.0.1:2323 olduser@localhost; sleep 1
$ timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/18080 && head -1 <&3'
$ pkill -f 18080:127.0.0.1:2323
@@</code></pre>
<p>シェルが <code>nologin</code> だと、ログインも <code>ssh host コマンド</code> の実行も止まる（<code>This account is currently not available.</code>）。だがシェルを起動しない <code>ssh -N</code> のポート転送は通ってしまい、練習機の中のサービス（<code>linuc-echo</code>）に届いた。転送は <code>pkill</code> で止めた（残すと第4章の <code>ss</code> に 18080 番が1行増える）。</p>
<p>確かめたら <code>olduser</code> を元の状態に戻し、試しに作った鍵も消す（演習02 はこの元の状態から始まり、第8章でも <code>olduser</code> を使う）。</p>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ sudo usermod -s /bin/bash olduser; sudo passwd -u olduser
$ sudo rm -r /home/olduser/.ssh; rm ~/.ssh/id_demo ~/.ssh/id_demo.pub
@@</code></pre>
<div class="scroll"><table>
<tr><th>操作</th><th>変える場所</th><th>止まるもの</th><th>止まらないもの</th></tr>
<tr><td><code>passwd -l</code></td><td>パスワード欄に <code>!</code> を足す</td><td>パスワードでのログイン</td><td><b>鍵でのログイン</b></td></tr>
<tr><td><code>usermod -e 1</code> / <code>chage -E</code></td><td>有効期限（8列目）を過去に</td><td>PAM を通るログイン全部（鍵も）</td><td>—</td></tr>
<tr><td>シェルを <code>/usr/sbin/nologin</code> に</td><td><code>/etc/passwd</code> のシェル欄</td><td>ログインとコマンド実行</td><td><code>ssh -N</code> のポート転送</td></tr>
</table></div>
<div class="analogy"><b>たとえ</b>: <code>passwd -l</code> は、社員証の<b>暗証番号</b>だけを無効にするのに近い。番号は使えなくなるが、顔認証（鍵）が登録されていれば入れてしまう。<code>usermod -e</code> は<b>社員資格そのもの</b>を失効させるので、どの認証手段でも入れない。
<br>ただし<b>崩れる点</b>: 社員証は1枚だが、Linux の有効期限は日付という1つの数で全入口に効く。番号失効（ロック）と資格失効（期限切れ）を混同すると、止めたつもりで入られる。</div>

<h2 id="shadow">/etc/shadow の列を読む</h2>
<div class="sgoal"><b>この節で分かること</b>: パスワードエージングがどの列に入っているか。</div>
<pre data-where="練習機の中（student@linuc）"><code>@@
$ sudo grep -E '^(root|olduser):' /etc/shadow | cut -c1-30
$ sudo passwd -S root
@@</code></pre>
<p><code>/etc/shadow</code> は <code>:</code> 区切りで9列ある。覚えるべきは次である。</p>
<div class="scroll"><table>
<tr><th>列</th><th>意味</th><th>設定するコマンド</th></tr>
<tr><td>2 パスワード</td><td>ハッシュ（試験では「暗号化されたパスワード」と呼ぶ）。<code>*</code> や <code>!</code> で始まるとパスワードでは入れない</td><td><code>passwd</code></td></tr>
<tr><td>3 最終変更日</td><td>最後にパスワードを変えた日（1970 からの日数）</td><td><code>chage -d</code></td></tr>
<tr><td>4 最短</td><td>変更してから次に変えられるまでの最短日数</td><td><code>chage -m</code></td></tr>
<tr><td>5 最長</td><td>パスワードの有効日数（過ぎると変更を求められる）</td><td><code>chage -M</code></td></tr>
<tr><td>6 警告</td><td>期限の何日前から警告するか</td><td><code>chage -W</code></td></tr>
<tr><td>7 猶予</td><td>パスワードの期限切れ後、まだ変更してログインできる日数。過ぎるとログインできなくなる</td><td><code>chage -I</code></td></tr>
<tr><td>8 <b>アカウント有効期限</b></td><td>この日を過ぎるとアカウントが使えない</td><td><code>chage -E</code> / <code>usermod -e</code></td></tr>
</table></div>
<p><code>root:*</code> の <code>*</code> も「一致するパスワードが無い」印で、<code>passwd -S root</code> は <code>L</code>（ロック）と出る。止まるのは<b>パスワードでの入口</b>だけである。コンソールでのログインもパスワードを打つので入れないが、root に鍵が登録されていれば <code>ssh</code> の設定次第で鍵では入れうる。この練習機の root は鍵も登録されていないので、管理は <code>student</code> の <code>sudo</code> 経由になっている（第5章）。この分け方が<b>シャドウパスワード</b>（第6章）の実際の姿である。</p>
<div class="analogy"><b>たとえ</b>: <code>/etc/shadow</code> の各列は、免許証の裏面にある<b>有効期限・更新日・条件欄</b>に近い。表（<code>/etc/passwd</code>）には名前と番号しか無く、期限などの機微な情報は裏（shadow）に分けてある。
<br>ただし<b>崩れる点</b>: 免許証は1枚だが、Linux は表（<code>/etc/passwd</code>・誰でも読める）と裏（<code>/etc/shadow</code>・一般ユーザは読めない。Ubuntu では <code>640</code>・<code>root:shadow</code>）を別ファイルに分けている。だから裏を読むには権限が要る。</div>

<div class="note try"><b>手を動かす</b>: 実践編の<a href="/linuc-security/">演習02</a>は、この <code>olduser</code> を本当にログインできなくする課題である。判定は「パスワードをロックしただけ」では通らない。有効期限が切れているかを、アカウントデータベースから実際に読んで確かめる。</div>

<div class="quiz"><b>確認</b>
<p>退職した <code>olduser</code> を、SSH 鍵を持っていても<b>ログインできない</b>ようにしたい。確実なのはどれか。</p>
<p>ア <code>passwd -l olduser</code>　イ <code>usermod -e 1 olduser</code>　ウ <code>passwd -d olduser</code></p>
<details><summary>答え</summary>
<p><b>イ</b>。<code>passwd -l</code>（ア）はパスワード欄に <code>!</code> を足すだけで、鍵では入れてしまう。
<code>passwd -d</code>（ウ）はパスワードを<b>空</b>にするのでむしろ危険。
アカウントの有効期限を過去にする <code>usermod -e 1</code>（または <code>chage -E</code>）なら、鍵の認証が通っても PAM のアカウント検査が拒否する。</p></details></div>
<div class="quiz"><b>確認</b>
<p><code>/etc/shadow</code> の各行の<b>8列目</b>は何を表すか。</p>
<details><summary>答え</summary>
<p>アカウントの有効期限（1970-01-01 からの日数）。この日を過ぎるとアカウントが使えなくなる。
<code>chage -E</code> / <code>usermod -e</code> で設定する。パスワードの有効期限（5列目）とは別物。</p></details></div>
<div class="quiz"><b>確認</b>
<p>ユーザのシェルを <code>/usr/sbin/nologin</code> にした。止まらないのはどれか。</p>
<p>ア 対話のログイン　イ <code>ssh host コマンド</code> でのコマンド実行　ウ <code>ssh -N</code> によるポート転送</p>
<details><summary>答え</summary>
<p><b>ウ</b>。<code>nologin</code> はシェルとして起動されたときに拒否するので、ログインもコマンド実行も止まる。
シェルを起動しない <code>ssh -N</code> のポート転送は通る。アカウントそのものを止めるなら有効期限を使う。</p></details></div>

<h2 id="wrap">この章で分かったこと</h2>
<div class="goal"><h4>持ち帰ってほしいこと</h4><ul>
<li><code>passwd -l</code>（ロック）は <code>/etc/shadow</code> のパスワード欄に <code>!</code> を足すだけ。SSH 鍵では入れたまま</li>
<li>アカウントそのものを止めるには有効期限を過去にする（<code>usermod -e 1</code> / <code>chage -E</code>）。鍵の認証が通った後で PAM のアカウント検査が拒否する</li>
<li><code>passwd -S</code> はパスワードの状態（P/L/NP）、<code>chage -l</code> はエージングと有効期限。見ているものが違う</li>
<li><code>/etc/shadow</code> の8列目がアカウント有効期限、7列目がパスワード期限切れ後の猶予。<code>*</code> や <code>!</code> のパスワード欄はパスワードでのログイン不可の印</li>
<li>シェルを <code>nologin</code> にしても <code>ssh -N</code> の転送は止まらない</li>
</ul></div>
<div class="verified"><b>検証環境</b>: イメージ ghcr.io/chai0204/lab-linuc:security-1.0.1@sha256:31b5b127298fad0e2ee33f368852d2be236b65338727d7f34d8e0d1d8485fde0 / 練習機 Ubuntu 24.04.5 LTS・カーネル 6.8.0-142-generic / passwd（shadow）4.13 / OpenSSH 9.6p1 / apt snapshot 20260929T000000Z / 外側 docker 29.8.0・amd64（KVM なしの TCG エミュレーション）/ 練習機の中の操作は対話のログインシェル（端末 80 桁）で記録 / 検証日 2026-10-13</div>
<nav class="pager"><a href="/linuc-security/theory/01-suid">← 1. SUID は、実行する人ではなく持ち主で動く</a><a href="/linuc-security/theory/03-sessions">次: 3. 入っている人と、入れる上限 →</a></nav>
<section id="comments">
<h2>コメント</h2>
<p class="detail">不具合でも感想でも、一言で構いません。GitHub アカウントでそのまま書けます。<br>   <b>本文と違う出力が出た場合</b>は <a href="https://github.com/chai0204/check-then-explain/issues/new/choose">Issue</a> のほうが、添える情報が決まっているので速く直せます。</p>
<div id="giscus"></div>
</section>
<footer><a href="/">トップ</a> · <a href="/linuc/">LinuC 出題範囲マップ</a> · <a href="/linuc-security/theory/">理論編 目次</a> · <a href="/linuc-security/theory/glossary">用語辞書</a></footer>
</div>
<script src="/linuc-security/chapters.js"></script>
<script src="/linuc-security/theory/terms.js"></script>
<script src="/shared/theory.js"></script>
<script src="/shared/comments.js"></script>
</body></html>
