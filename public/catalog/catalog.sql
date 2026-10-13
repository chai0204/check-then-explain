-- 記事の台帳の写し。tools/catalog.mjs が catalog/schema.sql と catalog/articles.sql（正本）と、実物から数えた章・演習から作る。手で編集しない。
-- トップの「SQL で引く」が、ブラウザの中の SQLite（sql.js）に読み込んで、SELECT と .schema だけを受け付ける。

-- 記事の台帳の形。行は catalog/articles.sql に置く。
-- 正本はこの2つの SQL の文。node tools/catalog.mjs が SQLite（Node 組み込みの node:sqlite・メモリ上）に読み込み、
-- トップの記事一覧と各記事のホームを焼き出す。更新するのは管理者だけで、読者に配るのは焼き出した静的なページだけ
-- （検索と絞り込みはブラウザの中で動く。読み取り専用なので、ネットにデータベースを置く必要が無い）。
-- 完了推定時間は表に持たない。章の「所要 N分」と演習の est_min を生成のたびに数える（手で持つとずれる）。

CREATE TABLE article (
  slug        TEXT PRIMARY KEY,                       -- URL の名前（/slug/ が記事ホーム）
  title       TEXT NOT NULL,                          -- 記事名
  status      TEXT NOT NULL CHECK (status IN ('確認済み', 'ドラフト', '修正中')),
                                                      -- 確認済み = 著者が読者として通した / ドラフト = まだ通していない / 修正中 = 直している途中
  cert        TEXT,                                   -- 関連資格（無ければ NULL）
  cert_exam   TEXT,                                   -- 試験の区分（例: '101'。NULL 可）
  cert_order  TEXT,                                   -- 資格の中の並び（例: '1.02'）。前後の記事のリンクに使う
  difficulty  TEXT NOT NULL CHECK (difficulty IN ('入門', '初級', '中級', '上級')),
  method      TEXT NOT NULL CHECK (method IN ('読むだけ', '演習あり（コンテナ）', '演習あり（仮想マシン）')),
  created     TEXT NOT NULL CHECK (created GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
                                                      -- 公開日 = 初めてサイトに出した日。トップの既定の並び（確認済みを先に、次にこの新しい順）の鍵
  updated     TEXT NOT NULL CHECK (updated GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND updated >= created),
                                                      -- 最終更新日 = 中身（本文・演習）を直した日
  summary     TEXT NOT NULL,                          -- 概要（2〜3文）
  audience    TEXT NOT NULL,                          -- 想定読者
  outcomes    TEXT NOT NULL,                          -- 得られるもの（1行に1つ）
  CHECK ((cert IS NULL) = (cert_order IS NULL))
);

CREATE TABLE article_domain (                         -- 関連領域（1記事に複数）
  slug    TEXT NOT NULL REFERENCES article(slug),
  domain  TEXT NOT NULL CHECK (domain IN ('サーバー', 'ネットワーク', 'セキュリティ', 'DB', 'ウェブ', 'OSS', '仮想化')),
  PRIMARY KEY (slug, domain)
);

CREATE TABLE article_related (                        -- 関連記事（資格の前後は cert_order から自動で出すので、ここには入れない）
  slug     TEXT NOT NULL REFERENCES article(slug),
  related  TEXT NOT NULL REFERENCES article(slug),
  PRIMARY KEY (slug, related),
  CHECK (slug <> related)
);

CREATE TABLE cert (                                   -- 資格の地図（出題範囲との対応表）があれば、その URL
  name     TEXT PRIMARY KEY,
  map_url  TEXT
);

CREATE TABLE chapter (                                -- 章（実物の chapters.js と各章の「所要 N分」から）
  slug     TEXT NOT NULL REFERENCES article(slug),
  n        INTEGER NOT NULL,                          -- 章の番号
  title    TEXT NOT NULL,
  url      TEXT NOT NULL,
  minutes  INTEGER NOT NULL,                          -- 所要時間（分）
  PRIMARY KEY (slug, n)
);
CREATE TABLE exercise (                               -- 演習（檻の verify/NN.meta から）
  slug     TEXT NOT NULL REFERENCES article(slug),
  cage     TEXT NOT NULL,                             -- 檻（1つの記事に檻が2つあるものは deb / rpm など）
  n        TEXT NOT NULL,                             -- 演習の番号（01 など）
  title    TEXT NOT NULL,
  minutes  INTEGER NOT NULL,                          -- 目安の時間（分）
  PRIMARY KEY (slug, cage, n)
);

-- 記事の台帳（行）。形は catalog/schema.sql。書き換えたら node tools/catalog.mjs で、トップと記事ホームと道しるべを作り直す。
-- 公開日（created）は初めてサイトに出した日。最終更新日（updated）は中身（本文・演習）を直した日で、道しるべだけの変更では動かさない。

INSERT INTO cert (name, map_url) VALUES ('LinuC レベル1', '/linuc/');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-boot', 'Linux の起動・仮想化・プロセス', 'ドラフト', 'LinuC レベル1', '101', '1.01', '初級', '演習あり（仮想マシン）', '2026-10-13', '2026-10-13',
  'LinuC レベル1 101 試験の主題1.01（インストールと仮想マシン・コンテナ、ブートと systemd、プロセス、デスクトップ）を、コンテナの中で動く仮想マシン（練習機）で確かめる10章。電源を入れ、GRUB でカーネルに引数を渡し、プロセスにシグナルを送るまでを自分の手で打つ。停止の頼みもシグナルもログインも相手に送る合図で、どう振る舞うかは受け取った側が決める。',
  'LinuC レベル1（101）の受験者で、出題範囲を読んで「そういうことができるんだな」で止まっている人。端末でコマンドを打てて、docker を動かせることが前提。',
  'virsh shutdown と destroy の違いを、受け取る相手の違いとして説明できる
コンテナと仮想マシンの違いを、同じコマンドを両方で打った出力で示せる
GRUB でカーネル引数を足し、その1回だけシングルユーザモードで起動できる
ssh の切断で処理が消える理由を SIGHUP で説明し、nohup や tmux で残せる');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-boot', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-files', 'ファイルとパーミッション', 'ドラフト', 'LinuC レベル1', '101', '1.02', '初級', '演習あり（コンテナ）', '2026-10-13', '2026-10-13',
  'LinuC レベル1 101 試験の主題1.02（所有者とパーミッション、ファイル管理、リンク、ファイルの検索）を、コンテナの中で実際に打って確かめる8章。他人の立場は alice・bob・carol として借りる。ファイルの名前はディレクトリに書かれた1行にすぎず、権限・所有者・時刻・中身は inode の側にある。chmod・find・tar・ln を、この1つの構造で説明する。',
  'LinuC レベル1（101）の受験者で、chmod 4755 や find -mtime +7 が、覚えたそばから抜けていく人。端末でコマンドを打てて、docker を動かせることが前提。',
  '「消せるかどうか」を、ファイルではなくディレクトリの権限から判断できる
umask の値から、新しいファイルとディレクトリの権限をビットで求められる
SUID・SGID・スティッキービットが、ファイルとディレクトリで何を変えるかを言える
ls -li と ls -F の表示から、ハードリンクとシンボリックリンクを見分けられる');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-files', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-text', 'コマンドラインとテキスト処理', 'ドラフト', 'LinuC レベル1', '101', '1.03', '初級', '演習あり（コンテナ）', '2026-10-13', '2026-10-13',
  'LinuC レベル1 101 試験の主題1.03（コマンドライン、フィルタ、リダイレクトとパイプ、正規表現、vi）を、コンテナの中で実際に打って確かめる10章。出題範囲が名指しする19個のフィルタは、すべて本文で打つ。コマンドが受け取るのはシェルが組み立て終えた後の文字列だけで、引用符・変数・ワイルドカード・リダイレクト・パイプは、コマンドが動く前にシェルが片づけている。',
  'LinuC レベル1（101）の受験者で、2>&1 の位置や uniq の前の sort を、覚えた順番ではなく理由で答えたい人。端末でコマンドを打てて、docker を動かせることが前提。',
  '引用符3種類で、$ と空白と * の扱いがどう変わるかを言える
2>&1 を書く位置で結果が変わる理由を、左から順に配線する規則で説明できる
uniq が隣どうししか比べないことを踏まえ、sort と組み合わせて集計できる
vi のモードを行き来して編集し、:w! :q! :e! ZZ の違いを言える');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-text', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-packages', 'パッケージ管理（apt と yum）', 'ドラフト', 'LinuC レベル1', '101', '1.04', '初級', '演習あり（コンテナ）', '2026-10-13', '2026-10-13',
  'LinuC レベル1 101 試験の主題1.04（apt・dpkg・yum・rpm）を、Debian 系（Ubuntu 24.04）と RPM 系（AlmaLinux 9.7）の2つの檻で打って確かめる7章。入れる・消す・調べる・照らし合わせる・署名を確かめる、を全部やる。パッケージのコマンドはどれも、手元の台帳（dpkg・rpm）かリポジトリの目録（apt・yum）という帳簿を読んでいるだけだ。',
  'LinuC レベル1（101）の受験者で、dpkg -S と apt-file search のような似たコマンドの違いで迷う人。端末でコマンドを打てて、docker を動かせることが前提。',
  'dpkg・rpm・apt・yum のコマンドを、台帳と目録のどちらを読むかで分けられる
remove・purge・autoremove の違いを、台帳の状態（ii / rc）で言える
dpkg -i が依存関係で止まったときの台帳の状態と、続きのやり方を言える
rpm -K の出力を読み、署名が確かめられたかを判断できる');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-packages', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-disks', 'ハードウェアとディスク', 'ドラフト', 'LinuC レベル1', '101', '1.05', '初級', '演習あり（仮想マシン）', '2026-10-13', '2026-10-13',
  'LinuC レベル1 101 試験の主題1.05（ハードウェア、パーティション、ファイルシステム）を、コンテナの中で動く仮想マシン（練習機）で確かめる8章。ディスクを分割し、フォーマットし、マウントし、ドライバを外し、USB メモリを抜き差しする。ディスクは装置・パーティション表・LVM・ファイルシステム・マウントの層が重なってできていて、各層は自分の印だけを読む。',
  'LinuC レベル1（101）の受験者で、fdisk も mount も本物のディスクで試したことが無い人。端末でコマンドを打てて、docker を動かせることが前提。',
  'USB メモリを挿したとき、カーネル・udev・modprobe が何をするかを順に言える
消してしまったパーティションを、表の行を書き戻して取り戻せる
論理ボリュームを広げるとき、ファイルシステムの側に要る操作を言える
/etc/fstab の6列を書き、装置名ではなく UUID やラベルで指せる');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-disks', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-shell', 'シェルとスクリプト', 'ドラフト', 'LinuC レベル1', '102', '1.06', '初級', '演習あり（コンテナ）', '2026-10-13', '2026-10-13',
  'LinuC レベル1 102 試験の主題1.06（シェル環境のカスタマイズ、シェルスクリプト）を、コンテナの中で実際に打って確かめる8章。1.06.2 は、レベル1の全39副題で最も重い副題だ。新しく起動したシェルやスクリプトは親の環境変数のコピーを受け取って始まり、終わるときに親へ返せるのは 0〜255 の終了ステータス1つだけである。',
  'LinuC レベル1（102）の受験者で、$@ と $* の違いや起動ファイルの読まれ方を、表で覚えきれない人。端末でコマンドを打てて、docker を動かせることが前提。',
  '起動ファイル7つが、シェルのどの起動のしかたで読まれるかを言える
source と bash でファイルを読む違いを、どのシェルが読むかで説明できる
"$@" と "$*" の違いと、引数を渡し直すときに "$@" を使う理由を言える
パイプの右側の while read で数えた値が残らない理由を説明できる');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-shell', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-network', 'ネットワークの基礎', 'ドラフト', 'LinuC レベル1', '102', '1.07', '初級', '演習あり（仮想マシン）', '2026-10-13', '2026-10-13',
  'LinuC レベル1 102 試験の主題1.07（プロトコルの基礎、ネットワーク構成、問題解決、クライアント側の DNS 設定）を、仮想マシンの中に作った「社内 LAN」で確かめる9章。壊れて渡される経路と名前解決を、原因を突き止めて直す。ネットワークの見え方は道具が読んだ表で決まり、ifconfig と ip、dig と ping は同じものを別々の表から読んでいる。',
  'LinuC レベル1（102）の受験者で、ip と ifconfig、dig と ping のどれで何が分かるかで止まっている人。端末でコマンドを打てて、docker を動かせることが前提。',
  'アドレスとマスクから、ネットワークアドレス・ブロードキャスト・使える台数を出せる
ping の From と ICMP のエラーから、どこで止まったかを特定できる
ss の待ち受けの表から、どのアドレスの何番で誰が待っているかを読める
getent ahosts で、/etc/hosts と DNS のどちらが答えたかを特定できる');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-network', 'ネットワーク');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-network', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-admin', 'アカウント・ジョブ・ロケール', 'ドラフト', 'LinuC レベル1', '102', '1.08', '初級', '演習あり（仮想マシン）', '2026-10-13', '2026-10-13',
  'LinuC レベル1 102 試験の主題1.08（アカウント管理、ジョブスケジューリング、ローカライゼーションと国際化）を、コンテナの中で動く仮想マシン（練習機）で確かめる9章。ユーザを作って止め、cron と at に本物の時刻でジョブを走らせ、ロケールを生成する。管理コマンドが書き換えるのは台帳の1行だけで、それが効くかは、読む側がいつ・どの列を読むかで決まる。',
  'LinuC レベル1（102）の受験者で、useradd や crontab のオプションを、読んでも覚えられない人。端末でコマンドを打てて、docker を動かせることが前提。',
  'usermod -G と -aG の違いを、結果の台帳で説明できる
