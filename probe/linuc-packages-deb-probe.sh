#!/bin/bash
# LinuC 主題1.04 Debian 系の檻: 本文が端末の画面としては載せずに言い切っていることの裏づけ（2026-10-20 の作り直しから）。
# 本文の表・確認問題の答え・たとえの「崩れる点」・演習のヒントと解答に出てくるコマンドを、読者と同じ打ち方で打つ。
# 節（========== 題 ==========）ごとに檻を起動し直す。「ふつうこう考える」で詰まったやり方は、本文の順の記録
# logs/linuc-packages-deb-tty.log の各章にある（本文の画面はそこから写している）。
#   bash probe/linuc-packages-deb-probe.sh（または bash probe/linuc-packages-run.sh probe）
cd "$(dirname "$0")/.." || exit 1
exec python3 -I probe/linuc-packages-seq.py --script /dev/stdin --cage deb \
  --out logs/linuc-packages-deb-probe.log \
  --note "本文が画面を載せずに言い切っていることの裏づけ（節ごとに檻を起動し直した）" <<'INPUT'
========== 第1章の確認問題と演習01 のヒント: sudo を付けずに apt install すると、権限が無いと断られ、何も入らない ==========
$ apt install labhello
$ labhello
$ sudo apt install labhello
$ labhello
========== 第1章: 消したときの man-db の知らせは、外れた説明書の行を索引から消さない（whatis には残り、man は説明書が無いと答える） ==========
$ whatis labhello
$ sudo apt install labhello
$ whatis labhello
$ sudo apt remove labhello
Do you want to continue? [Y/n] y
$ whatis labhello
$ man labhello
$ grep -n -A4 'triggered' /var/lib/dpkg/info/man-db.postinst
========== 第5章: remove で rc が残るのは、purge のときにまだすることがあるもの。設定ファイル（conffile）か、消すときの手順（postrm）を持つもの ==========
$ dpkg -s bc | grep -E '^(Status|Conffiles)'
$ ls /var/lib/dpkg/info/bc.*
$ sudo apt remove bc
Do you want to continue? [Y/n] y
$ dpkg -l bc | tail -1
$ ls /var/lib/dpkg/info/bc.*
$ sudo apt purge bc
Do you want to continue? [Y/n] y
$ dpkg -l bc
========== 第3章: man labhello で説明書が開く（パイプに渡すとページャを使わずに出る） ==========
$ sudo apt install labhello
$ man labhello | head -12
========== 第3章のたとえ: ディレクトリ /usr/bin を dpkg -S に渡すと、そこにファイルを置いたパッケージが何十も並ぶ ==========
$ dpkg -S /usr/bin | cut -c1-76
$ dpkg -S /usr/bin | tr ',' '\n' | wc -l
========== 第4章: dpkg -s は、台帳 /var/lib/dpkg/status の段落をそのまま出す ==========
$ dpkg -s labsvc
$ grep -A12 '^Package: labsvc$' /var/lib/dpkg/status
========== 第4章のたとえ: 権限や持ち主が変わっても、読めるなら dpkg -V は何も言わない。一般ユーザが読めなくなると ? が並ぶ。中身が変わると言う。終了コードはどれも 0 ==========
$ sudo apt install labhello
$ ls -l /usr/bin/labhello
$ sudo chmod 700 /usr/bin/labhello
$ sudo chown lab:lab /usr/bin/labhello
$ ls -l /usr/bin/labhello
$ dpkg -V labhello
$ echo $?
$ sudo chown root:root /usr/bin/labhello
$ sudo chmod 600 /usr/bin/labhello
$ ls -l /usr/bin/labhello
$ dpkg -V labhello
$ echo $?
$ sudo dpkg -V labhello
$ sudo chmod 755 /usr/bin/labhello
$ echo '# 書き足した' | sudo tee -a /usr/bin/labhello
$ dpkg -V labhello
$ echo $?
========== 第5章の確認問題: apt-get の remove・purge・remove --purge・autoremove ==========
$ sudo apt-get remove labsvc
Do you want to continue? [Y/n] y
$ dpkg -l labsvc | tail -1
$ ls -l /etc/labsvc.conf
$ sudo apt-get purge labsvc
Do you want to continue? [Y/n] y
$ dpkg -l labsvc | tail -1
$ ls -l /etc/labsvc.conf
$ sudo apt-get remove --purge labweb
Do you want to continue? [Y/n] y
$ dpkg -l labweb | tail -1
$ ls -l /etc/labweb.conf
$ sudo apt-get autoremove
Do you want to continue? [Y/n] y
$ apt list --installed 'lab*'
========== 第5章の表: apt remove --purge は apt purge と同じ ==========
$ sudo apt remove --purge labweb
Do you want to continue? [Y/n] y
$ dpkg -l labweb | tail -1
$ ls -l /etc/labweb.conf
========== 第5章の範囲外と言ったもの: 印を手で付け替える apt-mark auto / manual ==========
$ apt-mark showauto | grep lab
$ sudo apt-mark auto labweb
$ sudo apt-mark manual labweb-data
$ apt-mark showauto | grep lab
========== 演習05 のヒント: autoremove に名前を渡すと、その名前は remove と同じ消し方になる ==========
$ sudo apt autoremove labweb
Do you want to continue? [Y/n] y
$ dpkg -l labweb | tail -1
$ dpkg -l labweb-data | tail -1
$ ls -l /etc/labweb.conf
$ sudo apt purge labweb
Do you want to continue? [Y/n] y
$ dpkg -l labweb | tail -1
========== 演習05 のヒント: purge --autoremove は purge と autoremove を1回で ==========
$ sudo apt purge --autoremove labweb
Do you want to continue? [Y/n] y
$ dpkg -l labweb | tail -1
$ dpkg -l labweb-data | tail -1
$ ls -l /etc/labweb.conf
========== 第6章: /etc の下へは、一般ユーザの > では書けない。sudo tee なら書け、もう一度書くと中身を置き換える ==========
$ echo 'deb [trusted=yes] file:/srv/lab-repo lab-updates main' > /etc/apt/sources.list.d/lab-updates.list
$ echo 'deb [trusted=yes] file:/srv/lab-repo lab-updates main' | sudo tee /etc/apt/sources.list.d/lab-updates.list
$ echo 'deb [trusted=yes] file:/srv/lab-repo lab-updates main' | sudo tee /etc/apt/sources.list.d/lab-updates.list
$ cat /etc/apt/sources.list.d/lab-updates.list
========== 第6章: …_InRelease は、区分の Release に署名を付けて1つにしたもの ==========
$ head -3 /var/lib/apt/lists/snapshot.ubuntu.com_ubuntu_20260929T000000Z_dists_noble_InRelease
$ grep -n 'BEGIN PGP SIGNATURE' /var/lib/apt/lists/snapshot.ubuntu.com_ubuntu_20260929T000000Z_dists_noble_InRelease
========== 第6章: dists/ の Release は、その区分の目録ファイルの一覧（大きさとダイジェスト） ==========
$ head -14 /srv/lab-repo/dists/lab/Release
========== 第6章: Ubuntu 本体の Contents の大きさ（目録の写しの InRelease に、ファイルごとの大きさが書いてある。合わせて約 195MB） ==========
$ cd /var/lib/apt/lists
$ awk '$3=="Contents-amd64.gz"{print FILENAME, $2}' *_InRelease | sort -u
========== 第6章の表: apt-get update・apt-get upgrade・apt full-upgrade・apt-get dist-upgrade・apt-get install ==========
$ sudo apt-get install labhello
$ echo 'deb [trusted=yes] file:/srv/lab-repo lab-updates main' | sudo tee /etc/apt/sources.list.d/lab-updates.list
$ sudo apt-get update
$ apt list --upgradable
$ sudo apt-get upgrade
Do you want to continue? [Y/n] y
$ labhello
$ sudo apt full-upgrade
$ sudo apt-get dist-upgrade
========== 第6章の表: apt install は、入っていて新しい版があれば上げる ==========
$ sudo apt install labhello
$ echo 'deb [trusted=yes] file:/srv/lab-repo lab-updates main' | sudo tee /etc/apt/sources.list.d/lab-updates.list
$ sudo apt update
$ sudo apt install labhello
$ labhello
========== 第7章: apt-get -f install（apt --fix-broken install と同じ） ==========
$ apt download labapp
$ sudo dpkg -i labapp_1.0_all.deb
$ sudo apt-get -f install
Do you want to continue? [Y/n] y
$ dpkg -l labapp liblab | tail -2
========== 第7章: 止まっているものをまとめて設定する dpkg --configure -a ==========
$ apt download labhello
$ sudo dpkg --unpack labhello_1.0_all.deb
$ dpkg -l labhello | tail -1
$ sudo dpkg --configure -a
$ dpkg -l labhello | tail -1
========== 第7章: debconf-show の行の順番は打つたびに変わる ==========
$ sudo debconf-show tzdata | head -3
$ sudo debconf-show tzdata | head -3
$ sudo debconf-show tzdata | head -3
========== 第7章: dpkg-reconfigure をそのまま打つと、矢印キーで選ぶ画面が出る（Enter で今の答えのまま進める） ==========
$ sudo dpkg-reconfigure tzdata
（画面を写す）
（打鍵: <Enter> <Enter>）
========== 第10章の表: apt-get clean（取ってきた .deb を捨てる）と apt-get distclean（目録の写しを捨てる） ==========
$ sudo apt-get install --download-only labhello
$ ls /var/cache/apt/archives/
$ sudo apt-get clean
$ ls /var/cache/apt/archives/
$ ls /var/lib/apt/lists/
$ sudo apt-get distclean
$ ls /var/lib/apt/lists/
========== 第6章の表: apt-cache search と apt-get download（apt search・apt download と同じ働き） ==========
$ apt-cache search labhello
$ apt-get download labhello
$ ls
========== 演習02・04・05 のヒントと解答: 問いに答えて消す・入れ直す ==========
$ sudo apt remove labfortune
Do you want to continue? [Y/n] y
$ apt list --installed 'lab*'
$ sudo apt reinstall labbackup
$ labbackup
$ sudo apt remove labweb
Do you want to continue? [Y/n] y
$ dpkg -l labweb | tail -1
========== 演習08 の解答: 中身の木と DEBIAN/control を並べて作り、apt install ./ で入れる（第8章の N: の知らせは、_apt が /home/lab に入れないから） ==========
$ lab start 08
$ cd ~/work/08
$ mkdir -p labmine/usr/bin labmine/DEBIAN
$ cp labmine.sh labmine/usr/bin/labmine
$ chmod 755 labmine/usr/bin/labmine
$ cat > labmine/DEBIAN/control <<'END'
> Package: labmine
> Version: 1.0
> Architecture: all
> Maintainer: lab <lab@example.invalid>
> Depends: liblab
> Description: my script packaged by hand
> END
$ dpkg-deb --build --root-owner-group labmine .
$ dpkg -I labmine_1.0_all.deb
$ dpkg -c labmine_1.0_all.deb
$ sudo apt install ./labmine_1.0_all.deb
Do you want to continue? [Y/n] y
$ labmine
$ ls -ld /home/lab
$ id _apt
========== 演習08 の判定: liblab を先に名前を指定して入れると「自動で入った」印が付かず、通らない。liblab ごと消して入れ直すと通る ==========
$ lab start 08
$ cd ~/work/08
$ mkdir -p labmine/usr/bin labmine/DEBIAN
$ cp labmine.sh labmine/usr/bin/labmine
$ chmod 755 labmine/usr/bin/labmine
$ cat > labmine/DEBIAN/control <<'END'
> Package: labmine
> Version: 1.0
> Architecture: all
> Maintainer: lab <lab@example.invalid>
> Depends: liblab
> Description: my script packaged by hand
> END
$ dpkg-deb --build --root-owner-group labmine .
$ sudo apt install liblab
$ sudo apt install ./labmine_1.0_all.deb
$ lab check 08
$ sudo apt remove liblab
Do you want to continue? [Y/n] y
$ sudo apt install ./labmine_1.0_all.deb
Do you want to continue? [Y/n] y
$ lab check 08
========== 演習02〜04・06〜08 のヒントと解答に出てくる調べ方 ==========
$ dpkg -s labbackup | grep Section
$ dpkg -s labsvc | grep Section
$ dpkg -s labsvc-common | grep Section
$ dpkg -S /usr/bin/labsvc
$ dpkg -L labbackup
$ sudo apt install --reinstall labbackup
$ dpkg -V labbackup
$ echo 'deb [trusted=yes] file:/srv/lab-tools tools main' | sudo tee /etc/apt/sources.list.d/lab-tools.list
$ sudo apt update
$ apt search labcalc
$ apt-file search labcalc
$ apt-file list lab-mathtools
$ sudo apt install lab-mathtools
$ dpkg -S /usr/bin/labcalc
$ dpkg -L lab-mathtools
========== 演習06 のヒント: [trusted=yes] を付けずに足すと、署名の無いリポジトリとして apt update が断る ==========
$ echo 'deb file:/srv/lab-tools tools main' | sudo tee /etc/apt/sources.list.d/lab-tools.list
$ sudo apt update
$ apt-cache policy lab-mathtools
========== 演習07: dpkg -i で iU になった labnote は動かず、ほかの操作も止める。apt -f install で直す ==========
$ lab start 07
$ cd ~/work/07
$ sudo dpkg -i labnote_1.0_all.deb
$ dpkg -l labnote | tail -1
$ labnote
$ sudo apt install labhello
$ sudo apt -f install
Do you want to continue? [Y/n] y
$ dpkg -l labnote labnote-data | tail -2
$ labnote
========== 演習07 の別解: apt install ./labnote_1.0_all.deb（./ を付けないと、名前として探して見つからない） ==========
$ lab start 07
$ cd ~/work/07
$ sudo apt install labnote_1.0_all.deb
$ sudo apt install ./labnote_1.0_all.deb
Do you want to continue? [Y/n] y
$ dpkg -l labnote labnote-data | tail -2
========== 演習07 の解答: 依存が満たされている iU（dpkg --unpack で展開だけ）は、apt が次の操作のついでに設定する ==========
$ apt download labhello
$ sudo dpkg --unpack labhello_1.0_all.deb
$ dpkg -l labhello | tail -1
$ sudo apt install liblab
$ dpkg -l labhello | tail -1
INPUT
