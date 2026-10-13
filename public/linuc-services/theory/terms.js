/**
 * 用語辞書のデータ。辞書ページ(/linuc-services/theory/glossary)と、
 * 本文中の自動リンク(/shared/theory.js)が同じこのデータを使う。
 *   t       : 用語名（本文中でこの文字列を見つけたらリンクにする）
 *   alt     : 別名・表記ゆれ（同じくリンク対象）
 *   id      : 辞書ページ内のアンカー（kebab-case・一意）
 *   hint    : マウスを乗せたとき出る一言（20〜40字）
 *   body    : 辞書ページの説明。たとえ話を必ず1つ入れる
 *   misread : 誤解されやすい点（1文）
 *   ch      : 詳しく扱う章（辞書から本編へ戻るリンク）
 *
 * 多義語は登録しない（service / container / image など）。
 * LinuC の出題範囲に並ぶ語のうち、「読んで詰まる語」だけを入れる。
 */
window.TERM_GROUPS = [
  { g: "時刻 — 2つの時計と、その表示", terms: [
    { t:"システムクロック", alt:["system clock"], id:"system-clock",
      hint:"カーネルが持つ時刻。起動時に RTC から受け取り、以後は独立して進む",
      body:"カーネルがメモリ上で持っている時刻。<code>date</code> と <code>timedatectl</code> が読むのはこちら。起動のときにハードウェアクロックから値を受け取り、そのあとは独立して進む。電源を切れば消える。<b>たとえ</b>: 朝に壁の時計を見て合わせた<b>腕時計</b>。日中はこれだけを見て動く。<b>崩れる点</b>: 腕時計は見たいときに壁の時計と見比べられるが、システムクロックは RTC を定期的に見ない。ずれを見つける役は NTP デーモンが担う。",
      misread:"「正しい時刻を知っている側」と思われがちだが、何も確かめていない。合っているかを判断しているのは NTP デーモンである。", ch:1 },

    { t:"ハードウェアクロック", alt:["RTC","Real Time Clock","リアルタイムクロック"], id:"rtc",
      hint:"基板上の電池で動き続ける時計。電源を切っても止まらない",
      body:"マシンの基板にある、電池で動く時計。OS が止まっていても進み続ける。<code>hwclock</code> が <code>/dev/rtc0</code> 経由で読み、<code>/proc/driver/rtc</code> からはデバイスを開かずに覗ける。コンテナにはデバイスが渡されないので <code>hwclock</code> は失敗するが、RTC そのものは存在する。<b>たとえ</b>: 部屋の<b>壁掛け時計</b>。照明を消しても動いている。<b>崩れる点</b>: 壁掛け時計はいつでも見られるが、RTC は普段読まれない。OS は起動時に1回読むだけである。",
      misread:"「hwclock が失敗したから RTC が無い」と読まれがちだが、失敗しているのは経路（デバイスファイル）の有無である。", ch:1 },

    { t:"エポック秒", alt:["UNIX 時間","Unix time","epoch"], id:"epoch",
      hint:"1970-01-01 00:00:00 UTC からの通算秒。タイムゾーンを持たない",
      body:"1970年1月1日 00:00:00 UTC からの経過秒数。<code>date +%s</code> が出す数。タイムゾーンの情報を一切持たないので、どのゾーンで表示しても値は同じになる。<b>たとえ</b>: マラソンの<b>通過タイム</b>。計測器が出す秒数は、時計の表示形式を変えても変わらない。<b>崩れる点</b>: 通過タイムはレース開始が基準だが、エポックは全世界で1つの固定された瞬間が基準である。",
      misread:"「UTC の時刻」と説明されることがあるが、時刻ではなく基準点からの秒数である。ゾーンの概念が入り込む余地が無い。", ch:2 },

    { t:"タイムゾーン", alt:["zoneinfo","tzdata"], id:"timezone",
      hint:"表示するときのオフセットの表。1つの数ではなく、期間ごとの表",
      body:"ある地域で、いつからいつまでどれだけ UTC からずらして表示するかを並べた表。実体は <code>/usr/share/zoneinfo/</code> 配下のバイナリで、<code>Asia/Tokyo</code> には過去のサマータイムを含む9件の切り替えが入っている。<b>たとえ</b>: 改正を重ねた<b>就業規則</b>。「いまの始業時刻」だけでなく、いつから変わったかの履歴が要る。<b>崩れる点</b>: 就業規則は人が読むが、こちらはプログラムが読む固定長の表である。",
      misread:"「+9時間という1つの数」と思われがちだが、同じ地域でも年代によってオフセットが変わるので表になっている。", ch:2 },
  ]},

  { g: "時刻合わせ — 測ることと直すこと", terms: [
    { t:"NTP", alt:["Network Time Protocol"], id:"ntp",
      hint:"ネットワーク越しに時刻を合わせる仕組み。123/udp を使う",
      body:"ネットワーク上の基準と時刻を比べ、ずれを求めるためのプロトコル。<code>123/udp</code> で話す。実装は複数あり、現行の Ubuntu では <code>chronyd</code>、従来からあるものが <code>ntpd</code> である。公開された基準サーバ群の名前が <code>pool.ntp.org</code>。<b>たとえ</b>: <b>時報への電話</b>。かけて差をメモする作業の自動化である。<b>崩れる点</b>: 電話は1回で済むが、NTP は往復の遅延を見積もるために何度も測る。",
      misread:"「時刻を配る仕組み」と読まれがちだが、配られた値を自分の時計に反映するかどうかはローカル側の設定と権限が決める。", ch:3 },

    { t:"stratum", alt:["ストラタム"], id:"stratum",
      hint:"基準から何段離れているかの数。基準にした相手より必ず1大きい",
      body:"時刻の供給源から何段目かを表す数。原子時計や GPS に直結した機器が 1 で、それを基準にしたサーバが 2 になる。自分が基準にした相手より必ず1大きくなる。この教材の檻では基準サーバが <code>local stratum 8</code> なので、クライアントは 9 になる。<b>たとえ</b>: 伝言ゲームの<b>順番</b>。何人目かが分かれば、どれだけ劣化しうるかの見当がつく。<b>崩れる点</b>: 伝言ゲームは人数が多いほど必ず崩れるが、stratum が大きくても測定が正確なら誤差は小さい。あくまで目安である。",
      misread:"精度の数値だと読まれがちだが、距離（段数）であって誤差の量そのものではない。", ch:3 },

    { t:"CAP_SYS_TIME", alt:[], id:"cap-sys-time",
      hint:"システムクロックを変更する権限。コンテナには既定で渡されない",
      body:"Linux のケーパビリティの1つで、システムクロックを変更できる権限。これが無いと <code>date -s</code> は <code>Operation not permitted</code> になり、<code>chronyc makestep</code> は <code>500 Failure</code> を返す。ずれを<b>測る</b>のには要らないので、権限が無くても同期状態の報告はできる。<b>たとえ</b>: 時計の<b>裏蓋の鍵</b>。針の位置を読むのは誰でもできるが、回すには鍵が要る。<b>崩れる点</b>: 鍵は後から借りられるが、ケーパビリティは起動時に決まり、動いているプロセスには足せない。",
      misread:"root なら必ず持っていると思われがちだが、コンテナの root は渡されたケーパビリティしか持たない。", ch:3 },
  ]},

  { g: "ログ — ラベルと受け皿", terms: [
    { t:"facility", alt:["ファシリティ"], id:"facility",
      hint:"ログがどの種類の機能から出たかを表すラベル。local0〜7 は自由に使える",
      body:"syslog のログに付ける「出どころの種類」のラベル。<code>auth</code>・<code>cron</code>・<code>daemon</code>・<code>kern</code>・<code>mail</code> などが決まっており、<code>local0</code> から <code>local7</code> までは用途が決まっていないので自分のアプリに割り当てられる。宛先を決めるために使われ、ログの行には残らない。<b>たとえ</b>: 郵便物に押す<b>種別のスタンプ</b>。<b>崩れる点</b>: スタンプは郵便物に残るが、facility は分類に使われたあと行から消える。",
      misread:"ファイル名やディレクトリを指すと読まれがちだが、宛先ではなくラベルである。どのファイルへ入れるかは受け手の設定が決める。", ch:4 },

    { t:"priority", alt:["プライオリティ","severity"], id:"priority",
      hint:"ログの重さの段。emerg から debug までの8段で、上下がある",
      body:"ログの重さを表す8段の値。重い順に <code>emerg</code>・<code>alert</code>・<code>crit</code>・<code>err</code>・<code>warning</code>・<code>notice</code>・<code>info</code>・<code>debug</code>。設定で <code>local4.warning</code> と書くと warning 以上が、<code>local4.=warning</code> と書くと warning だけが対象になる。<b>たとえ</b>: 社内の<b>役職</b>。「課長以上」と言えば部長も社長も含む。<b>崩れる点</b>: 役職は人に固定されているが、priority は1行ごとに送り手が自由に決められる。",
      misread:"数値が大きいほど重いと読まれがちだが、syslog の数値は emerg が 0 で debug が 7、つまり小さいほど重い。", ch:4 },

    { t:"セレクタ", alt:["selector"], id:"selector",
      hint:"rsyslog の設定行の左側。facility.priority の形でどの行を拾うか決める",
      body:"rsyslog の設定1行の左半分で、<code>facility.priority</code> の形で書く。右半分が宛先。<code>*.*</code> は全部、<code>mail.err</code> は mail の err 以上、<code>local3.none</code> はその facility を除外する。当てはまった行は、当てはまったすべての宛先に書かれる。<b>たとえ</b>: 郵便局の<b>仕分け条件</b>。条件に合う郵便物を該当する棚すべてに写しとして入れる。<b>崩れる点</b>: 郵便物は1通しかないので複数の棚には入らないが、ログは複製される。",
      misread:"上から順に評価して最初に当たったところで止まると読まれがちだが、当てはまる行すべてが実行される。", ch:4 },

    { t:"journald", alt:["systemd-journald","journal"], id:"journald",
      hint:"systemd が持つログの箱。項目ごとにバイナリで保存し、journalctl で読む",
      body:"systemd のログ収集デーモン。テキスト1行ではなく、PID・ホスト名・起動 ID・ユニット名などを項目に分けたバイナリ形式で保存する。だから <code>journalctl -u</code> や <code>-p</code> で絞り込める。保存先は <code>/var/log/journal/</code>（残る）か <code>/run/log/journal/</code>（消える）。rsyslog とは独立しており、同じ1行が両方に入る。<b>たとえ</b>: 自由記述の日誌に対する<b>項目が決まった記録簿</b>。欄ごとに読めるので後から絞れる。<b>崩れる点</b>: 記録簿は欄外を書けないが、journald は本文も丸ごと持っている。情報は減っていない。",
      misread:"<code>/var/log/syslog</code> を整形して見せていると読まれがちだが、まったく別の保存領域を持っている。片方を消しても他方は残る。", ch:5 },

    { t:"machine-id", alt:["/etc/machine-id"], id:"machine-id",
      hint:"そのインストールを識別する32桁の16進。journal の保存先の名前になる",
      body:"そのシステムを一意に識別する32桁の16進文字列。<code>/etc/machine-id</code> にある。journal を永続化すると <code>/var/log/journal/&lt;machine-id&gt;/</code> というディレクトリができる。<b>たとえ</b>: 建物の<b>登記番号</b>。ホスト名が表札なら、こちらは変わらない番号である。<b>崩れる点</b>: 登記番号は建て替えても残ることがあるが、machine-id は再インストールで変わる。",
      misread:"ホスト名の別名と読まれがちだが、ホスト名を変えても machine-id は変わらない。", ch:5 },

    { t:"logrotate", alt:["ログローテーション"], id:"logrotate",
      hint:"ログを切って世代管理する別プログラム。常駐せずタイマーに呼ばれる",
      body:"ログファイルを切り替え、古い世代を圧縮・削除するプログラム。常駐しない。<code>logrotate.timer</code>（または <code>/etc/cron.daily/</code>）が1日1回呼ぶ。設定は <code>/etc/logrotate.conf</code> の既定と <code>/etc/logrotate.d/</code> の対象ごとの設定の2段。前回いつ切ったかは <code>/var/lib/logrotate/status</code> に残る。<b>たとえ</b>: 月末に来る<b>書類の整理業者</b>。規定表を持っているが、カレンダーは持っていない。<b>崩れる点</b>: 業者は来れば何かするが、logrotate は条件を満たさなければ何もせず終了コード 0 を返す。",
      misread:"ログを書くプログラムの機能と思われがちだが、完全に別のプログラムである。journal は対象外で、自分で上限を持つ。", ch:6 },

    { t:"su ディレクティブ", alt:["su root adm"], id:"su-directive",
      hint:"logrotate がどのユーザ・グループとして作業するかの指定",
      body:"logrotate の設定に書く「誰として作業するか」の指定。ログの親ディレクトリが root 以外のグループに書き込み可のとき、これが無いと logrotate はそのログを飛ばす。Debian 系では <code>/etc/logrotate.conf</code> に <code>su root adm</code> が書かれていて、<code>include</code> された設定はそれを受け継ぐ。<b>たとえ</b>: 現場に入るための<b>権限を明示した書類</b>。事務所には用意されているが、現場へ直行すると持っていない。<b>崩れる点</b>: 書類は現場で借りられるが、こちらは実行時に渡したファイルで決まる。",
      misread:"セキュリティ上の飾りと読まれがちだが、これが無いと /var/log 配下のログが実際に飛ばされる。", ch:6 },
  ]},

  { g: "メール — 宛先が曲がる場所", terms: [
    { t:"MTA", alt:["Mail Transfer Agent","メール配送エージェント"], id:"mta",
      hint:"メールを受け取って配送するプログラム。postfix や exim がこれ",
      body:"メールを受け取り、宛先に応じて配送するプログラム。<code>postfix</code> と <code>exim</code> が代表で、どちらも <code>sendmail</code> 互換のコマンド（<code>sendmail</code>・<code>mailq</code>・<code>newaliases</code>）を持つので、使う側のコマンドは実装が変わっても同じになる。<b>たとえ</b>: <b>郵便局</b>。差出人は窓口に出すだけで、経路は局が決める。<b>崩れる点</b>: 郵便局は宛先住所に従うが、MTA は自分の持つ表で宛先を書き換えてよい。",
      misread:"メールソフト（送受信する側）と混同されがちだが、MTA は配送する側である。", ch:7 },

    { t:"エイリアス", alt:["/etc/aliases","aliases"], id:"aliases",
      hint:"システム全体でメールの宛先を書き換える表。更新後 newaliases が要る",
      body:"<code>/etc/aliases</code> に書く、システム全体の宛先書き換え表。<code>alice: bob</code> と書けば alice 宛が bob に届く。postfix が実際に読むのは <code>hash:</code> 形式の <code>/etc/aliases.db</code> なので、テキストを直したあと <code>newaliases</code> で作り直す必要がある。<b>たとえ</b>: 郵便局が持つ<b>転居届の台帳</b>。<b>崩れる点</b>: 転居届は本人が出すが、この表は管理者が書く。本人の意思とは無関係に曲げられる。",
      misread:"テキストを書き換えれば効くと思われがちだが、<code>newaliases</code> を打つまで古い .db が使われ続ける。", ch:7 },

    { t:".forward", alt:["~/.forward","forward ファイル"], id:"forward",
      hint:"ユーザ本人が自分宛のメールを転送する設定。作り直しは要らない",
      body:"ユーザのホームディレクトリに置く、自分宛メールの転送先を書いたテキストファイル。エイリアスの展開より後に見られる。テキストとして直接読まれるので <code>newaliases</code> のような作り直しは要らない。ただし group や other に書き込み権があると postfix は読まず、警告をログにだけ出す。<b>たとえ</b>: 自席に貼る<b>「不在時はこの人へ」のメモ</b>。<b>崩れる点</b>: メモは誰が書いても読まれるが、.forward は権限が緩いと読まれない。しかも読まなかったことを本人に伝えない。",
      misread:"設定したのに転送されないとき設定内容を疑いがちだが、まず権限（world writable でないか）を見る。", ch:7 },

    { t:"postmaster", alt:[], id:"postmaster",
      hint:"管理者宛の予約された名前。誰に届くかは /etc/aliases が決める",
      body:"メールの運用で予約されている管理者の宛先名。メールの不具合を知らせる先として、どのサーバにも置くことになっている。実際に誰に届くかは <code>/etc/aliases</code> の <code>postmaster: root</code> が決める。なお、配送できなかったメールの差し戻しは postmaster ではなく元の送り手に返る（この教材の檻では送り手が root なので、どちらも root に集まった）。<b>たとえ</b>: 会社の<b>総務の窓口名</b>。<b>崩れる点</b>: 総務は人だが、postmaster は役職名だけで、誰を指すかは表が決める。",
      misread:"固定のユーザ名だと思われがちだが、エイリアスで任意のユーザに向けられる。", ch:7 },

    { t:"バウンス", alt:["bounce","差し戻し"], id:"bounce",
      hint:"配送できなかったことを知らせるメール。元の送り手に返る",
      body:"メールを配送できなかったとき、MTA がその旨を知らせるために作るメール。postfix のログには <code>sender non-delivery notification</code> と出て、元の送り手に送られる。元の1通はキューから消えるので、<code>mailq</code> が空でも配送が成功したとは言えない。<b>たとえ</b>: 「宛先不明」と書かれて差出人に戻ってくる<b>封筒</b>。<b>崩れる点</b>: 郵便の差出人は人ごとに違うが、サーバの上でメールを出すプログラムの多くは root として動くので、戻ってきた通知は root のメールボックスに集まる。",
      misread:"キューに残り続けると思われがちだが、差し戻しが作られた時点でキューからは消える。確かめるのは送り手のメールボックス（この教材の檻では root）である。", ch:7 },
  ]},
];