ロック・期限切れ・シェルの拒否が、ログインのどの段で効くかを説明できる
ユーザの crontab と /etc/crontab の書式の違いを、動いた結果で説明できる
文字化けが「バイトの破損」ではなく「読み方の誤り」であることを示せる');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-admin', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-services', '時刻・ログ・メール', 'ドラフト', 'LinuC レベル1', '102', '1.09', '初級', '演習あり（コンテナ）', '2026-10-12', '2026-10-13',
  'LinuC レベル1 102 試験の主題1.09（システム時刻の管理、システムのログ、MTA の基本）を、systemd が動くコンテナの中で打って確かめる7章。timedatectl も journalctl も systemctl も動く。送り手は中身とラベルだけを渡し、宛先を決めているのは受け手側にある設定ファイルだ。',
  'LinuC レベル1（102）の受験者で、出題範囲を読んで「そういうことができるんだな」で止まっている人。端末でコマンドを打てて、docker を動かせることが前提。',
  'chrony に基準を設定して同期させ、chronyc で状態を読み分けられる
同じ1行が複数のログファイルに入る理由を、設定の構造から説明できる
logrotate が設定を拒否する2つの条件を、出力から特定できる
メールの配送の経路を、/etc/aliases・~/.forward とログから追える');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-services', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-security', 'セキュリティ', 'ドラフト', 'LinuC レベル1', '102', '1.10', '初級', '演習あり（仮想マシン）', '2026-10-13', '2026-10-13',
  'LinuC レベル1 102 試験の主題1.10（セキュリティ管理、ホストの設定、暗号化、クラウド）を、コンテナの中で動く仮想マシン（練習機）で確かめる9章（クラウドは理論のみ）。自分を締め出す操作も、外から戻せる構えで扱う。「止めたつもり」はたいてい止まっておらず、制限は正しい対象に、信用できる持ち主の設定で書けたときだけ効く。',
  'LinuC レベル1（102）の受験者で、出題範囲を読んで「そういうことができるんだな」で止まっている人。端末でコマンドを打てて、docker を動かせることが前提。',
  'find -perm 4000 と -4000 の違いを説明し、SUID の棚卸しができる
