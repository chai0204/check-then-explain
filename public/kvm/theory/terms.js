/**
 * 用語辞書のデータ。辞書ページ(/kvm/theory/glossary)と、
 * 本文中の自動リンク(/shared/theory.js)が同じこのデータを使う。
 *   t       : 用語名（本文中でこの文字列を見つけたらリンクにする）
 *   alt     : 別名・表記ゆれ（同じくリンク対象）
 *   id      : 辞書ページ内のアンカー（kebab-case・一意）
 *   hint    : マウスを乗せたとき出る一言（20〜40字）
 *   body    : 辞書ページの説明。たとえ話を必ず1つ入れ、崩れる点を添える
 *   misread : 誤解されやすい点（1文）
 *   ch      : 詳しく扱う章（辞書から本編へ戻るリンク）
 *
 * 多義語は登録しない（コンテナ / イメージ / ドメイン / ゲスト単体 など）。
 * 「読んで詰まる語」だけを入れる。
 */
window.TERM_GROUPS = [
  { g: "CPU と仮想化支援 — 印は自己申告", terms: [
    { t:"仮想化支援機能", alt:["VT-x","AMD-V"], id:"hw-virt",
      hint:"仮想マシンの命令を CPU に直接実行させる仕組み。Intel は VT-x、AMD は AMD-V",
      body:"CPU に組み込まれた、仮想マシンの中の OS（ゲスト）の命令を CPU がそのまま実行し、ハードウェアに触る命令のときだけハイパーバイザーに処理を戻す仕組み。Intel は VT-x（<code>/proc/cpuinfo</code> の印は <code>vmx</code>）、AMD は AMD-V（<code>svm</code>）。KVM はこれを使う。<b>たとえ</b>: 工場に作り付けの<b>来客用の作業場</b>。来客は自分で作業し、危ない機械に手を伸ばしたときだけブザーが鳴って係が代わる。<b>崩れる点</b>: 来客は作業場にいると分かっているが、ゲストの OS は自分の命令が作業場の中で実行されていることを知らされない。",
      misread:"印（vmx / svm）があれば使えると思われがちだが、印は CPU の申告にすぎず、使うにはカーネルの KVM と /dev/kvm を開けることが要る。", ch:1 },

    { t:"CPUID", alt:[], id:"cpuid",
      hint:"OS が CPU に「あなたは何者か・何ができるか」を尋ねる命令",
      body:"x86 の CPU の命令の1つで、番号を渡すと、その番号の問いへの答え（メーカーの名前、持っている機能の印、ハイパーバイザーの名前など）が返る。Linux の <code>/proc/cpuinfo</code> の <code>flags</code> や <code>lscpu</code> は、主にこの答えから作られている。TCG の練習機では答えを QEMU が作る。KVM でも、練習機が CPUID を実行すると本物の CPU は KVM に戻り、KVM が QEMU の用意した答えの表から答える（表に載せられるのは本物の CPU と KVM が持つ機能だけ）。0x40000000 番には、ハイパーバイザーの名前が入る。この記事の練習機では TCG でも KVM でも QEMU が書いていて（<code>TCGTCGTCGTCG</code>・<code>KVMKVMKVM</code>）、<code>-cpu …,kvm=off</code> で KVM の名前を書かないこともできる。<b>たとえ</b>: CPU が自分で書き込む<b>問診票</b>。OS はそれを読んで、使う部品を決める。<b>崩れる点</b>: 病院は問診票の後に検査をするが、仮想マシンの中の OS は、答えを外から確かめる方法を持たない（CPU の設定 MSR を読んでも、答えるのはやはりハイパーバイザーである）。",
      misread:"CPU の回路を調べた結果だと思われがちだが、答えは書き換えられる（仮想マシンでは QEMU や KVM が答えを作っている）。", ch:1 },

    { t:"ハイパーバイザー", alt:[], id:"hypervisor",
      hint:"仮想マシンを動かし、ゲストに CPU やメモリがあるように見せる層",
      body:"仮想マシンの中の OS に、CPU・メモリ・装置があるように見せて動かす層。この記事では、KVM（カーネルの中）と QEMU（装置を真似するプロセス）が組になってこの役をする。TCG のときは QEMU だけで全部を受け持つ。ゲストは CPUID の <code>hypervisor</code> の印で「自分は仮想マシンだ」と知り、0x40000000 番の名前でどのハイパーバイザーかを知る（この記事では、名前は QEMU が書いている。消すこともできるので、名前は KVM を使っている証拠にならない）。<b>たとえ</b>: 舞台の<b>裏方</b>。役者（ゲスト）が本物の部屋だと思って演じられるよう、壁や扉を用意する。<b>崩れる点</b>: 裏方は客席から見えないように振る舞うが、QEMU は既定でゲストに名前（<code>KVMKVMKVM</code>）をわざわざ知らせ、ゲストもそれを使って協力する（準仮想化）。",
      misread:"仮想マシンからは外が見えないように作るものだと思われがちだが、QEMU は既定で、KVM のときも TCG のときも CPUID に名前を書いてゲストに知らせている。反対に、名前があることは KVM を使っている証拠にならない（kvm=off で消せる。確かめるなら外の /proc/PID/fd）。", ch:5 },

    { t:"ファームウェア", alt:["UEFI","BIOS"], id:"firmware",
      hint:"電源を入れて最初に動く、OS より前のプログラム（UEFI・BIOS）",
      body:"計算機の電源を入れて最初に動くプログラム。装置を初期化し、ディスクからブートローダ（GRUB）を読み込んで渡す。いまは UEFI、昔は BIOS。仮想化支援機能を有効にするかどうかの設定もここにある（切られていると、Intel の CPU では Linux 5.6 以降、AMD の CPU では Linux 6.7 以降は、<code>vmx</code> / <code>svm</code> を並べない）。練習機は OVMF（QEMU 用の UEFI）で起動する。<b>たとえ</b>: 店の<b>開店準備の係</b>。シャッターを開け、レジを点け、店長（OS）を呼ぶ。<b>崩れる点</b>: 開店準備は毎日同じ人がやるが、練習機のファームウェアは QEMU が渡したファイル（<code>OVMF.fd</code>）で、起動のたびに読み込まれる。",
      misread:"OS の一部だと思われがちだが、OS が動き出す前に仕事を終える別のプログラム。KVM でその仕事も速くなるが、後ろに GRUB の決まった待ち時間があるので、カーネルが動き出すまでの時間全体は少ししか縮まない（第4章）。", ch:4 },
  ]},

  { g: "KVM と /dev/kvm — 入口はファイル1つ", terms: [
    { t:"KVM", alt:["Kernel-based Virtual Machine"], id:"kvm",
      hint:"仮想化支援機能を使って仮想マシンを動かす、Linux のカーネルの部品",
      body:"Linux のカーネルに組み込まれる仮想化の部品（<code>kvm</code> と、CPU のメーカーごとの <code>kvm_intel</code> / <code>kvm_amd</code>）。使う側には <code>/dev/kvm</code> というファイル1つだけを見せ、そこを開いたプログラム（QEMU など）に、カーネルの中の仮想マシンと仮想の CPU を作って渡す。ディスクやネットワークなどの装置の真似はしない（割り込みの装置など一部だけを受け持つ）ので、QEMU と組で使う。<b>たとえ</b>: 役所の奥にある<b>専門の部署</b>。窓口の札（<code>/dev/kvm</code>）を通してしか頼めない。<b>崩れる点</b>: 役所の部署は窓口の人が取り次ぐが、KVM は頼んだプログラムに、作った仮想マシンそのものをファイルとして手渡す。",
      misread:"QEMU の機能の1つだと思われがちだが、カーネルの部品で、QEMU は頼まれたときだけ使う（-accel kvm）。", ch:2 },

    { t:"カーネルのモジュール", alt:["カーネルの部品"], id:"kernel-module",
      hint:"動いているカーネルに後から読み込める部品。KVM もこれ",
      body:"Linux のカーネルに、動いたまま読み込んだり外したりできる部品。<code>/proc/modules</code>（<code>lsmod</code>）で一覧が見える。KVM は <code>kvm</code>（本体）と <code>kvm_intel</code> / <code>kvm_amd</code>（CPU のメーカーごと）の2つ。CPU が仮想化支援を名乗っていると、起動のときに自動で読み込まれる。<b>たとえ</b>: 家電の<b>アタッチメント</b>。本体（カーネル）に付ければ機能が増える。<b>崩れる点</b>: アタッチメントは形が合えば付くが、<code>kvm_intel</code> は CPU が <code>vmx</code> を名乗っていないと読み込まれない。付くかどうかを決めているのは、CPU の申告である。",
      misread:"コンテナの中から見える一覧はコンテナのものだと思われがちだが、/proc/modules はホストのカーネル（あなたの PC）のものを見せている。", ch:2 },

    { t:"デバイスファイル", alt:[], id:"device-file",
      hint:"カーネルの中の装置や仕組みへの入口になるファイル。種類と番号で行き先が決まる",
      body:"<code>/dev</code> の下にある、カーネルの中の装置や仕組みにつながるファイル。<code>ls -l</code> の行の頭が <code>c</code>（文字デバイス）か <code>b</code>（ブロックデバイス）で、2つの番号（<code>/dev/kvm</code> は 10, 232）がカーネルの中の行き先を決める。名前ではなく番号が本体で、<code>mknod</code> で同じ番号のファイルを作れば同じ行き先になる。ただし、開けるかどうかは別に決まる（device cgroup・ファイルの権限）。<b>たとえ</b>: 役所の<b>窓口の番号札</b>。札は行き先を示すだけで、仕事をしているのは奥の部署である。<b>崩れる点</b>: 番号札は誰が持っても窓口に行けるが、デバイスファイルは、持っている（作れた）だけでは開けない。",
      misread:"中にデータが入ったファイルだと思われがちだが、中身は無く、開くとカーネルの中の行き先につながる。", ch:2 },

    { t:"device cgroup", alt:["デバイスの cgroup"], id:"device-cgroup",
      hint:"コンテナが開いてよいデバイスの番号の一覧。--device がこれに足す",
      body:"cgroup（プロセスのまとまりに制限を付ける Linux の仕組み）の一部で、そのまとまりのプロセスが、どの番号のデバイスを開いたり作ったりしてよいかを決める。docker の既定では、端末や <code>/dev/null</code> などの決まった番号だけを開いてよい。<code>--device /dev/kvm</code> はファイルを置くと同時に、10, 232 をこの一覧に足す。一覧に無い番号は、ファイルの権限が通っても、root でも開けない（Operation not permitted）。カーネルはファイルの権限を先に確かめるので、権限でも断られるときは Permission denied のほうが出る。<b>たとえ</b>: ビルの<b>入館証に書かれた、入ってよい部屋の番号</b>。合鍵を作っても、番号が無ければ警備に止められる。<b>崩れる点</b>: 警備は人を見て止めるが、device cgroup は「どのまとまりのプロセスか」で止める。同じ root でも、コンテナの中か外かで結果が違う。",
      misread:"コンテナの中の root なら何でも開けると思われがちだが、この一覧に無い番号は、ファイルの権限が通ったあとで断られ、root でも開けない。", ch:2 },

    { t:"補助グループ", alt:["--group-add"], id:"supplementary-group",
      hint:"プロセスが持つ、主なグループ以外のグループ。ファイルの権限の判定に使われる",
      body:"プロセスは主なグループ（<code>gid</code>）のほかに、いくつもの補助グループを持てる。ファイルのグループの権限は、このどれかが持ち主のグループと一致すれば効く。<code>docker run --group-add 302</code> は、コンテナの中のプロセスに補助グループ 302 を番号で足す。<code>/proc/self/status</code> の <code>Groups:</code> で見える。<b>たとえ</b>: 名刺の<b>所属の欄に足す、兼務先</b>。本務（主なグループ）とは別に、兼務先の部屋にも入れる。<b>崩れる点</b>: 名刺の兼務先は名前で書くが、カーネルは番号でしか覚えていない。檻の <code>/etc/group</code> に名前が無ければ、<code>groups: cannot find name for group ID 302</code> と出る。",
      misread:"コンテナの中で kvm という名前のグループに入ればよいと思われがちだが、照らし合わせるのは番号で、檻の中の kvm グループの番号はホストと違いうる（この檻には kvm という名前のグループ自体が無い）。", ch:2 },

    { t:"ケーパビリティ", alt:["CapEff","CapBnd"], id:"capability",
      hint:"root の特権を細かく分けたもの。CapEff はいま効いているもの、CapBnd は持てる上限",
      body:"root の特権を、時刻を変える・ネットワークを設定する・装置を作る、などの約40個に分けたもの。<code>/proc/self/status</code> の <code>CapEff</code> がいま効いている特権、<code>CapBnd</code> が持てる特権の上限（16進のビット列）。この檻の lab は <code>CapEff</code> が 0（特権なし）のまま KVM を使える。KVM を使うのに特権は要らず、<code>/dev/kvm</code> を開ければよいからである。起動のときに渡しすぎていないかは <code>CapBnd</code> で見る（lab は root ではないので、<code>--privileged</code> で起動しても <code>CapEff</code> は 0 のまま。<code>CapBnd</code> が docker の既定の <code>00000000a80425fb</code> から <code>000001ffffffffff</code> に増える）。<b>たとえ</b>: <b>合鍵の束を1本ずつに分けたもの</b>。必要な鍵だけを渡せる。<b>崩れる点</b>: 合鍵は1本で1つの扉を開けるが、ケーパビリティの中には1本で多くの扉が開くもの（CAP_SYS_ADMIN）があり、分けたつもりでもほとんど root と変わらないことがある。",
      misread:"KVM を使うには特権（--privileged や --cap-add）が要ると思われがちだが、要るのは /dev/kvm を開けることだけである。", ch:2 },
  ]},

  { g: "QEMU と KVM — 頼まれたときだけ使う", terms: [
    { t:"TCG", alt:["Tiny Code Generator"], id:"tcg",
      hint:"QEMU が仮想マシンの命令を翻訳して実行する方式。特権が要らない代わりに遅い",
      body:"Tiny Code Generator。QEMU が、仮想マシンの CPU の命令をひとまとまりずつ、いま動いている CPU の命令に翻訳して実行する方式（訳したものは取っておいて使い回す）。<code>/dev/kvm</code> も特権も使わない。この記事の <code>qemu-system-x86_64</code> は、アクセラレータを指定されなければ TCG で動く。CPU の答え（CPUID）も QEMU が作るので、既定の型では Intel の PC の上で AMD の CPU と AMD-V を名乗る。<b>たとえ</b>: 外国語の本を<b>声に出して訳しながら読む</b>。誰でもできるが遅い。<b>崩れる点</b>: 訳しながら読む人は原文を変えないが、TCG は CPU そのものを作り替えて見せ、元の CPU（Intel）と違うメーカー（AMD）を名乗らせることまでする。",
      misread:"仮想マシンは必ず仮想化支援機能を使うと思われがちだが、TCG は使わずに動く。遅いだけで中の OS は普通に動き、hypervisor の印で仮想マシンだとも分かる。", ch:3 },

    { t:"アクセラレータ", alt:["-accel"], id:"accelerator",
      hint:"QEMU が仮想マシンの命令を何で実行するか（tcg・kvm など）",
      body:"QEMU が、仮想マシンの CPU の命令を何で実行するかの選択。<code>-accel tcg</code>（翻訳して実行）、<code>-accel kvm</code>（KVM で本物の CPU に実行させる）など。<code>qemu-system-x86_64 -accel help</code> で、この QEMU に組み込まれているものが分かる（組み込まれていても、<code>/dev/kvm</code> を開けなければ kvm は使えない）。古い書き方は <code>-enable-kvm</code>・<code>-machine accel=kvm</code>。<b>たとえ</b>: タクシーに伝える<b>道の選び方</b>。「高速道路で」と言わなければ下の道を走る。<b>崩れる点</b>: 運転手は気を利かせて高速道路を勧めることがあるが、QEMU は何も勧めず、黙って TCG で走る。",
      misread:"/dev/kvm があれば QEMU が自動で KVM を使うと思われがちだが、qemu-system-x86_64 は指定しなければ TCG のままである（第3章。名前が kvm で終わる作りの QEMU は KVM を先に試す）。", ch:3 },

    { t:"ファイル記述子", alt:["fd"], id:"fd",
      hint:"プロセスが開いているファイルを指す番号。/proc/PID/fd で見える",
      body:"プロセスが開いたファイルごとにカーネルが渡す番号。<code>/proc/PID/fd/</code> の下に番号ごとのリンクがあり、<code>readlink</code> で何を指しているかが分かる。KVM で動く QEMU は、<code>/dev/kvm</code> のほかに、カーネルの中の仮想マシン（<code>anon_inode:kvm-vm</code>）と仮想の CPU（<code>anon_inode:kvm-vcpu:0</code> など）をファイル記述子として持っている。<code>anon_inode</code> は、ディスクの上に名前の無いファイルという意味。<b>たとえ</b>: 図書館で借りた本の<b>貸出票の番号</b>。番号で、借りている本が分かる。<b>崩れる点</b>: 貸出票は本棚にある本を指すが、<code>kvm-vm</code> はどこの棚にも無い。カーネルが作り、QEMU が閉じれば消える。",
      misread:"ファイル記述子はディスクの上のファイルだけを指すと思われがちだが、KVM の仮想マシンのように、名前の無いカーネルの中のものも指す。", ch:3 },

    { t:"ユーザ空間", alt:["userspace"], id:"userspace",
      hint:"カーネルの外で動くプログラムの世界。systemd-analyze の userspace の時間",
      body:"カーネルの外側で動く、普通のプログラム（systemd やそれが起動するサービス）の世界。<code>systemd-analyze</code> は起動の時間を、カーネルが動き出してから systemd に渡すまで（<code>kernel</code>）と、systemd が起動し終わるまで（<code>userspace</code>）に分けて出す。練習機のユーザ空間の時間は、KVM で約 10 倍短くなった。<b>たとえ</b>: 店の<b>開店後の営業</b>。開店準備（ファームウェア・GRUB・カーネル）が終わってから、店員（プログラム）が次々に仕事を始める。<b>崩れる点</b>: 店の営業は客を待つ時間が多いが、起動のユーザ空間は CPU が働き続ける時間がほとんどで、だから KVM でよく縮む。",
      misread:"ユーザ空間のプログラムは仮想マシンでは遅いと思われがちだが、KVM では本物の CPU がそのまま実行するので、TCG との差がいちばん大きく出る。", ch:4 },

    { t:"GRUB", alt:[], id:"grub",
      hint:"カーネルを読み込んで起動するブートローダ。メニューで決まった秒数待つ",
      body:"ファームウェアの次に動き、カーネルと initramfs をディスクから読み込んで渡すプログラム（ブートローダ）。練習機はメニューを 3 秒出して待つ設定（<code>/etc/default/grub.d/99-lab.cfg</code> の <code>GRUB_TIMEOUT=3</code>）。この待ち時間は、TCG でも KVM でも同じ 3 秒である。<b>たとえ</b>: 駅の<b>発車ベル</b>。鳴っている間は、電車がどれだけ速くても出発しない。<b>崩れる点</b>: 発車ベルは乗客のために鳴るが、練習機の GRUB の待ち時間は、別の記事で読者がメニューからカーネルに引数を渡す練習をするために置いてある。",
      misread:"起動の時間はすべて CPU の速さで決まると思われがちだが、GRUB のように決まった時間だけ待つ部分は、KVM でも縮まない。", ch:4 },
  ]},

  { g: "中から見える違い — アクセラレータで CPU が変わる", terms: [
    { t:"CPU の型", alt:["CPU モデル","-cpu"], id:"cpu-model",
      hint:"QEMU が練習機に見せる CPU の種類（qemu64・host・max など）",
      body:"QEMU が練習機に見せる CPU の名前と機能のひとそろい。<code>-cpu</code> で選び、<code>qemu-system-x86_64 -cpu help</code> で一覧が出る。何も指定しないと <code>qemu64</code>（名前は QEMU Virtual CPU version 2.5+）、<code>host</code> は本物の CPU を KVM が渡せる分だけそのまま、<code>max</code> はその方式で使える機能を全部。<code>-cpu host,-vmx</code> のように、後ろに機能を足したり消したりできる。<b>たとえ</b>: 舞台の<b>配役表</b>。役名と、その役ができること（特技）が書いてある。<b>崩れる点</b>: 配役表どおりに演じるのが舞台だが、KVM では本物の CPU が演じるので、本物に無い特技（Intel の PC で <code>svm</code>）は演じられず、役のほうが削られる。",
      misread:"同じ型なら TCG でも KVM でも同じ CPU が見えると思われがちだが、KVM ではメーカーの名前も機能も本物の CPU に引きずられる（第5章）。", ch:5 },

    { t:"準仮想化", alt:["paravirtualized"], id:"paravirt",
      hint:"ゲストが自分は仮想マシンだと知って、ハイパーバイザーと協力して動くこと",
      body:"ゲストの OS が、自分は仮想マシンの中にいると知ったうえで、ハイパーバイザーの用意した近道（時計の読み方 kvm-clock など）を使って動くこと。Linux は起動のときに CPUID でハイパーバイザーの名前を調べ、知っている名前（KVM など）なら協力する。練習機の <code>dmesg</code> には、KVM では <code>Booting paravirtualized kernel on KVM</code>、TCG では <code>on bare hardware</code>（名前を知らないので、準仮想化を使わずに実機と同じやり方で起動）と出た。<b>たとえ</b>: 管理会社の<b>やり方に合わせた暮らし方</b>。表札の会社を知っていれば、その会社のゴミ出しの決まりに合わせる。<b>崩れる点</b>: 住人は知らない会社でも決まりを聞けば合わせられるが、カーネルは知らない名前（<code>TCGTCGTCGTCG</code>）には協力の方法を持たず、実機と同じに振る舞う。",
      misread:"準仮想化は特別に作った OS でしか使えないと思われがちだが、いまの Linux は名前を知っているハイパーバイザーの上なら自動で使う。", ch:5 },

    { t:"入れ子の仮想化", alt:["nested virtualization","Nested Virtualization"], id:"nested",
      hint:"仮想マシンの中で、さらに仮想マシンを KVM で動かすこと",
      body:"仮想マシンの中で、さらに仮想マシンを動かすこと。KVM で動く仮想マシンの中で KVM を使うには、外の KVM が仮想化支援の印（<code>vmx</code> / <code>svm</code>）を中に渡す必要がある。渡すかどうかは外の設定（<code>/sys/module/kvm_intel/parameters/nested</code> が <code>Y</code>、AMD は <code>/sys/module/kvm_amd/parameters/nested</code> が <code>1</code>）と、QEMU に見せる CPU の型（<code>-cpu host</code> なら渡る、<code>-cpu host,-vmx</code> なら渡らない）で決まる。<b>たとえ</b>: 貸し会議室の中に、さらに<b>貸し会議室を作る</b>こと。オーナーが又貸しを許していれば作れる。<b>崩れる点</b>: 又貸しの許可は書類で確かめられるが、中の仮想マシンは許されているかを尋ねる窓口を持たない。CPU の答えに印があるかだけを見て、KVM を用意する。",
      misread:"中で KVM が使えないのは中の OS の設定のせいだと思われがちだが、外が仮想化支援の印を中に渡しているかどうかで決まる。", ch:5 },

    { t:"libvirt", alt:[], id:"libvirt",
      hint:"仮想マシンの定義（XML）から QEMU のコマンド行を組み立てて動かす管理の道具",
      body:"仮想マシンを定義（XML）で管理し、それに従って QEMU を起動・停止する道具。<code>virsh</code> はその操作のコマンド。このサイトの仮想マシン型の檻は libvirt を使い、定義は <code>&lt;domain type='qemu'&gt;</code>（TCG）。<code>/dev/kvm</code> が使える檻でも、定義が <code>type='qemu'</code> なら QEMU に <code>-accel tcg</code> を渡す。<code>virsh capabilities</code> で、その環境で作れる種類（<code>qemu</code>・<code>kvm</code>）が分かる。<b>たとえ</b>: 工事の<b>発注書</b>を出す係。現場（QEMU）は発注書のとおりに動く。<b>崩れる点</b>: 発注係は現場の様子を見て書き直すこともあるが、libvirt は重機（<code>/dev/kvm</code>）があることを知っていても、定義を勝手に書き換えない。",
      misread:"/dev/kvm を渡せば libvirt の仮想マシンも KVM で動くと思われがちだが、定義の type が qemu なら TCG のままである（第6章）。", ch:6 },
  ]},
];
