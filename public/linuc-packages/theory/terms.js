/**
 * 用語辞書のデータ。辞書ページ(/linuc-packages/theory/glossary)と、
 * 本文中の自動リンク(/shared/theory.js)が同じこのデータを使う。
 *   t       : 用語名（本文中でこの文字列を見つけたらリンクにする）
 *   alt     : 別名・表記ゆれ（同じくリンク対象）
 *   id      : 辞書ページ内のアンカー（kebab-case・一意）
 *   hint    : マウスを乗せたとき出る一言（20〜40字）
 *   body    : 辞書ページの説明。たとえ話を必ず1つ入れる
 *   misread : 誤解されやすい点（1文）
 *   ch      : 詳しく扱う章（辞書から本編へ戻るリンク）
 *
 * 多義語は登録しない（パッケージ / インストール など）。
 * コマンド名そのもの（apt・rpm など）は本文で常に code の中に書くので登録しない。
 * LinuC の出題範囲に並ぶ語のうち、「読んで詰まる語」と、この教材の柱になる語（台帳・目録）を入れる。
 * 章の番号は 2026-10-20 の組み直し（第1〜8章 Debian 系・第9〜11章 RPM 系）に合わせてある。
 */
window.TERM_GROUPS = [
  { g: "パッケージ管理の柱 — 台帳と目録", terms: [
    { t:"台帳", alt:["パッケージデータベース"], id:"ledger",
      hint:"何を入れたかの記録。dpkg は /var/lib/dpkg、rpm は /var/lib/rpm に持つ",
      body:"パッケージを入れたときに、パッケージ管理の道具が「このパッケージを、この版で、このファイルとともに入れた」と書き残す記録。Debian 系は <code>/var/lib/dpkg/</code>（<code>status</code> と <code>info/名前.list</code>・<code>info/名前.md5sums</code> などのテキスト）、RPM 系は <code>/var/lib/rpm/</code>（データベース。RHEL 9 は SQLite、RHEL 7・8 は Berkeley DB）にある。<code>dpkg -l</code>・<code>-s</code>・<code>-L</code>・<code>-S</code> や <code>rpm -q</code> の仲間は、ここだけを読む。<b>たとえ</b>: 役所の<b>住民票</b>。暮らしていても転入届が無ければ、台帳の上ではそこにいない。<b>崩れる点</b>: 住民票は本人が窓口で直せるが、パッケージの台帳を書き換えるのは dpkg と rpm だけで、利用者が手で直すものではない。",
      misread:"「ファイルがあれば入っている」と思われがちだが、ファイルを消しても台帳は「入っている」のままで、中身だけを置いても台帳には載らない（第4章で実測）。", ch:4 },

    { t:"目録", alt:["目録の写し"], id:"catalog",
      hint:"リポジトリに何があるかの一覧。apt と yum は手元に写しを取ってきて読む",
      body:"リポジトリにあるパッケージの名前・版・依存関係・置き場所を並べた一覧。Debian 系は <code>dists/区分/main/binary-amd64/Packages</code>、RPM 系は <code>repodata/</code>。apt と yum はこれを手元に写して（<code>/var/lib/apt/lists/</code>・<code>/var/cache/dnf/</code>）、写しのほうを読む。<code>apt show</code> や <code>yum info</code> が入っていないパッケージに答えられるのはこのため。<b>たとえ</b>: 図書館の<b>蔵書目録のコピー</b>。借りられる本は分かるが、コピーした後に入った本は載っていない。<b>崩れる点</b>: 図書館なら行けば最新の目録が見られるが、apt は <code>apt update</code> まで写しを取り直さない（yum は期限が切れていれば自分で取り直す）。",
      misread:"「リポジトリをその場で見に行っている」と思われがちだが、読んでいるのは手元の写しで、apt では取り直すまで古いまま（第6章で実測）。", ch:6 },

    { t:"リポジトリ", alt:["repository"], id:"repository",
      hint:"パッケージの配り場所。中身の置き場と、その目録でできている",
      body:"パッケージを配る場所。中身の置き場（Debian 系の <code>pool/</code> の .deb、RPM 系の .rpm）と目録（<code>dists/</code>・<code>repodata/</code>）でできている。Debian 系は <code>/etc/apt/sources.list</code> と <code>/etc/apt/sources.list.d/</code>、RPM 系は <code>/etc/yum.repos.d/*.repo</code> に「どこにあるか」を書く。<code>https://</code> のサーバでも、<code>file:</code> のディレクトリでもよい（この教材の檻は <code>file:</code>）。<b>たとえ</b>: 在庫の一覧表つきの<b>倉庫</b>。棚と、棚の一覧表がセットになっている。<b>崩れる点</b>: 倉庫は行けば中が見えるが、apt と yum は一覧表しか見ない。棚に品物を置いても、一覧表に載っていなければ「無い」ことになる。",
      misread:"ダウンロードサイトと同じものと思われがちだが、目録の無いただのファイル置き場は、apt や yum からはリポジトリとして使えない。", ch:6 },

    { t:"依存関係", alt:["依存"], id:"dependency",
      hint:"このパッケージを動かすのに、先に入っていなければならない別のパッケージ",
      body:"パッケージが動くために必要な別のパッケージ（と、その版の条件）。.deb は情報の <code>Depends:</code> の欄（<code>dpkg -s</code>・<code>dpkg -I</code>・<code>apt-cache depends</code>）、.rpm は <code>Requires</code>（<code>rpm -qR</code>・<code>yum deplist</code>）に書かれている。apt と yum は目録を読んで、足りないものを一緒に入れる。dpkg と rpm は依存関係を<b>読んで確かめる</b>が、足りないものを取りに行かない。<b>たとえ</b>: 家具の説明書の<b>「別売りの部品 B が必要」</b>の一文。<b>崩れる点</b>: 家具なら部品が無くても箱に戻せるが、dpkg は展開したまま <code>iU</code> で止まり、rpm は1つも入れずに止まる。止まり方が違う。",
      misread:"「dpkg -i や rpm -i も依存を入れる」と思われがちだが、どちらも取りに行かない（第7章・第11章で実測）。", ch:5 },

    { t:"ダイジェスト", alt:["中身の要約"], id:"digest",
      hint:"ファイルの中身から計算した短い値。1バイト違えば別の値になる",
      body:"ファイルの中身から計算する短い値（MD5・SHA256 など）。同じ中身なら同じ値、1バイトでも違えば別の値になる。台帳は入れたときの値を持っていて（<code>/var/lib/dpkg/info/名前.md5sums</code>、rpm の台帳）、<code>dpkg -V</code> と <code>rpm -V</code> はいまのファイルの値と比べる。目録も .deb や .rpm の値を持ち、取ってきたファイルが壊れていないかを確かめる。<b>たとえ</b>: 書類の<b>指紋</b>。指紋が同じなら同じ書類と見なせる。<b>崩れる点</b>: 人の指紋は誰のものかを示すが、ダイジェストは中身が同じかしか示さない。誰が作ったかを確かめるのは署名の役目である。",
      misread:"「ダイジェストが OK なら安全」と思われがちだが、壊れていないことしか分からず、誰が作ったかは分からない（第10章の <code>rpm -K</code>）。", ch:4 },

    { t:"アーキテクチャ", alt:["noarch"], id:"architecture",
      hint:"パッケージがどの種類の CPU 向けか。all と noarch はどれでもよい印",
      body:"パッケージがどの種類の CPU 向けに作られたかの印。Debian 系は <code>amd64</code>（いまの PC の多く）や <code>all</code>（どの CPU でも動く）、RPM 系は <code>x86_64</code>（amd64 と同じ）や <code>noarch</code>（どの CPU でも動く）と書く。ファイル名にも入る（<code>labapp_1.0_all.deb</code>・<code>labhello-1.0-1.noarch.rpm</code>）。シェルのスクリプトだけのパッケージは、どの CPU でも動くので <code>all</code> / <code>noarch</code> になる。<b>たとえ</b>: 電化製品の<b>対応電圧</b>の表示。合わない国では使えないが、「全世界対応」のものもある。<b>崩れる点</b>: 電圧は変換器で合わせられるが、CPU 向けのパッケージは、違う種類の CPU ではそのままでは動かない。",
      misread:"Debian 系と RPM 系で同じ書き方だと思われがちだが、amd64 と x86_64、all と noarch のように呼び名が違う。", ch:3 },
  ]},

  { g: "Debian 系 — apt と dpkg", terms: [
    { t:"ディストリビューション", alt:["スイート","suite"], id:"suite",
      hint:"sources.list の3番目の欄。noble・noble-updates のような区分の名前",
      body:"<code>/etc/apt/sources.list</code> の1行の3番目の欄（deb822 形式では <code>Suites:</code>）。<code>noble</code>（Ubuntu 24.04 が出たときの版）や <code>noble-updates</code>（その後の修正版）のような名前で、リポジトリの <code>dists/名前/</code> に対応する。この教材の練習用リポジトリにも <code>lab</code> と <code>lab-updates</code> がある。<b>たとえ</b>: 雑誌の<b>号</b>。同じ雑誌でも、何号を取り寄せるかで中身が違う。<b>崩れる点</b>: 雑誌の号は出たら変わらないが、<code>noble-updates</code> のような区分は中身が足されていく（この教材の檻は snapshot で日付を止めている）。",
      misread:"Ubuntu や Debian という製品名のことだと思われがちだが、sources.list の欄としては、リポジトリの中の区分（スイート）を指す。", ch:6 },

    { t:"コンポーネント", alt:["component"], id:"component",
      hint:"sources.list の4番目の欄。main・universe のような区分",
      body:"<code>/etc/apt/sources.list</code> の1行の4番目以降の欄（deb822 形式では <code>Components:</code>）。同じディストリビューションの中を、サポートの範囲やライセンスで分けた区分で、Ubuntu なら <code>main</code>・<code>restricted</code>・<code>universe</code>・<code>multiverse</code>。1行に複数並べられる。<b>たとえ</b>: 書店の<b>売り場</b>。同じ号の雑誌でも、どの売り場から取るかを選ぶ。<b>崩れる点</b>: 売り場は見て回れるが、apt は書かれたコンポーネントの目録しか取らない。書いていない売り場の本は、無いのと同じになる。",
      misread:"パッケージの部品のことと思われがちだが、リポジトリの中の区分（<code>dists/ディストリビューション/コンポーネント/</code>）である。", ch:6 },

    { t:"deb822 形式", alt:[".sources ファイル"], id:"deb822",
      hint:"Types: URIs: Suites: のように欄の名前を付けて書くソースの形式",
      body:"apt のソースを <code>Types:</code> <code>URIs:</code> <code>Suites:</code> <code>Components:</code> <code>Signed-By:</code> のように欄の名前を付けて書く形式。<code>/etc/apt/sources.list.d/*.sources</code> に置く。Ubuntu 24.04 では Ubuntu 本体の分が <code>ubuntu.sources</code> に移り、<code>/etc/apt/sources.list</code> にはその案内のコメントが残っている。中身は1行形式と同じ4つの欄である。<b>たとえ</b>: 住所を1行で書くか、<b>郵便番号・都道府県・番地と欄を分けた用紙</b>に書くかの違い。<b>崩れる点</b>: 用紙のほうは1枚に複数のディストリビューション（<code>Suites:</code>）を書けるので、1行形式に直すと行が増える。",
      misread:"「sources.list が無くなった」と思われがちだが、1行形式も <code>/etc/apt/sources.list</code> や <code>*.list</code> でそのまま使える（試験が問うのは1行形式）。", ch:6 },

    { t:"Contents", alt:["Contents 目録"], id:"contents",
      hint:"どのファイルがどのパッケージに入っているかの目録。apt-file が読む",
      body:"「どのファイルがどのパッケージに入っているか」を並べた目録。Packages（名前・説明・依存関係）とは別のファイルで、<code>apt-file search</code> / <code>apt-file list</code> がこれを読む。だから入っていないパッケージの中のファイルも探せる。<code>apt update</code>（<code>apt-file update</code> も中で同じことをする）で取ってくる。Ubuntu の Contents は大きく、3つの区分で約 195MB ある（この教材の檻では Ubuntu の分を取らない設定にしてある）。<b>たとえ</b>: 本の<b>巻末索引</b>。目次（Packages）では分からない語の場所を引ける。<b>崩れる点</b>: 巻末索引は本に付いてくるが、Contents は別に取りに行く目録で、取っていなければ引けない。",
      misread:"<code>apt update</code> でいつも取れると思われがちだが、apt-file を入れていないと取りに行かない（apt-file の設定が取り先を足している）。", ch:6 },

    { t:"conffile", alt:["設定ファイル（conffile）"], id:"conffile",
      hint:"利用者が書き換える前提の設定ファイル。remove しても残る",
      body:"パッケージの中で「利用者が書き換える設定ファイル」として印を付けたファイル（.deb の <code>DEBIAN/conffiles</code>、<code>dpkg -s</code> の <code>Conffiles:</code> 欄）。<code>apt remove</code> / <code>dpkg -r</code> では消えずに残り、台帳に <code>rc</code> と書かれる。消すには <code>purge</code> / <code>-P</code>。入れ直しても、書き換えたものは元に戻さない。<b>たとえ</b>: 賃貸で<b>自分で替えたカーテン</b>。家具を運び出しても、カーテンは外すと言わない限り残る。<b>崩れる点</b>: 実際の退去は元に戻して返すのが決まりだが、dpkg は残すのが既定である。",
      misread:"/etc の下のファイルは全部 conffile と思われがちだが、パッケージを作るときに印を付けたものだけが特別に扱われる。", ch:5 },

    { t:"自動で入った印", alt:["auto の印"], id:"auto-mark",
      hint:"依存関係のために apt が入れたものに付く印。autoremove が使う",
      body:"apt が「利用者が名指ししたのではなく、依存関係のために自分が入れた」ものに付ける印。dpkg の台帳ではなく apt 自身の記録（<code>/var/lib/apt/extended_states</code>）にあり、<code>apt-mark showauto</code> / <code>showmanual</code> や、<code>apt list --installed</code> の <code>automatic</code> で見られる。印があって、もう誰にも必要とされていないものを <code>apt autoremove</code> が消す。RPM 系の yum も同じ記録を持ち、<code>yum remove</code> が要らなくなった依存関係を一緒に消す（<code>clean_requirements_on_remove=True</code>）。<b>たとえ</b>: 引っ越しのとき<b>一緒に借りたトランクルーム</b>の契約。本体の荷物が無くなったら返してよい。<b>崩れる点</b>: 人なら「まだ使うかも」と迷うが、apt は依存されているかどうかだけで決める。",
      misread:"dpkg も覚えていると思われがちだが、印は apt（と yum）の記録にしか無いので、dpkg には autoremove にあたるものが無い。", ch:5 },

    { t:"展開済み・設定前", alt:["iU"], id:"unpacked",
      hint:"dpkg -l の iU。ファイルは置いたが、設定まで済んでいない状態",
      body:"<code>dpkg -l</code> の行頭が <code>iU</code>（入れたい／展開済み）の状態。<code>dpkg -i</code> が依存関係の足りないパッケージを入れると、中身を置いたところで止まり、この状態で台帳に残る。ファイルはあるのでコマンドは動きかけて失敗する。依存関係が満たされないまま残っていると、apt はほかの操作も断り、<code>apt --fix-broken install</code> を求める。<code>dpkg --unpack</code> で展開だけしたときも、この状態になる（<code>dpkg --configure</code> で設定を済ませる）。<b>たとえ</b>: 組み立て家具の<b>部品を床に並べたまま</b>の状態。<b>崩れる点</b>: 家具なら並べたまま放っておいても困るのはその家具だけだが、依存関係の足りない iU は apt のほかの操作まで止める。",
      misread:"エラーで止まったので何も入っていないと思われがちだが、中身は展開済みで台帳にも載っている（第7章で実測）。", ch:7 },

    { t:"debconf", alt:[], id:"debconf",
      hint:"パッケージを入れるときの質問と、その答えを覚えておくしくみ",
      body:"Debian 系のパッケージが、設定するときに利用者へ質問を出し（タイムゾーンなど）、答えを記録しておくしくみ。答えは <code>debconf-show パッケージ名</code> で見られる（行頭の <code>*</code> は、その質問がもう出されたという印）。<code>dpkg-reconfigure</code> は質問をもう一度出し、その答えでパッケージの設定の手順を走らせ直す。画面の出し方は選べ、ふつうは矢印キーで選ぶ画面、<code>-f teletype</code> なら文字だけの質問になる。<b>たとえ</b>: 家電の<b>初期設定ウィザード</b>と、その回答の控え。<b>崩れる点</b>: 家電は回答を本体に書き込むだけだが、dpkg-reconfigure は設定の手順を丸ごとやり直し、設定ファイルを書き直すことがある。",
      misread:"設定ファイルそのものと思われがちだが、質問の答えを覚えておく場所で、設定ファイルはその答えから作られる。", ch:7 },
  ]},

  { g: "RPM 系 — yum と rpm", terms: [
    { t:"dnf", alt:["DNF"], id:"dnf",
      hint:"RHEL 8 以降の yum の中身。yum は dnf へのリンクになっている",
      body:"RHEL 8 以降（AlmaLinux・Rocky Linux も同じ）で yum の代わりに動いているパッケージ管理の道具。<code>/usr/bin/yum</code> は <code>dnf-3</code> へのシンボリックリンクで、<code>/etc/yum.conf</code> も <code>/etc/dnf/dnf.conf</code> へのリンクになっている。サブコマンドの名前（<code>install</code> <code>remove</code> <code>list</code> <code>info</code> <code>provides</code>）は yum と同じ。<code>yumdownloader</code> と <code>repoquery</code> も dnf の働きを呼ぶ道具へのリンクで、目録の写しは <code>/var/cache/dnf/</code> に置く。<b>たとえ</b>: <b>屋号を変えずに店主が代わった店</b>。看板も注文の仕方も前のまま。<b>崩れる点</b>: 細かい既定の動きは入れ替わっており、古い資料のとおりにならないことがある（<code>yum remove</code> が依存関係も消す、など）。",
      misread:"yum とは別に覚えるコマンドだと思われがちだが、試験の yum の問題はコマンドの形のまま dnf で試せる。ただし既定の動き（remove が依存関係を消すか）は RHEL 7 と違うところがある。", ch:10 },

    { t:"repo id", alt:["リポジトリ ID"], id:"repo-id",
      hint:".repo ファイルの [ ] の中の名前。yum list の @ の後ろに出る",
      body:"<code>/etc/yum.repos.d/*.repo</code> の <code>[lab]</code> のように、<code>[ ]</code> の中に書くリポジトリの名前。<code>yum repolist</code> の左の欄に出て、<code>yum list installed</code> の右端に <code>@lab</code> の形で「どこから入ったか」として出る。rpm で直接入れたものは <code>@System</code> になる。ファイル名とは関係なく、1つの .repo ファイルにいくつでも書ける。<b>たとえ</b>: 取引先の<b>社名コード</b>。伝票には社名ではなくコードで書く。<b>崩れる点</b>: 社名コードは取引先が決めるが、repo id は自分で付ける。同じリポジトリでも、書いた人によって名前が違うことがある。",
      misread:"ファイル名が repo id になると思われがちだが、ファイル名は自由で、名前は [ ] の中で決まる。", ch:10 },

    { t:"目録の期限", alt:["metadata_expire"], id:"metadata-expire",
      hint:"yum が目録を取り直すまでの時間。過ぎると次のコマンドで取り直す",
      body:"yum（dnf）が手元の目録の写しをいつまで使うかの期限で、<code>.repo</code> や <code>/etc/yum.conf</code> の <code>metadata_expire=</code>（秒）で決める。期限が切れていると、次にコマンドを打った時点で自分で取り直す。目録の写しをまだ持っていないリポジトリ（足したばかりのもの）も、その場で取りに行く。<code>-1</code> は期限なし。この教材の檻は、中身の変わらないリポジトリを相手にしているので <code>-1</code> にしてある。<b>たとえ</b>: <b>賞味期限</b>の付いたカタログ。期限が切れていたら、使う前に新しいものを取ってくる。<b>崩れる点</b>: 期限の内側でリポジトリの中身が変わっても気づかない。そのときは <code>yum makecache</code> で取り直させる。",
      misread:"apt と同じく更新のコマンドを打つまで古いままと思われがちだが、yum は期限と写しの有無を見て自分で取り直す（第10章で実測）。", ch:10 },

    { t:"保存庫", alt:[], id:"vault",
      hint:"AlmaLinux の古い版のリポジトリを凍結して置いておく場所（vault）",
      body:"AlmaLinux が、次の版が出て更新の止まった版（9.7 など）のリポジトリを、そのままの形で残している場所（<code>vault.almalinux.org</code>）。中身が変わらないので、この教材の RPM 系の檻はここに向けて、読者ごと・日ごとに出力が変わらないようにしている。実機の AlmaLinux はふつう、最新の配り先を使う。<b>たとえ</b>: 雑誌の<b>バックナンバーの書庫</b>。もう新しい記事は足されない。<b>崩れる点</b>: 書庫の雑誌は読むだけだが、保存庫のパッケージは今でも入れられる。ただし安全のための修正も、もう足されない。",
      misread:"最新のリポジトリと同じだと思われがちだが、更新が止まった版なので、実機の運用で向けたままにしてはいけない。", ch:10 },
  ]},

  { g: "署名と鍵", terms: [
    { t:"署名", alt:["signature"], id:"signature",
      hint:"作った人の鍵で付ける印。公開鍵で確かめると、作った人と無改ざんが分かる",
      body:"パッケージや目録を作った人が、自分だけが持つ鍵（秘密鍵）で付ける印。受け取った側は、対になる公開鍵で確かめると「その人が作ったもので、あとから書き換えられていない」ことが分かる。<code>rpm -K</code>（<code>--checksig</code>）で確かめると、署名が無ければ <code>digests OK</code>、鍵が無ければ <code>digests SIGNATURES NOT OK</code>（<code>-Kv</code> で <code>NOKEY</code>）、確かめられれば <code>digests signatures OK</code>、書き換えられていれば <code>DIGESTS SIGNATURES NOT OK</code> と出る。署名の語（<code>signatures</code>）が小文字で OK のときだけ確かめられている。yum は <code>gpgcheck=1</code> で、確かめられないものをリポジトリから入れない。<b>たとえ</b>: 書類の<b>印鑑</b>と、役所の<b>印影の登録簿</b>。<b>崩れる点</b>: 役所は印鑑の無い書類を受け付けないが、<code>rpm -K</code> は「署名が無い」を失敗として扱わない。断るのは yum の規則である。",
      misread:"<code>rpm -K</code> で OK なら署名を確かめたと思われがちだが、署名の無いパッケージも <code>digests OK</code> と出る（第10章で実測）。", ch:10 },

    { t:"公開鍵", alt:["GPG 鍵","GPG公開鍵"], id:"public-key",
      hint:"署名を確かめるための鍵。rpm は gpg-pubkey として台帳に入れる",
      body:"署名を確かめるための鍵（配ってよい鍵）。RPM 系では <code>rpm --import 鍵のファイル</code> で取り込み、台帳に <code>gpg-pubkey-鍵のID-…</code> という名前の（ファイルを持たない）パッケージとして記録される。一覧は <code>rpm -q gpg-pubkey</code>。yum は <code>.repo</code> の <code>gpgkey=</code> に書いた鍵を、入れる前に取り込んでよいか尋ねる。Debian 系では <code>Signed-By:</code>（<code>[signed-by=…]</code>）で、どの鍵で目録を確かめるかを指定する。<b>たとえ</b>: 登録した<b>印影</b>。登録してあれば、届いた書類の印鑑を照らし合わせられる。<b>崩れる点</b>: 印影の登録は本人確認のうえで行うが、<code>rpm --import</code> は渡された鍵をそのまま信じる。鍵そのものの出どころは、取り込む前に自分で確かめる。",
      misread:"鍵を取り込めばパッケージが安全になると思われがちだが、変わるのは「確かめられるようになる」ことだけで、その鍵の持ち主を信じてよいかは別の判断である。", ch:10 },
  ]},
];