パスワードのロックとアカウントの有効期限の違いを言える
特定のユーザに特定のコマンドだけを許す sudo のルールを書ける
管理用の ssh を巻き込まずに、iptables でポートを塞げる');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-security', 'セキュリティ');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-security', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-oss', 'オープンソースの文化', 'ドラフト', 'LinuC レベル1', '102', '1.11', '入門', '読むだけ', '2026-10-13', '2026-10-13',
  'LinuC レベル1 102 試験の主題1.11（オープンソースの概念とライセンス、コミュニティとエコシステム）を、どの Ubuntu にも入っているライセンスの実物を読んで確かめる4章。演習は無い。オープンソースは権利を手放したソフトではなく、持ち主が条件を書いて出した許可で、その条件と連絡先はソフトと一緒に配られている。',
  'LinuC レベル1（102）の受験者で、出題範囲を読んで「GPL というライセンスがあるんだな」で止まっている人。端末で読むだけのコマンドを打てれば足りる。',
  'オープンソースに持ち主がいることを、手元の copyright ファイルで示せる
GPL の義務が配るときに生まれることを、条文の convey の定義から説明できる
主なライセンスを、コピーレフト型・準コピーレフト型・非コピーレフト型に分けられる
不具合の報告先を、ソフトの中の情報から層ごとに読み取れる');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-oss', 'OSS');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'sqlite', 'SQLite', '確認済み', NULL, NULL, NULL, '中級', '演習あり（コンテナ）', '2026-10-08', '2026-10-08',
  'サーバのいないデータベースが、どこまで普通のファイルなのかを手で確かめる5章。ヘッダのバイト列とプロセス一覧から始め、型、トランザクションの速さ、同時書き込みのロック、ディレクトリの権限の順に、コンテナの中で起きることを見る。SQLite はサーバではなくライブラリで、DB を読み書きしているのは、いま起動したそのプロセス自身だ。',
  'sqlite3 を打てて SQL も書けるが、「なぜ落ちたのか」を人に説明できない人。読むだけなら準備は要らず、演習は docker を動かせることが前提。',
  'DB がファイル1個であることを、ヘッダのバイト列とプロセス一覧で示せる
