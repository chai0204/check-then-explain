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
  'linuc-files', 'ファイルとパーミッション', 'ドラフト', 'LinuC レベル1', '101', '1.02', '初級', '演習あり（コンテナ）', '2026-10-13', '2026-10-14',
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
  'linuc-disks', 'ハードウェアとディスク', 'ドラフト', 'LinuC レベル1', '101', '1.05', '初級', '演習あり（仮想マシン）', '2026-10-13', '2026-10-14',
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
  'linuc-network', 'ネットワークの基礎', 'ドラフト', 'LinuC レベル1', '102', '1.07', '初級', '演習あり（仮想マシン）', '2026-10-13', '2026-10-14',
  'LinuC レベル1 102 試験の主題1.07（プロトコルの基礎、ネットワーク構成、問題解決、クライアント側の DNS 設定）を、仮想マシンの中に作った「社内 LAN」で確かめる9章。壊れて渡される経路と名前解決を、原因を突き止めて直す。ネットワークの見え方は道具が読んだ表で決まり、ifconfig と ip、dig と ping は同じものを別々の表から読んでいる。',
  'LinuC レベル1（102）の受験者で、ip と ifconfig、dig と ping のどれで何が分かるかで止まっている人。端末でコマンドを打てて、docker を動かせることが前提。',
  'アドレスとマスクから、ネットワークアドレス・ブロードキャスト・使える台数を出せる
ping の From と ICMP のエラーから、どこで止まったかを特定できる
ss の待ち受けの表から、どのアドレスの何番で誰が待っているかを読める
getent ahosts で、/etc/hosts と DNS のどちらが答えたかを特定できる');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-network', 'ネットワーク');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-network', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-admin', 'アカウント・ジョブ・ロケール', 'ドラフト', 'LinuC レベル1', '102', '1.08', '初級', '演習あり（仮想マシン）', '2026-10-13', '2026-10-14',
  'LinuC レベル1 102 試験の主題1.08（アカウント管理、ジョブスケジューリング、ローカライゼーションと国際化）を、コンテナの中で動く仮想マシン（練習機）で確かめる9章。ユーザを作って止め、cron と at に本物の時刻でジョブを走らせ、ロケールを生成する。管理コマンドが書き換えるのは台帳の1行だけで、それが効くかは、読む側がいつ・どの列を読むかで決まる。',
  'LinuC レベル1（102）の受験者で、useradd や crontab のオプションを、読んでも覚えられない人。端末でコマンドを打てて、docker を動かせることが前提。',
  'usermod -G と -aG の違いを、結果の台帳で説明できる
ロック・期限切れ・シェルの拒否が、ログインのどの段で効くかを説明できる
ユーザの crontab と /etc/crontab の書式の違いを、動いた結果で説明できる
文字化けが「バイトの破損」ではなく「読み方の誤り」であることを示せる');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-admin', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-services', '時刻・ログ・メール', 'ドラフト', 'LinuC レベル1', '102', '1.09', '初級', '演習あり（コンテナ）', '2026-10-12', '2026-10-14',
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

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'kvm', 'KVM', 'ドラフト', NULL, NULL, NULL, '中級', '演習あり（仮想マシン）', '2026-10-14', '2026-10-14',
  'このサイトの練習機を動かしている QEMU と、それを速くする KVM を、同じ練習機を TCG と KVM で起動して比べながら確かめる6章。CPU の仮想化支援の印は CPU の自己申告で、KVM の入口は /dev/kvm というファイル1つであり、コンテナに渡すとはそのファイルと開く許可を渡すことで特権は増えないことを、エラーの文言と持てる特権の上限（CapBnd）で示す。練習機の中から見える「どのハイパーバイザーか」の名前は QEMU の名乗りで消せることも確かめ、このサイトの仮想マシン型の檻が KVM を使わない理由（全員に同じ画面・権限ゼロ）と、その代償の時間も測る。',
  'このサイトの実践編で docker run を打って練習機を動かしているが、KVM や --device /dev/kvm が何をしているかを説明できない人。Linux の端末と docker を使えることが前提で、KVM の演習には /dev/kvm のある Linux の PC が要る（無くても TCG の演習と理論編は進められる）。',
  'CPU の仮想化支援の印（vmx / svm）が CPUID の申告であることを、TCG の練習機の出力で説明できる
コンテナで /dev/kvm を開くまでの関門を、エラーの文言（No such file・Permission denied・Operation not permitted）で見分けられる
QEMU が KVM を使っているかを /proc/PID/fd で確かめ（練習機の中の名乗りは決め手にならない）、起動の時間がどこで縮むかを測れる
このサイトの仮想マシン型の檻が KVM を使わない理由と代償を、数字で言える');
INSERT INTO article_domain (slug, domain) VALUES ('kvm', '仮想化');
INSERT INTO article_domain (slug, domain) VALUES ('kvm', 'サーバー');


INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'qemu', 'QEMU', 'ドラフト', NULL, NULL, NULL, '中級', '演習あり（コンテナ）', '2026-10-14', '2026-10-14',
  'このサイトの仮想マシン型の檻の中で動いている QEMU を、libvirt を通さずに qemu-system-x86_64 と qemu-img で直接打って確かめる7章。何も渡さずに組み上がる PC、端末を壊すシリアル、書いたところだけを持つディスク、命令を翻訳する CPU、プロセスの中のネットワーク、差し替えられるファームウェアを順に見て、最後に libvirt が組み立てたコマンド行を読む。仮想マシンは QEMU という1つのプロセスで、何を演じるかは起動のときのコマンド行が決める（動いている間も、QMP で部品を足せる）。',
  'このサイトの実践編で docker run を打って練習機を起動したことはあるが、裏で何が動いているのか、--stop-timeout 30 や ssh linuc が何をしているのかを説明できない人。端末でコマンドを打てて、docker を動かせることが前提。',
  '何も渡さずに起動した QEMU の画面から、既定で組み上がる PC の部品を言える
