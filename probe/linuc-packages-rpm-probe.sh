#!/bin/bash
# LinuC 主題1.04 RPM 系の檻: 本文が端末の画面としては載せずに言い切っていることの裏づけ（2026-10-20 の作り直しから）。
# 本文の表・確認問題の答え・演習のヒントと解答に出てくるコマンドを、読者と同じ打ち方で打つ。
# 節（========== 題 ==========）ごとに檻を起動し直す。「ふつうこう考える」で詰まったやり方は、本文の順の記録
# logs/linuc-packages-rpm-tty.log の各章にある（本文の画面はそこから写している）。
#   bash probe/linuc-packages-rpm-probe.sh（または bash probe/linuc-packages-run.sh probe）
cd "$(dirname "$0")/.." || exit 1
exec python3 -I probe/linuc-packages-seq.py --script /dev/stdin --cage rpm \
  --out logs/linuc-packages-rpm-probe.log \
  --note "本文が画面を載せずに言い切っていることの裏づけ（節ごとに檻を起動し直した）" <<'INPUT'
========== 第9章: Running scriptlet は labhello の手順ではない（labhello は手順を持たない）。man-db が説明書の置き場に登録した手順で、この檻では索引を作り直さない ==========
$ rpm -qp --scripts /srv/lab-rpm/labhello-1.0-1.noarch.rpm
$ rpm -q --filetriggers man-db
$ sudo yum install labhello
Is this ok [y/N]: y
$ whatis labhello
========== 第9章: labapp を入れたときの Running scriptlet は、liblab が /usr/lib に置いたファイルに反応した、別のパッケージ（glibc-common）の手順 ==========
$ rpm -qp --scripts /srv/lab-rpm/labapp-1.0-1.noarch.rpm /srv/lab-rpm/liblab-1.0-1.noarch.rpm
$ rpm -qpl /srv/lab-rpm/liblab-1.0-1.noarch.rpm
$ rpm -q --filetriggers glibc-common
========== 第9章: rpm -qR の /usr/bin/sh と config(labapp) は、作るときに rpm が自動で足したもの（labapp はシェルのスクリプトで、設定ファイルを持つ） ==========
$ sudo yum install labapp
Is this ok [y/N]: y
$ head -1 /usr/bin/labapp
$ rpm -q --qf '[%{REQUIRENAME}  %{REQUIREFLAGS:deptype}\n]' labapp
$ rpm -q --provides labapp
========== 第9章: /etc/dnf/protected.d/sudo.conf は、yum に sudo を消させない設定 ==========
$ cat /etc/dnf/protected.d/sudo.conf
$ sudo yum remove sudo
========== 第10章の表: yum の baseurl は file:/srv/… の形も読める（file:///srv/… と同じ場所） ==========
$ printf '%s\n' '[lab-tools]' 'name=lab tools' 'baseurl=file:/srv/lab-tools-rpm' 'gpgcheck=0' | sudo tee /etc/yum.repos.d/lab-tools.repo
$ yum --disablerepo='*' --enablerepo=lab-tools list available
========== 第10章の表: 練習用のパッケージ（署名は見出しだけ）の中身を1バイト書き換えると DIGESTS signatures NOT OK ==========
$ rpm -Kv /srv/lab-rpm/labhello-1.0-1.noarch.rpm
$ ls -l /srv/lab-rpm/labhello-1.0-1.noarch.rpm
$ cp /srv/lab-rpm/labhello-1.0-1.noarch.rpm ~/hello-copy.rpm
$ printf 'A' | dd of=$HOME/hello-copy.rpm bs=1 seek=7526 conv=notrunc status=none
$ rpm -K ~/hello-copy.rpm; echo $?
$ rpm -Kv ~/hello-copy.rpm
$ echo $HOME
========== 第10章: yum provides の名前のあとの 32: はエポック ==========
$ yum info bind-utils | grep -E '^(Name|Epoch|Version|Release)' | head -4
========== 第10章: 更新できるものが無ければ、check-update の終了コードは 0 ==========
$ yum check-update
$ echo $?
========== 第10章: 目録が取れないと、check-update の終了コードは 1 ==========
$ printf '%s\n' '[broken]' 'name=broken' 'baseurl=file:///nonexistent' 'gpgcheck=0' | sudo tee /etc/yum.repos.d/broken.repo
$ yum check-update
$ echo $?
========== 第10章: 足したばかりのリポジトリの目録を取った直後は、Last metadata expiration check の行が出ないこともある（1回目） ==========
$ sudo yum install labhello
Is this ok [y/N]: y
$ printf '%s\n' '[lab-updates]' 'name=lab updates (LinuC 1.04)' 'baseurl=file:///srv/lab-updates-rpm' 'gpgcheck=1' 'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-lab-updates' | sudo tee /etc/yum.repos.d/lab-updates.repo
$ yum check-update
$ echo $?
========== 第10章: 同じ（2回目） ==========
$ sudo yum install labhello
Is this ok [y/N]: y
$ printf '%s\n' '[lab-updates]' 'name=lab updates (LinuC 1.04)' 'baseurl=file:///srv/lab-updates-rpm' 'gpgcheck=1' 'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-lab-updates' | sudo tee /etc/yum.repos.d/lab-updates.repo
$ yum check-update
$ echo $?
========== 第10章: 同じ（3回目） ==========
$ sudo yum install labhello
Is this ok [y/N]: y
$ printf '%s\n' '[lab-updates]' 'name=lab updates (LinuC 1.04)' 'baseurl=file:///srv/lab-updates-rpm' 'gpgcheck=1' 'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-lab-updates' | sudo tee /etc/yum.repos.d/lab-updates.repo
$ yum check-update
$ echo $?
========== 第10章のたとえ: 署名の無いパッケージを断るのは yum の規則（rpm -K は失敗にしない）。手元の .rpm は既定では確かめない（localpkg_gpgcheck）が、確かめさせると断る ==========
$ grep -E 'gpgcheck|localpkg' /etc/dnf/dnf.conf
$ rpm -K /srv/lab-files/labnosig-1.0-1.noarch.rpm
$ sudo yum install --setopt=localpkg_gpgcheck=1 /srv/lab-files/labnosig-1.0-1.noarch.rpm
Is this ok [y/N]: y
$ sudo yum install /srv/lab-files/labnosig-1.0-1.noarch.rpm
Is this ok [y/N]: y
$ rpm -q labnosig
========== 第10章: 同じ（4回目） ==========
$ sudo yum install labhello
Is this ok [y/N]: y
$ printf '%s\n' '[lab-updates]' 'name=lab updates (LinuC 1.04)' 'baseurl=file:///srv/lab-updates-rpm' 'gpgcheck=1' 'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-lab-updates' | sudo tee /etc/yum.repos.d/lab-updates.repo
$ yum check-update
$ echo $?
========== 第10章: 同じ（5回目） ==========
$ sudo yum install labhello
Is this ok [y/N]: y
$ printf '%s\n' '[lab-updates]' 'name=lab updates (LinuC 1.04)' 'baseurl=file:///srv/lab-updates-rpm' 'gpgcheck=1' 'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-lab-updates' | sudo tee /etc/yum.repos.d/lab-updates.repo
$ yum check-update
$ echo $?
========== 第10章: 同じ（6回目） ==========
$ sudo yum install labhello
Is this ok [y/N]: y
$ printf '%s\n' '[lab-updates]' 'name=lab updates (LinuC 1.04)' 'baseurl=file:///srv/lab-updates-rpm' 'gpgcheck=1' 'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-lab-updates' | sudo tee /etc/yum.repos.d/lab-updates.repo
$ yum check-update
$ echo $?
========== 第10章の表: makecache は全部のリポジトリに取りに行って確かめる。clean all は手元の写しを捨て、次の yum が AlmaLinux 本体の目録（合わせて約 53MB）を取り直す ==========
$ sudo yum makecache
$ sudo yum clean all
$ ls /var/cache/dnf/
$ yum search liblab
========== 第10章の確認問題: whatprovides は provides と同じ。repoquery は yum を付けずにも打てる ==========
$ yum whatprovides '*/liblab.sh'
$ repoquery -l labtool
========== 第11章（と理論編の目次の「実務」）: yum install ./ファイル なら、足りない依存は目録から取る ==========
$ yumdownloader labtool
$ sudo yum install ./labtool-1.0-1.noarch.rpm
Is this ok [y/N]: y
$ yum list installed labtool labtool-data
========== 第11章の確認問題: 入れずに一覧だけ見る rpm2cpio | cpio -t と rpm -qpl ==========
$ yumdownloader labtool
$ rpm2cpio labtool-1.0-1.noarch.rpm | cpio -t
$ rpm -qpl labtool-1.0-1.noarch.rpm
========== 第11章: rpm -Va の行の中身（一般ユーザで31行。読めずに確かめられなかった ? と Permission denied の10行、設定ファイルの c、コンテナで省かれた missing、目録の写しの置き場の付け替え、演習11 の labmotd）。sudo を付けると21行 ==========
$ rpm -Va
$ rpm -Va | wc -l
$ sudo rpm -Va | wc -l
$ ls -l /var/cache/dnf
========== 第11章の表: -U に、入っているのと同じ版や古い版を渡すと is already installed と断る（終了コード 2）。-F は何もしない ==========
$ yumdownloader labhello
$ cp /srv/lab-updates-rpm/labhello-1.1-1.noarch.rpm .
$ sudo rpm -ivh labhello-1.0-1.noarch.rpm
$ sudo rpm -Uvh labhello-1.0-1.noarch.rpm
$ echo $?
$ sudo rpm -Uvh labhello-1.1-1.noarch.rpm
$ sudo rpm -Uvh labhello-1.0-1.noarch.rpm
$ echo $?
$ sudo rpm -Fvh labhello-1.0-1.noarch.rpm
$ echo $?
========== 演習11 のヒント: which は実行できないファイルを探さないので、いまの labmotd は見つからない。台帳にはパスをそのまま渡す ==========
$ labmotd
$ which labmotd
$ rpm -qf /usr/bin/labmotd
========== 演習11 の解答: --setperms は権限だけを戻し、--replacepkgs で入れ直すと全部戻る ==========
$ rpm -V labmotd; echo $?
$ sudo rpm --setperms labmotd
$ rpm -V labmotd; echo $?
$ sudo rpm -Uvh --replacepkgs /srv/lab-rpm/labmotd-1.0-1.noarch.rpm
$ rpm -V labmotd; echo $?
========== 演習11 の解答: yum reinstall でも戻る ==========
$ sudo yum reinstall labmotd
Is this ok [y/N]: y
$ rpm -V labmotd; echo $?
$ labmotd
========== 第10章: yum upgrade（yum update と同じもの。上げるものが無ければ何もしない） ==========
$ sudo yum upgrade
========== 第10章で範囲外とした yum のモジュール（dnf module） ==========
$ yum module list | head -6
========== 演習09 のヒントと解答: rpm -ql・rpm -qc と yum list installed ==========
$ sudo yum install labapp
Is this ok [y/N]: y
$ rpm -ql labapp
$ rpm -qc labapp
$ yum list installed labapp liblab
========== 演習10 の解答: lab-tools を足し（第10章と同じヒアドキュメント）、鍵を取り込む問いに答えて入れる ==========
$ sudo tee /etc/yum.repos.d/lab-tools.repo <<'END'
> [lab-tools]
> name=lab tools
> baseurl=file:///srv/lab-tools-rpm
> gpgcheck=1
> gpgkey=file:///srv/lab-tools-rpm/RPM-GPG-KEY-lab-tools
> END
$ yum repolist
$ yum provides '*/labcalc'
$ sudo yum install lab-mathtools
Is this ok [y/N]: y
Is this ok [y/N]: y
$ labcalc 2 3
$ yum list installed lab-mathtools
$ rpm -q gpg-pubkey --qf '%{SUMMARY}\n'
========== 演習10 の別解: printf で行を並べて tee に渡しても、同じ .repo ファイルになる ==========
$ printf '%s\n' '[lab-tools]' 'name=lab tools' 'baseurl=file:///srv/lab-tools-rpm' \
> 'gpgcheck=1' 'gpgkey=file:///srv/lab-tools-rpm/RPM-GPG-KEY-lab-tools' \
> | sudo tee /etc/yum.repos.d/lab-tools.repo
$ cat /etc/yum.repos.d/lab-tools.repo
========== 演習10 の判定と解答: gpgcheck=0 で入れたあとに鍵だけ取り込んでも通らない。gpgcheck=1 に直し、消して入れ直すと通る ==========
$ printf '%s\n' '[lab-tools]' 'name=lab tools' 'baseurl=file:///srv/lab-tools-rpm' 'gpgcheck=0' | sudo tee /etc/yum.repos.d/lab-tools.repo
$ sudo yum install lab-mathtools
Is this ok [y/N]: y
$ lab check 10
$ sudo rpm --import /srv/lab-tools-rpm/RPM-GPG-KEY-lab-tools
$ lab check 10
$ sudo tee /etc/yum.repos.d/lab-tools.repo <<'END'
> [lab-tools]
> name=lab tools
> baseurl=file:///srv/lab-tools-rpm
> gpgcheck=1
> gpgkey=file:///srv/lab-tools-rpm/RPM-GPG-KEY-lab-tools
> END
$ lab check 10
$ sudo yum remove lab-mathtools
Is this ok [y/N]: y
$ sudo yum install lab-mathtools
Is this ok [y/N]: y
$ lab check 10
========== 演習10 の解答: gpgcheck=0 で入れたものを、gpgcheck=1 に直して消して入れ直すと、入れるときに鍵を取り込んでよいかを尋ねられる ==========
$ printf '%s\n' '[lab-tools]' 'name=lab tools' 'baseurl=file:///srv/lab-tools-rpm' 'gpgcheck=0' | sudo tee /etc/yum.repos.d/lab-tools.repo
$ sudo yum install lab-mathtools
Is this ok [y/N]: y
$ sudo tee /etc/yum.repos.d/lab-tools.repo <<'END'
> [lab-tools]
> name=lab tools
> baseurl=file:///srv/lab-tools-rpm
> gpgcheck=1
> gpgkey=file:///srv/lab-tools-rpm/RPM-GPG-KEY-lab-tools
> END
$ sudo yum remove lab-mathtools
Is this ok [y/N]: y
$ sudo yum install lab-mathtools
Is this ok [y/N]: y
Is this ok [y/N]: y
$ lab check 10
========== 演習10 の解答の別解: 消さずに yum reinstall で入れ直しても、鍵を取り込んでよいかを尋ねられて通る ==========
$ printf '%s\n' '[lab-tools]' 'name=lab tools' 'baseurl=file:///srv/lab-tools-rpm' 'gpgcheck=0' | sudo tee /etc/yum.repos.d/lab-tools.repo
$ sudo yum install lab-mathtools
Is this ok [y/N]: y
$ sudo tee /etc/yum.repos.d/lab-tools.repo <<'END'
> [lab-tools]
> name=lab tools
> baseurl=file:///srv/lab-tools-rpm
> gpgcheck=1
> gpgkey=file:///srv/lab-tools-rpm/RPM-GPG-KEY-lab-tools
> END
$ sudo yum reinstall lab-mathtools
Is this ok [y/N]: y
Is this ok [y/N]: y
$ lab check 10
========== 演習10 の解答: 鍵を先に取り込んだ檻（第10章を打ったまま）では、gpgcheck=0 で入れてから 1 に戻すと、判定は見分けられない（課題文で起動し直してと書く理由） ==========
$ sudo rpm --import /srv/lab-tools-rpm/RPM-GPG-KEY-lab-tools
$ printf '%s\n' '[lab-tools]' 'name=lab tools' 'baseurl=file:///srv/lab-tools-rpm' 'gpgcheck=0' | sudo tee /etc/yum.repos.d/lab-tools.repo
$ sudo yum install lab-mathtools
Is this ok [y/N]: y
$ sudo tee /etc/yum.repos.d/lab-tools.repo <<'END'
> [lab-tools]
> name=lab tools
> baseurl=file:///srv/lab-tools-rpm
> gpgcheck=1
> gpgkey=file:///srv/lab-tools-rpm/RPM-GPG-KEY-lab-tools
> END
$ lab check 10
========== 演習10 の課題文: 第10章を打った檻のままでも始まりの画面は同じだが、lab tools の鍵が台帳に残っているので、入れるときに鍵を取り込む問いが出ない ==========
$ sudo yum install labhello
Is this ok [y/N]: y
$ sudo tee /etc/yum.repos.d/lab-updates.repo <<'END'
> [lab-updates]
> name=lab updates (LinuC 1.04)
> baseurl=file:///srv/lab-updates-rpm
> gpgcheck=1
> gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-lab-updates
> END
$ sudo yum update labhello
Is this ok [y/N]: y
Is this ok [y/N]: y
$ sudo rpm --import /srv/lab-tools-rpm/RPM-GPG-KEY-lab-tools
$ lab start 10
$ labcalc 2 3
$ ls /srv/lab-tools-rpm
$ rpm -q gpg-pubkey --qf '%{SUMMARY}\n'
$ sudo tee /etc/yum.repos.d/lab-tools.repo <<'END'
> [lab-tools]
> name=lab tools
> baseurl=file:///srv/lab-tools-rpm
> gpgcheck=1
> gpgkey=file:///srv/lab-tools-rpm/RPM-GPG-KEY-lab-tools
> END
$ sudo yum install lab-mathtools
Is this ok [y/N]: y
$ lab check 10
========== 演習10 の解答: 台帳に取り込んだ鍵の一覧 ==========
$ rpm -q gpg-pubkey --qf '%{SUMMARY}\n'
========== 演習12 の判定: 何もしなければ ✗ ==========
$ lab check 12
========== 演習12 の判定: yum だけで入れると ✗（yum がリポジトリ lab から入れた） ==========
$ sudo yum install labtool
Is this ok [y/N]: y
$ lab check 12
========== 演習12 の判定: yum に手元のファイルを渡して入れると ✗（yum が手元のファイルから入れた。yum list installed の右端は @@commandline） ==========
$ lab start 12
$ cd ~/work/12
$ yumdownloader --resolve labtool
$ sudo yum install ./labtool-1.0-1.noarch.rpm ./labtool-data-1.0-1.noarch.rpm
Is this ok [y/N]: y
$ yum list installed labtool labtool-data
$ lab check 12
========== 演習12 の判定: rpm で入れたあと yum reinstall すると ✗（いまの labtool は yum が入れたもの） ==========
$ lab start 12
$ cd ~/work/12
$ yumdownloader --resolve labtool
$ sudo rpm -ivh labtool-1.0-1.noarch.rpm labtool-data-1.0-1.noarch.rpm
$ sudo yum reinstall labtool
Is this ok [y/N]: y
$ lab check 12
========== 演習12 の判定: yum で入れて yum で消したあと、rpm で入れると ✔（右端は @@System のまま） ==========
$ sudo yum install labtool
Is this ok [y/N]: y
$ sudo yum remove labtool labtool-data
Is this ok [y/N]: y
$ lab start 12
$ cd ~/work/12
$ yumdownloader --resolve labtool
$ sudo rpm -ivh labtool-1.0-1.noarch.rpm labtool-data-1.0-1.noarch.rpm
$ yum list installed labtool labtool-data
$ lab check 12
========== 演習12 の判定: rpm で入れて yum で消し、もう一度 rpm で入れると ✔（右端は @@System のまま） ==========
$ lab start 12
$ cd ~/work/12
$ yumdownloader --resolve labtool
$ sudo rpm -ivh labtool-1.0-1.noarch.rpm labtool-data-1.0-1.noarch.rpm
$ sudo yum remove labtool labtool-data
Is this ok [y/N]: y
$ sudo rpm -ivh labtool-1.0-1.noarch.rpm labtool-data-1.0-1.noarch.rpm
$ yum list installed labtool labtool-data
$ lab check 12
========== 演習12 の判定: yum に手元のファイルを渡して入れ、rpm -e で消してから rpm で入れると ✔（右端は @@commandline のまま） ==========
$ lab start 12
$ cd ~/work/12
$ yumdownloader --resolve labtool
$ sudo yum install ./labtool-1.0-1.noarch.rpm ./labtool-data-1.0-1.noarch.rpm
Is this ok [y/N]: y
$ yum list installed labtool labtool-data
$ sudo rpm -e labtool labtool-data
$ sudo rpm -ivh labtool-1.0-1.noarch.rpm labtool-data-1.0-1.noarch.rpm
$ yum list installed labtool labtool-data
$ lab check 12
========== 演習12 の判定: yum で入れて rpm -e で消し、rpm で入れると ✔（右端は @lab のまま） ==========
$ sudo yum install labtool
Is this ok [y/N]: y
$ yum list installed labtool labtool-data
$ sudo rpm -e labtool labtool-data
$ lab start 12
$ cd ~/work/12
$ yumdownloader --resolve labtool
$ sudo rpm -ivh labtool-1.0-1.noarch.rpm labtool-data-1.0-1.noarch.rpm
$ yum list installed labtool labtool-data
$ lab check 12
========== 演習12 の判定: 第11章を打った檻（rpm で入れて消し、labapp を yum で入れ直した）のままでも、rpm で入れれば ✔ ==========
$ yumdownloader --resolve labtool
$ sudo rpm -ivh labtool-1.0-1.noarch.rpm labtool-data-1.0-1.noarch.rpm
$ sudo rpm -e labtool labtool-data
$ sudo yum install labapp
Is this ok [y/N]: y
$ sudo rpm -e --nodeps liblab
$ sudo yum reinstall labapp
Is this ok [y/N]: y
$ lab start 12
$ cd ~/work/12
$ yumdownloader --resolve labtool
$ sudo rpm -ivh labtool-1.0-1.noarch.rpm labtool-data-1.0-1.noarch.rpm
$ yum list installed labtool labtool-data
$ lab check 12
========== 演習09 の判定: 台帳のファイルが消えていると「消えている」と出る（設定ファイルにもそう添える） ==========
$ sudo yum install labapp
Is this ok [y/N]: y
$ sudo rm /usr/bin/labapp /etc/labapp.conf
$ lab check 09
========== 演習12 の解答: yumdownloader の --destdir と --resolve ==========
$ yumdownloader --destdir /tmp/dl labtool
$ ls /tmp/dl
$ yumdownloader --resolve labtool
$ ls
INPUT