database is locked と readonly database の原因を切り分けられる
SQLite を選ぶ場面と選ばない場面を、自分の言葉で言える
書き込みをまとめると速くなる理由を、誰が fsync を呼ぶかで説明できる');
INSERT INTO article_domain (slug, domain) VALUES ('sqlite', 'DB');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'wasm', 'WebAssembly（WASM）', 'ドラフト', NULL, NULL, NULL, '中級', '演習あり（コンテナ）', '2026-10-08', '2026-10-08',
  '41バイトのバイナリを手で書いて、それが何もできないことを確かめる5章。WAT を手で書いて .wasm にし、wasmtime と node の2つのホストで走らせ、最後は配布されたバイナリを実行せずに調べる。WASM は外の世界を一切知らず、できることは全部、ホストが import として手渡したものだけだ。',
  'JavaScript が読めて、WASM が速いらしいことは知っているが、「なぜサンドボックスなのか」を説明できない人。Rust も C も使わず、演習は docker で動かす。',
  'WAT を手で書いて .wasm にし、関数を呼び出せる
配布された .wasm が何を要求しているかを、実行せずに調べられる
WASM が「できないこと」を、檻の形として説明できる
文字列を、ポインタと長さの2つの数値だけでホストに渡せる');
INSERT INTO article_domain (slug, domain) VALUES ('wasm', 'ウェブ');
INSERT INTO article_domain (slug, domain) VALUES ('wasm', 'セキュリティ');