qcow2 の差分ディスクで土台を汚さずに起動し、-snapshot と savevm の違いをファイルの大きさで示せる
練習機の NIC の名前と 10.0.2.x のアドレスが、QEMU のどの指定から来るかを説明できる
libvirt が組み立てた QEMU の引数を読み、定義の XML の各行と対応づけられる');
INSERT INTO article_domain (slug, domain) VALUES ('qemu', '仮想化');


INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'docker', 'Docker', 'ドラフト', NULL, NULL, NULL, '中級', '演習あり（仮想マシン）', '2026-10-14', '2026-10-14',
  'このサイトの実践編で打つ docker run が何をしているのかを、仮想マシン（練習機）の中に入れた本物の docker で確かめる7章。コンテナのプロセスを練習機の ps で見つけ、イメージを tar に書き出して指紋を計算し、公開したポートの宛先の書き換えを iptables の数えで見る。docker は自分では何も閉じ込めず、カーネルに頼んで1つのプロセスに名前空間・cgroup・overlay を付けているだけで、コンテナの中身も力も、起動するときに渡したもので決まる。',
  'docker run は打てるが、その1行が何をしているのか（なぜ docker stop が10秒かかるのか、なぜファイアウォールの INPUT で閉じたポートに外から届くのか）を人に説明できない人。端末でコマンドを打てて、docker か podman でコンテナを動かせることが前提。',
  'コンテナが練習機の上の1つのプロセスであることを、ps と /proc の名前空間・cgroup で示せる
タグとダイジェストの違いを、名前を付け替えた結果とイメージの中の指紋で説明できる
ファイアウォールの INPUT で塞いだポートに外から届く理由を、DNAT の後のパケットの道で説明できる
--cap-add・--device・--user が渡すもの（減らすもの）を CapEff と /dev で測り、--privileged がそれをどこまで広げるかを練習機の root と比べて言える');
INSERT INTO article_domain (slug, domain) VALUES ('docker', '仮想化');
INSERT INTO article_domain (slug, domain) VALUES ('docker', 'サーバー');
INSERT INTO article_domain (slug, domain) VALUES ('docker', 'セキュリティ');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'podman', 'Podman', 'ドラフト', NULL, NULL, NULL, '中級', '演習あり（仮想マシン）', '2026-10-14', '2026-10-14',
  'このサイトの檻を docker の代わりに動かせる podman が、docker とどこまで同じでどこから違うのかを、練習機（仮想マシン）の中の本物の podman（rootless）で確かめる7章。デーモンのいない作り、コンテナの中の root が外では本人になるユーザ名前空間、ユーザの systemd に任せる動かし方を、プロセスと UID の番号で見る。podman は打った人の権限のまま、打った人の置き場所に、打った人の systemd の下でコンテナを作る。',
  'docker の代わりに podman を打てるが、rootless だと何が違うのか、なぜログアウトでコンテナが止まるのかを人に説明できない人。端末でコマンドを打てて、docker か podman でコンテナを動かせることが前提（Docker の記事を先に読むと比べやすい）。',
  'podman にデーモンがいないことを、conmon とプロセスの親子で示せる
rootless のコンテナの中の UID が外で何番になるかを、UID の対応表から計算できる
rootless のコンテナがログアウトで止まる理由を説明し、linger と quadlet で動かし続けられる
docker と podman で、既定の特権・ping の許し方・exec の umask の決まり方・印のファイルがどう違うかを示せる');
INSERT INTO article_domain (slug, domain) VALUES ('podman', '仮想化');
INSERT INTO article_domain (slug, domain) VALUES ('podman', 'サーバー');
INSERT INTO article_domain (slug, domain) VALUES ('podman', 'セキュリティ');

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
INSERT INTO article_related (slug, related) VALUES ('kvm', 'linuc-boot');
INSERT INTO article_related (slug, related) VALUES ('linuc-boot', 'kvm');
INSERT INTO article_related (slug, related) VALUES ('kvm', 'qemu');
INSERT INTO article_related (slug, related) VALUES ('qemu', 'kvm');
INSERT INTO article_related (slug, related) VALUES ('qemu', 'linuc-boot');
INSERT INTO article_related (slug, related) VALUES ('linuc-boot', 'qemu');
INSERT INTO article_related (slug, related) VALUES ('docker', 'podman');
INSERT INTO article_related (slug, related) VALUES ('docker', 'linuc-boot');
INSERT INTO article_related (slug, related) VALUES ('docker', 'qemu');
INSERT INTO article_related (slug, related) VALUES ('docker', 'kvm');
INSERT INTO article_related (slug, related) VALUES ('podman', 'docker');
INSERT INTO article_related (slug, related) VALUES ('podman', 'linuc-boot');
INSERT INTO article_related (slug, related) VALUES ('kvm', 'docker');
INSERT INTO article_related (slug, related) VALUES ('kvm', 'podman');
INSERT INTO article_related (slug, related) VALUES ('qemu', 'docker');
INSERT INTO article_related (slug, related) VALUES ('qemu', 'podman');
INSERT INTO article_related (slug, related) VALUES ('linuc-boot', 'docker');
INSERT INTO article_related (slug, related) VALUES ('linuc-boot', 'podman');
