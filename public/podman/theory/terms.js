/**
 * 用語辞書のデータ。辞書ページ(/podman/theory/glossary)と、
 * 本文中の自動リンク(/shared/theory.js)が同じこのデータを使う。
 *   t       : 用語名（本文中でこの文字列を見つけたらリンクにする）
 *   alt     : 別名・表記ゆれ（同じくリンク対象）
 *   id      : 辞書ページ内のアンカー（kebab-case・一意）
 *   hint    : マウスを乗せたとき出る一言（20〜40字）
 *   body    : 辞書ページの説明。たとえ話を必ず1つ入れ、崩れる点を書く
 *   misread : 誤解されやすい点（1文）
 *   ch      : 詳しく扱う章（辞書から本編へ戻るリンク）
 *
 * 多義語は登録しない（コンテナ / イメージ / pod 単体 など）。
 */
window.TERM_GROUPS = [
  { g: "デーモンのいない作り", terms: [
    { t:"conmon", id:"conmon",
      hint:"コンテナ1つに1つ付き添い、プロセスの親になって終了を見届ける小さなプログラム",
      body:"podman がコンテナごとに起動する見張り役。OCI ランタイム（crun）を呼んでコンテナを作らせ、できたプロセスの親になり、出力の送り先を持ち、終了コードをファイルに書いて、<code>--exit-command</code> で podman を呼び直して後始末を頼む。podman コマンド自身はコンテナを作ったら終わるので、残るのは conmon だけである。docker の containerd-shim にあたる。<b>たとえ</b>: コインパーキングの<b>車ごとの精算機</b>。<b>崩れる点</b>: 精算機は出庫を記録して終わるが、conmon は終わるときに podman を呼び直す（見張り役から利用者の道具を呼ぶ逆向きの呼び出しがある）。",
      misread:"podman にも見えないデーモンがいて、それがコンテナの親だと思われがちだが、親は conmon である。conmon の親は、シェルから podman run -d したときは PID 1（systemd）、quadlet で起動したときは本人の systemd（systemd --user）になる。", ch:1 },

    { t:"crun", id:"crun",
      hint:"podman が既定で使う OCI ランタイム。名前空間と cgroup を設定してプロセスを作る",
      body:"C で書かれた OCI ランタイムで、podman の既定。docker が使う runc（Go で書かれている）と同じ OCI ランタイム仕様を満たすので、同じイメージ・同じ設定のコンテナを作れる。作ったら終わり、プロセスの親は conmon が持つ。<b>たとえ</b>: 同じ規格のコンセントに挿さる<b>別の会社の電化製品</b>。<b>崩れる点</b>: 規格が同じでも、細かい既定（エラーの文面、対応する機能の版）はランタイムごとに違う。",
      misread:"podman 専用の仕組みだと思われがちだが、OCI ランタイム仕様を満たす独立したプログラムで、docker から使うこともできる。", ch:1 },
  ]},
  { g: "rootless — 一般ユーザのままのコンテナ", terms: [
    { t:"rootless", alt:["ルートレス"], id:"rootless",
      hint:"root の権限を使わず、一般ユーザのままコンテナを動かすこと",
      body:"コンテナの作成・網・置き場所を、一般ユーザの権限で済ませる動かし方。ユーザ名前空間の中で中の root を外の本人に読み替え、網はユーザのプロセス（slirp4netns・pasta・rootlessport）が運び、イメージは本人のホームの下に置く。root の権限を使うのは、UID の対応表を書く newuidmap・newgidmap だけ。<b>たとえ</b>: 建物の配管に手を出せない<b>借家人の暮らし方</b>。<b>崩れる点</b>: 借家人なら大家に頼めば済むが、rootless では頼む相手（root のデーモン）が最初からいないので、できないことは本当にできない（1024 番未満の公開など）。",
      misread:"権限が少ないだけの同じ仕組みだと思われがちだが、網・置き場所・UID の扱いが根本から違う作りになる。", ch:2 },

    { t:"ユーザ名前空間", alt:["user namespace"], id:"userns",
      hint:"中と外で UID を読み替える名前空間。rootless のコンテナの土台",
      body:"Linux の名前空間の1つで、中の UID・GID を外の別の番号に読み替える。対応表は <code>/proc/PID/uid_map</code> で読め、「中の番号・外の番号・個数」の3列。rootless の podman では、中の 0 が外の本人（student なら 1000）、中の 1〜65536 が <code>/etc/subuid</code> で借りた 100000〜165535 になる。<b>たとえ</b>: 劇団の<b>役名の表</b>。舞台の上の王様は、劇場の外の名簿では本人である。<b>崩れる点</b>: 役者は背番号を自分で決められないが、ユーザ名前空間の表も本人は書けず、root の権限を持つ newuidmap が貸し出し簿（<code>/etc/subuid</code>）を見て書く。",
      misread:"中の root は練習機の root と同じだと思われがちだが、外では本人の番号として扱われる。中の root の特権が効くのは、持ち主が対応表にある番号（本人と借りた範囲）のファイルだけで、そこでは本人には読めないものも読める。", ch:2 },

    { t:"サブ UID", alt:["subuid"], id:"subuid",
      hint:"一般ユーザが、ユーザ名前空間の中で使ってよい外の UID の範囲を書いた表",
      body:"「ユーザ名:始まりの UID:個数」の形で、そのユーザがユーザ名前空間の対応表に使ってよい UID の範囲を書く（GID は <code>/etc/subgid</code>）。<code>student:100000:65536</code> なら 100000〜165535 の 65536 個。useradd が新しいユーザに自動で割り当てる。<b>たとえ</b>: 劇場の<b>背番号の貸し出し簿</b>。<b>崩れる点</b>: 背番号は返せば別の人に貸せるが、subuid の範囲が重なると、別のユーザのコンテナのファイルが同じ番号の持ち主になってしまうので、範囲は重ならないように割り当てる。",
      misread:"練習機にユーザとして登録された番号だと思われがちだが、誰でもない番号で、外から見るとただの数字の持ち主になる。", ch:2 },

    { t:"newuidmap", alt:["newgidmap"], id:"newuidmap",
      hint:"ユーザ名前空間の対応表を、subuid の範囲で書く、root の権限を持つプログラム",
      body:"一般ユーザは、自分以外の外の UID を対応表に書けない。newuidmap（GID は newgidmap）は、この練習機（Ubuntu）では持ち主が root で setuid の印（<code>s</code>）が付いている（Fedora や Arch などはファイルのケーパビリティで必要な権限だけを持たせる）。呼んだ人が <code>/etc/subuid</code> で許された範囲だけを、その権限で書く。rootless の podman が root の権限を使うのはここだけ。<b>たとえ</b>: 劇場の<b>事務所</b>。貸し出し簿を見て背番号の割り当てを書く。<b>崩れる点</b>: 事務所の人は相談に乗ってくれるが、newuidmap は貸し出し簿に無い範囲を1つも書かない。",
      misread:"podman が root で動いている証拠だと思われがちだが、root の権限を使うのは対応表を書くこの瞬間だけ。", ch:2 },

    { t:"podman unshare", id:"podman-unshare",
      hint:"コンテナと同じユーザ名前空間の中でコマンドを動かす（その中では本人が root）",
      body:"podman がコンテナに使うのと同じユーザ名前空間を作って（または入って）、その中でコマンドを実行する。中では本人が root として振る舞えるので、中の番号で <code>chown</code> したり、外から消せない 100999 などの持ち主のファイルを消したりできる。<b>たとえ</b>: <b>舞台に上がって作業する</b>こと。<b>崩れる点</b>: 舞台の王様でも、劇場が貸していない物（範囲の外の UID の持ち主、たとえば外の root のファイル）には触れない。",
      misread:"sudo のように何でもできると思われがちだが、できるのは本人と subuid の範囲の持ち物に対してだけ。", ch:2 },
  ]},
  { g: "置き場所", terms: [
    { t:"イメージの置き場所", id:"storage",
      hint:"rootless の podman のイメージとコンテナの置き場所（ユーザごと）",
      body:"rootless の podman がイメージの層・コンテナの書き込み用の層・記録のデータベース（<code>db.sql</code>）を置く場所。root の podman は <code>/var/lib/containers/storage</code> を使う。podman はデーモンを持たず、打った人の置き場所を直接読むので、student と root では見えるイメージが違う。<b>たとえ</b>: 社員ごとの<b>机の引き出し</b>。<b>崩れる点</b>: 引き出しは物として分かれているが、置き場所はディレクトリが違うだけで、練習機の root なら中を読める。分かれているのは「打った人の置き場所だけを読む」という決まりのほう。",
      misread:"同じ機械なら podman も sudo podman も docker も同じイメージを見ていると思われがちだが、全部別の置き場所。", ch:3 },
  ]},
  { g: "rootless のネットワーク", terms: [
    { t:"slirp4netns", id:"slirp4netns",
      hint:"ユーザの権限で TCP/IP を話し、rootless のコンテナを外とつなぐプログラム",
      body:"コンテナの網の名前空間に tap0（10.0.2.100）を作り、その向こうでユーザの権限の TCP/IP の処理（libslirp）が、コンテナの通信を本人の通信として外へ運ぶ。ゲートウェイは 10.0.2.2、DNS は 10.0.2.3 で、QEMU のユーザモードの網と同じ部品（libslirp）を使い、番号の初期値も slirp4netns が QEMU に合わせて決めている（libslirp 自体は番号を決めない。コンテナ自身は .100、QEMU の練習機は .15）。podman 4 の rootless の既定。<b>たとえ</b>: 窓の外に置いた<b>荷物の中継所</b>。<b>崩れる点</b>: 中継所は荷物を開けないが、slirp4netns は通信をいったん受け取って自分の接続として出し直すので、外から見た送り主は本人（練習機）になる。",
      misread:"コンテナが練習機の網に直結していると思われがちだが、練習機の網の設定は何も変わっていない。", ch:4 },

    { t:"pasta", alt:["passt"], id:"pasta",
      hint:"練習機の NIC とアドレスを写して見せる rootless の網（podman 5 の既定）",
      body:"passt という道具の一部で、コンテナの網の名前空間に練習機と同じ名前・同じアドレスの NIC を写して見せ、通信をユーザの権限で運び直す。podman 4.9 では <code>--network pasta</code> で選べ、podman 5 から rootless の既定になった。<b>たとえ</b>: 自分の住所を書いた<b>私書箱</b>。<b>崩れる点</b>: 私書箱は本人の住所とは別の場所にあるが、pasta のコンテナには練習機と同じアドレスが見えるので、コンテナと練習機の区別がアドレスでは付かない。",
      misread:"slirp4netns と同じ見え方だと思われがちだが、コンテナから見えるアドレスが違う（10.0.2.100 と 10.0.2.15）。", ch:4 },

    { t:"rootlessport", id:"rootlessport",
      hint:"rootless のポートの公開で、練習機の側で待ち受けて中へ運ぶプロセス",
      body:"rootless の podman で <code>-p</code> を使うと、練習機の側では本人の rootlessport が待ち受ける。子のプロセス（rootlessport-child）はコンテナの網の中で中のポートにつなぎ、そのつながりを親に渡すだけで、両側のデータを写し続けるのは親の rootlessport である。iptables の宛先の書き換え（DNAT）は使わない。本人のプロセスなので、1024 番未満では待ち受けられない。<b>たとえ</b>: 借家人が窓口に置く<b>受付</b>。<b>崩れる点</b>: 受付は誰でも雇えるが、1024 番未満の窓口は建物の管理者（特権）にしか開けられない決まりがある。",
      misread:"docker と同じく iptables の規則で公開していると思われがちだが、ユーザのプロセスが中継している。", ch:4 },
  ]},
  { g: "pod と systemd", terms: [
    { t:"infra", alt:["infra コンテナ","pause"], id:"infra",
      hint:"pod の名前空間を持ち続け、pod の網の寿命の区切りになる、何もしないコンテナ",
      body:"pod を作ると podman が最初に作るコンテナで、中身は何もしないで眠り続けるだけのプログラム（localhost/podman-pause のイメージ。catatonit から作る）。pod の uts・ipc の名前空間を持ち続け、アプリのコンテナはそこに相乗りする。pod の網（rootless では <code>/run/user/1000/netns/</code> の下のファイルで固定する）も infra が動いている間は保たれ、infra を止めると podman が外とのつなぎ（tap0・公開・網のファイル）を片付ける（名前空間は、入っているアプリがいる間は残り、lo だけになる）。アプリが入れ替わっても、infra が動いていればアドレスと公開は変わらない。<b>たとえ</b>: シェアハウスの<b>大家</b>。何もしないで住み続け、住所を保つ。<b>崩れる点</b>: 大家は住人の面倒を見ることもあるが、infra は本当に何もしない。住人が落ちても起こしたりしない（それは <code>--restart</code> や systemd の仕事）。",
      misread:"pod の管理をしているプロセスだと思われがちだが、名前空間を持っているだけで、何も管理していない。", ch:5 },

    { t:"linger", alt:["enable-linger"], id:"linger",
      hint:"ログインしていなくても、そのユーザの systemd を動かしておく logind の設定",
      body:"<code>loginctl enable-linger</code> で入れる。普通はユーザの systemd（user@UID.service）は最後のログインが終わると止まり、その下の rootless のコンテナも止まる。linger のユーザの systemd は練習機の起動と一緒に立ち上がり、ログアウトしても止まらない。<b>たとえ</b>: 人がいなくても<b>事務所を開けておく届け</b>。<b>崩れる点</b>: 開けておくだけで、中の仕事を始めてはくれない。起動時にコンテナを起動するのは、quadlet などで書いた systemd のサービスの役目。",
      misread:"podman run -d だけでログアウト後も動くと思われがちだが、linger が無いと本人の systemd ごと止まる。", ch:6 },

    { t:"quadlet", id:"quadlet",
      hint:".container ファイルから、podman run を1行に書いた systemd の unit を作る仕組み",
      body:"systemd の generator として動く podman の部品。<code>~/.config/containers/systemd/</code> の <code>.container</code> ファイルを、<code>systemctl --user daemon-reload</code> のときに読み、<code>ExecStart=</code> に <code>podman run …</code> を書いた unit（名前.service）を作る。起動・停止・再起動・起動時の自動起動は systemd に任せる。落ちたときの起動し直しは podman の <code>--restart</code> でもできるが、機械の起動のときに立ち上げ直す常駐の係が podman にはいないので、その役を systemd が受け持つ（systemd の下では <code>Restart=</code> を使う）。<b>たとえ</b>: 手書きのメモを<b>正式な手順書に清書する係</b>。<b>崩れる点</b>: 清書係は一度書いたら終わりだが、quadlet は reload のたびに書き直すので、作られた unit を手で直しても消える。直すのはいつも <code>.container</code> のほう。",
      misread:"書いただけで動くと思われがちだが、daemon-reload で unit が作られ、start で初めて起動する。", ch:6 },
  ]},
  { g: "docker との違い", terms: [
    { t:"印のファイル", id:"containerenv",
      hint:"podman がコンテナの中に置く印のファイル（docker は /.dockerenv）",
      body:"podman はコンテナの中に <code>/run/.containerenv</code> を置き、docker は <code>/.dockerenv</code> を置く。中のプログラムが「どのランタイムのコンテナの中か」を見分けるのに使う（このサイトの <code>lab env</code> もこれで見分けている）。<b>たとえ</b>: 部屋に置かれた<b>管理会社のステッカー</b>。<b>崩れる点</b>: ステッカーは剥がせば消えるように、これはただのファイルで、作り物のイメージに置くことも消すこともできる。確かな見分け方ではなく、目安である。",
      misread:"仕組みの違いから自然にできるものだと思われがちだが、ランタイムがわざわざ置いている印にすぎない。", ch:7 },

    { t:"docker 互換の API", id:"compat-api",
      hint:"podman が docker の API の形で頼みを受け付ける受け口（podman.socket）",
      body:"podman は <code>podman system service</code>（student の systemd の <code>podman.socket</code>）で、docker の API と同じ形の受け口を開ける。<code>DOCKER_HOST</code> をそのソケットに向ければ、docker の CLI が podman にコンテナを作らせる。podman 4.9 は docker の API の 1.41 版として振る舞う。docker の CLI 29 は 1.44 版より古いサーバとの版合わせを断る決まりを持っていて、たいていのコマンドは断りを無視して CLI 自身の版（1.52）の番号のまま頼み、podman はそれを咎めずに答えるので動くが、既定の <code>docker images</code> の表示などは断られる（<code>DOCKER_API_VERSION=1.41</code> か <code>--format</code> で出る）。<b>たとえ</b>: <b>通訳つきの窓口</b>。<b>崩れる点</b>: 窓口の通訳の世代を聞いて、客（CLI）のほうが「古い通訳は相手にしない」と決めていることがある。断るのは窓口ではなく客の側。",
      misread:"podman が dockerd を中に持っていると思われがちだが、docker の API の形を真似ているだけで、相手の版をどう扱うかはクライアントの側の決まりでも変わる。", ch:7 },
  ]},
];