INSERT INTO article_related (slug, related) VALUES ('linuc-boot', 'linuc-disks');
INSERT INTO article_related (slug, related) VALUES ('linuc-boot', 'linuc-security');
INSERT INTO article_related (slug, related) VALUES ('linuc-files', 'linuc-admin');
INSERT INTO article_related (slug, related) VALUES ('linuc-files', 'linuc-shell');
INSERT INTO article_related (slug, related) VALUES ('linuc-files', 'linuc-disks');
INSERT INTO article_related (slug, related) VALUES ('linuc-text', 'linuc-shell');
INSERT INTO article_related (slug, related) VALUES ('linuc-packages', 'linuc-services');
INSERT INTO article_related (slug, related) VALUES ('linuc-packages', 'linuc-security');
INSERT INTO article_related (slug, related) VALUES ('linuc-disks', 'linuc-boot');
INSERT INTO article_related (slug, related) VALUES ('linuc-disks', 'linuc-files');
INSERT INTO article_related (slug, related) VALUES ('linuc-shell', 'linuc-text');
INSERT INTO article_related (slug, related) VALUES ('linuc-shell', 'linuc-admin');
INSERT INTO article_related (slug, related) VALUES ('linuc-shell', 'linuc-files');
INSERT INTO article_related (slug, related) VALUES ('linuc-network', 'linuc-security');
INSERT INTO article_related (slug, related) VALUES ('linuc-admin', 'linuc-security');
INSERT INTO article_related (slug, related) VALUES ('linuc-admin', 'linuc-files');
INSERT INTO article_related (slug, related) VALUES ('linuc-admin', 'linuc-shell');
INSERT INTO article_related (slug, related) VALUES ('linuc-services', 'linuc-packages');
INSERT INTO article_related (slug, related) VALUES ('linuc-security', 'linuc-boot');
INSERT INTO article_related (slug, related) VALUES ('linuc-security', 'linuc-admin');
INSERT INTO article_related (slug, related) VALUES ('linuc-security', 'linuc-network');
INSERT INTO article_related (slug, related) VALUES ('linuc-oss', 'linuc-packages');
INSERT INTO article_related (slug, related) VALUES ('sqlite', 'linuc-files');

INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-boot', 1, 'virsh は電源を入れ、止まるよう頼むだけ', '/linuc-boot/theory/01-virsh', 25);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-boot', 2, '入れるかは受け取る側のファイルが決める', '/linuc-boot/theory/02-ssh', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-boot', 3, 'コンテナのカーネルはホストのもの', '/linuc-boot/theory/03-container', 15);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-boot', 4, 'GUI が無くても既定は graphical.target', '/linuc-boot/theory/04-install', 12);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-boot', 5, 'ファームウェアが必ず読めるのは FAT の中のファイルだけ', '/linuc-boot/theory/05-boot', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-boot', 6, 'Ubuntu では、root にパスワードが無いとシングルユーザモードは何も聞かない', '/linuc-boot/theory/06-target', 18);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-boot', 7, 'halt では電源は切れない', '/linuc-boot/theory/07-shutdown', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-boot', 8, 'kill は止めない、合図を送るだけ', '/linuc-boot/theory/08-signal', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-boot', 9, 'exit では消えず、切断で消える', '/linuc-boot/theory/09-hup', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-boot', 10, 'X では画面の側がサーバー', '/linuc-boot/theory/10-x11', 14);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-files', 1, '名前と中身は別の場所にある', '/linuc-files/theory/01-permissions', 18);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-files', 2, 'umask は引き算ではない', '/linuc-files/theory/02-umask', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-files', 3, '特殊なビットは「誰として」と「誰が消せるか」', '/linuc-files/theory/03-special-bits', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-files', 4, 'コピーは作り直し、移動は書き換え', '/linuc-files/theory/04-cp-mv-rm', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-files', 5, 'find は名前をたどり、属性で選ぶ', '/linuc-files/theory/05-find', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-files', 6, 'tar は束ねるだけ', '/linuc-files/theory/06-tar', 18);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-files', 7, 'リンクは名前を増やすか、道順を書くか', '/linuc-files/theory/07-links', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-files', 8, 'locate は索引の写真を引く', '/linuc-files/theory/08-locate', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-text', 1, '引用符と変数は届く前に片づく', '/linuc-text/theory/01-quote', 15);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-text', 2, 'カレントは探さない', '/linuc-text/theory/02-path', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-text', 3, 'man は別物を説明することがある', '/linuc-text/theory/03-man', 14);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-text', 4, '1行は改行で終わる範囲', '/linuc-text/theory/04-lines', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-text', 5, 'uniq は隣どうしだけ', '/linuc-text/theory/05-columns', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-text', 6, 'sed は結果を見せるだけ', '/linuc-text/theory/06-sed', 22);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-text', 7, 'リダイレクトは左から配線', '/linuc-text/theory/07-redirect', 18);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-text', 8, 'xargs は空白で区切る', '/linuc-text/theory/08-pipe', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-text', 9, '. は何にでも当たる', '/linuc-text/theory/09-regex', 22);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-text', 10, ':w! は読み取り専用にも書く', '/linuc-text/theory/10-vi', 25);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-packages', 1, '入っているかどうかは台帳が決める', '/linuc-packages/theory/01-package', 15);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-packages', 2, 'apt は目録を読んで台帳に書く', '/linuc-packages/theory/02-apt', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-packages', 3, '目録は取りに行くまで古いまま', '/linuc-packages/theory/03-sources', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-packages', 4, 'dpkg は依存を読めるが取りに行かない', '/linuc-packages/theory/04-dpkg', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-packages', 5, 'yum は目録を自分で取りに行く', '/linuc-packages/theory/05-yum', 22);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-packages', 6, 'rpm -V が黙るのは台帳どおりだから', '/linuc-packages/theory/06-rpm-query', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-packages', 7, 'OK は確かめた範囲の OK', '/linuc-packages/theory/07-rpm-install', 22);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-disks', 1, 'HDD か SSD かは、装置の申告で決まる', '/linuc-disks/theory/01-hardware', 18);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-disks', 2, 'ドライバは、外しても戻ってくる', '/linuc-disks/theory/02-modules', 26);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-disks', 3, 'パーティションの表は、目次にすぎない', '/linuc-disks/theory/03-partition', 25);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-disks', 4, '起動の入口は、マウントしなくても見つかる', '/linuc-disks/theory/04-esp', 24);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-disks', 5, 'LV を広げても、ファイルシステムは広がらない', '/linuc-disks/theory/05-lvm', 22);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-disks', 6, 'ファイルシステムは、作った大きさより小さく見える', '/linuc-disks/theory/06-mkfs', 24);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-disks', 7, 'tmpfs は、メモリを先に取らない', '/linuc-disks/theory/07-swap', 17);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-disks', 8, 'マウントは、名前ではなく中身の印で指す', '/linuc-disks/theory/08-mount', 30);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-shell', 1, '起動ファイルはシェルの生まれ方で決まる', '/linuc-shell/theory/01-startup', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-shell', 2, '子のシェルは親を書き換えられない', '/linuc-shell/theory/02-source', 18);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-shell', 3, '&& と || は直前の数だけを見る', '/linuc-shell/theory/03-lists', 15);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-shell', 4, '先頭行を読むのはカーネル', '/linuc-shell/theory/04-script', 22);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-shell', 5, '引数は渡す側で切られている', '/linuc-shell/theory/05-args', 15);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-shell', 6, '返せるのは 0〜255 の数1つ', '/linuc-shell/theory/06-status', 18);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-shell', 7, 'パイプの先で数えた数は持ち帰れない', '/linuc-shell/theory/07-loops', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-shell', 8, '関数は子ではない', '/linuc-shell/theory/08-function', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-network', 1, 'アドレスは、分けるたびに減る', '/linuc-network/theory/01-address', 14);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-network', 2, 'ifconfig に見えないアドレスがある', '/linuc-network/theory/02-interface', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-network', 3, 'ifup は、自分が付けたものしか知らない', '/linuc-network/theory/03-owner', 21);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-network', 4, '返事をしたのは、相手ではなかった', '/linuc-network/theory/04-route', 18);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-network', 5, 'traceroute は、断られた返事で道を知る', '/linuc-network/theory/05-trace', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-network', 6, 'IPv6 のアドレスは、頼まなくても付いている', '/linuc-network/theory/06-ipv6', 14);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-network', 7, 'LISTEN していても、外からは入れない', '/linuc-network/theory/07-ports', 19);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-network', 8, 'resolv.conf に書いた1行は、消される', '/linuc-network/theory/08-dns', 19);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-network', 9, 'dig と ping は、別の表を引いている', '/linuc-network/theory/09-names', 18);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-admin', 1, 'ユーザの台帳は3枚に分かれている', '/linuc-admin/theory/01-ledger', 15);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-admin', 2, 'useradd は、頼まれたことしかしない', '/linuc-admin/theory/02-useradd', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-admin', 3, '所属は、書いたとおりに置き換わる', '/linuc-admin/theory/03-membership', 18);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-admin', 4, 'ロックは、扉を1つ閉めるだけ', '/linuc-admin/theory/04-lock', 18);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-admin', 5, 'crontab には「誰が」の列が無い', '/linuc-admin/theory/05-crontab', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-admin', 6, '毎日の仕事は、名前で選ばれる', '/linuc-admin/theory/06-daily', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-admin', 7, '拒否リストを消すと、誰も使えなくなる', '/linuc-admin/theory/07-at', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-admin', 8, 'ロケールは、名前で指しているだけ', '/linuc-admin/theory/08-locale', 18);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-admin', 9, '文字コードは、読む側が決める', '/linuc-admin/theory/09-iconv', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-services', 1, '時計は2つある', '/linuc-services/theory/01-clock', 17);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-services', 2, 'タイムゾーンは表示の都合だけ', '/linuc-services/theory/02-timezone', 14);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-services', 3, '基準を渡されるまで始まらない', '/linuc-services/theory/03-ntp', 15);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-services', 4, '宛先は受け手の表が決める', '/linuc-services/theory/04-rsyslog', 26);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-services', 5, 'journald は隣にある別の箱', '/linuc-services/theory/05-journald', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-services', 6, '捨てる判断も受け手側にある', '/linuc-services/theory/06-logrotate', 21);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-services', 7, '宛先に書いた名前は希望にすぎない', '/linuc-services/theory/07-mail', 25);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-security', 1, 'SUID は、実行する人ではなく持ち主で動く', '/linuc-security/theory/01-suid', 15);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-security', 2, '「ロックした」は「無効化した」ではない', '/linuc-security/theory/02-accounts', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-security', 3, '入っている人と、入れる上限', '/linuc-security/theory/03-sessions', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-security', 4, '開いているポートは、数えないと見えない', '/linuc-security/theory/04-ports', 15);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-security', 5, 'sudo は、許したものだけに絞る', '/linuc-security/theory/05-sudo', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-security', 6, 'シャドウと、使っていないサービスを止める', '/linuc-security/theory/06-services', 18);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-security', 7, 'ファイアウォールは、自分を締め出せる', '/linuc-security/theory/07-firewall', 18);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-security', 8, '鍵は、持ち主で非対称になっている', '/linuc-security/theory/08-crypto', 22);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-security', 9, 'クラウドでは、守る範囲が分かれている', '/linuc-security/theory/09-cloud', 14);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-oss', 1, 'オープンソースには、持ち主がいる', '/linuc-oss/theory/01-owner', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-oss', 2, 'コピーレフトは、配るときに効く', '/linuc-oss/theory/02-copyleft', 18);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-oss', 3, '持ち主がいないのは、パブリックドメインだけ', '/linuc-oss/theory/03-permissive', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('linuc-oss', 4, '報告先は、ソフトの中に書いてある', '/linuc-oss/theory/04-community', 15);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('sqlite', 1, 'これはファイルである', '/sqlite/theory/01-file', 12);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('sqlite', 2, '型は宣言ではなく提案', '/sqlite/theory/02-affinity', 12);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('sqlite', 3, 'まとめると速い', '/sqlite/theory/03-transaction', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('sqlite', 4, '同時に書けるのは1人', '/sqlite/theory/04-lock', 14);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('sqlite', 5, 'ディレクトリに書けないと', '/sqlite/theory/05-directory', 16);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('wasm', 1, '41バイトの計算機', '/wasm/theory/01-machine', 20);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('wasm', 2, '能力は import から', '/wasm/theory/02-import', 14);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('wasm', 3, '越えるのは数値だけ', '/wasm/theory/03-memory', 14);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('wasm', 4, 'ホストが違うと動かない', '/wasm/theory/04-host', 14);
INSERT INTO chapter (slug, n, title, url, minutes) VALUES ('wasm', 5, 'バイナリを読む', '/wasm/theory/05-binary', 18);

INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-boot', 'linuc-boot', '01', '練習機に電源を入れ、自動で起動するようにする', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-boot', 'linuc-boot', '02', 'RSA の鍵で、パスワードなしで入れるようにする', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-boot', 'linuc-boot', '03', '次の1回だけ、CUI のターゲットで起動する', 15);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-boot', 'linuc-boot', '04', '既定のターゲットを変えて、再起動後も CUI にする', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-boot', 'linuc-boot', '05', '停止を予約し、ログイン中の人に知らせる', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-boot', 'linuc-boot', '06', 'TERM を無視するプロセスを止める', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-boot', 'linuc-boot', '07', '切断しても止まらない処理を残す', 15);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-files', 'linuc-files', '01', '一覧は見せずに、1つのファイルだけ読ませる', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-files', 'linuc-files', '02', '次に開くシェルでも 640 と 750 で作られるようにする', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-files', 'linuc-files', '03', 'devs の共有ディレクトリを作る', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-files', 'linuc-files', '04', '設定ファイルを、時刻ごと控えておく', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-files', 'linuc-files', '05', '大きな .tmp だけを、深いところまで消す', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-files', 'linuc-files', '06', 'project を tar.xz にまとめる', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-files', 'linuc-files', '07', 'current を v2 に切り替える', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-files', 'linuc-files', '08', 'locate で見つからない2つを、見つかるようにする', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-text', 'linuc-text', '01', '標準のエディタを vi にする', 8);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-text', 'linuc-text', '02', '自作のコマンドを名前だけで動かす', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-text', 'linuc-text', '03', 'アクセスログのステータスを数える', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-text', 'linuc-text', '04', '設定ファイルを sed で書き換える', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-text', 'linuc-text', '05', '出力を2本に分けて保存する', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-text', 'linuc-text', '06', '名前に空白のあるファイルもまとめて消す', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-text', 'linuc-text', '07', 'レベルが ERROR か WARN の行だけを抜き出す', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-text', 'linuc-text', '08', 'vi で TODO を直す', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-packages', 'deb', '01', 'labsvc を、跡形なく消す', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-packages', 'deb', '02', 'labcalc コマンドを使えるようにする', 15);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-packages', 'deb', '03', '配られた .deb を、動く状態まで入れる', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-packages', 'rpm', '04', 'labcalc を、署名の確認を切らずに入れる', 15);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-packages', 'rpm', '05', '書き換えられた labmotd を、入れた直後に戻す', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-packages', 'rpm', '06', 'labtool を yumdownloader で取り、rpm で入れる', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-disks', 'linuc-disks', '01', 'vdb を SSD として扱わせる（再起動しても）', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-disks', 'linuc-disks', '02', 'USB メモリを挿し直しても使えなくする', 15);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-disks', 'linuc-disks', '03', '消してしまったパーティションを取り戻す', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-disks', 'linuc-disks', '04', '新しいサーバのディスクを GPT で切る', 15);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-disks', 'linuc-disks', '05', '2台のディスクにまたがる箱を作り、中身ごと広げる', 15);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-disks', 'linuc-disks', '06', '5種類のファイルシステムを作り、ext4 の予約を減らす', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-disks', 'linuc-disks', '07', 'スワップを作り、起動しても有効にする', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-disks', 'linuc-disks', '08', '一般ユーザが光学メディアをマウントできるようにする', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-shell', 'linuc-shell', '01', 'ログインしたときだけ挨拶を出す', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-shell', 'linuc-shell', '02', '自作のコマンドを、名前だけで呼べるようにする', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-shell', 'linuc-shell', '03', 'スクリプトを、全員が名前だけで使えるように置く', 15);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-shell', 'linuc-shell', '04', '引数を数えて、使い方を出すスクリプト', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-shell', 'linuc-shell', '05', '成功と失敗を、終了ステータスで返すスクリプト', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-shell', 'linuc-shell', '06', '決まったコマンドだけを選ばせるメニュー', 15);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-shell', 'linuc-shell', '07', 'ファイルごとに数えて、合計を出す', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-shell', 'linuc-shell', '08', 'bash -x で原因を見つけて直す', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-network', 'linuc-network', '01', 'enp0s17 にアドレスを手で付ける', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-network', 'linuc-network', '02', 'enp0s17 を ifupdown に持たせる', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-network', 'linuc-network', '03', 'enp0s18 を nmcli で DHCP につなぐ', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-network', 'linuc-network', '04', 'デフォルトルートを正しいルータに直す', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-network', 'linuc-network', '05', '掲示板を外から見えるようにする', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-network', 'linuc-network', '06', 'lab.example の名前を引けるようにする', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-network', 'linuc-network', '07', 'www.lab.example を正しいサーバに向ける', 8);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-admin', 'linuc-admin', '01', 'ユーザを1人、使える状態で作る', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-admin', 'linuc-admin', '02', '今の所属を残したまま、グループを1つ足す', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-admin', 'linuc-admin', '03', 'アカウントを消さずに一時停止する', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-admin', 'linuc-admin', '04', '2種類の表に、毎分のジョブを置く', 15);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-admin', 'linuc-admin', '05', '置いてあるのに走らないスクリプトを、毎日の実行に入れる', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-admin', 'linuc-admin', '06', '1人だけ、at と crontab を使えなくする', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-admin', 'linuc-admin', '07', '呼ぶ人のロケールに左右されないスクリプトにする', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-admin', 'linuc-admin', '08', '文字コードのそろわない3つのファイルを UTF-8 にする', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-services', 'linuc', '01', '時刻の表示を3箇所で揃える', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-services', 'linuc', '02', 'chrony に基準を与えて同期させる', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-services', 'linuc', '03', 'local3 のログを専用ファイルへ落とす', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-services', 'linuc', '04', 'journal の上限を自分で決める', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-services', 'linuc', '05', 'ログを切って3世代だけ残す', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-services', 'linuc', '06', 'メールを2回曲げて、ログで追う', 15);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-security', 'linuc-security', '01', 'SUID の棚卸しをする', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-security', 'linuc-security', '02', '退職者のアカウントを本当に無効化する', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-security', 'linuc-security', '03', '使っていない待ち受けを止める', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-security', 'linuc-security', '04', 'sudo を1コマンドだけに絞る', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-security', 'linuc-security', '05', 'ファイアウォールで塞ぐ（管理の ssh は残す）', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-security', 'linuc-security', '06', 'SSH 鍵でパスワードなしログインを用意する', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('linuc-security', 'linuc-security', '07', 'GnuPG でファイルを暗号化する', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('sqlite', 'sqlite', '01', 'データベースを1個のファイルとして見る', 8);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('sqlite', 'sqlite', '02', '型に嘘をつかせる', 10);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('sqlite', 'sqlite', '03', '同じ2000行を、2通りの速さで入れる', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('sqlite', 'sqlite', '04', '2人で同時に書こうとする', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('sqlite', 'sqlite', '05', '書ける権限があるのに、書けない', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('wasm', 'wasm', '01', '41バイトの計算機をつくる', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('wasm', 'wasm', '02', 'ホストから能力をもらう', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('wasm', 'wasm', '03', '数値2つで文字列を渡す', 12);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('wasm', 'wasm', '04', '同じ .wasm を2つのホストに渡す', 15);
INSERT INTO exercise (slug, cage, n, title, minutes) VALUES ('wasm', 'wasm', '05', '実行する前に調べる', 12);
