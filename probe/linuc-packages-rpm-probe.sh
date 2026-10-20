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
========== 第10章の表: makecache は全部のリポジトリに取りに行って確かめる。clean all は手元の写しを捨てる ==========
$ sudo yum makecache
$ sudo yum clean all
$ ls /var/cache/dnf/
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
========== 第11章: rpm -Va の行の中身（設定ファイルの c と、コンテナで省かれたもの。31 行） ==========
$ rpm -Va
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
========== 演習10 の解答: lab-tools を足し、鍵を取り込む問いに答えて入れる ==========
$ printf '%s\n' '[lab-tools]' 'name=lab tools' 'baseurl=file:///srv/lab-tools-rpm' \
> 'gpgcheck=1' 'gpgkey=file:///srv/lab-tools-rpm/RPM-GPG-KEY-lab-tools' \
> | sudo tee /etc/yum.repos.d/lab-tools.repo
$ yum repolist
$ yum provides '*/labcalc'
$ sudo yum install lab-mathtools
Is this ok [y/N]: y
Is this ok [y/N]: y
$ labcalc 2 3
$ yum list installed lab-mathtools
$ rpm -q gpg-pubkey --qf '%{SUMMARY}\n'
========== 演習10 の解答: 台帳に取り込んだ鍵の一覧 ==========
$ rpm -q gpg-pubkey --qf '%{SUMMARY}\n'
========== 演習12 の解答: yumdownloader の --destdir と --resolve ==========
$ yumdownloader --destdir /tmp/dl labtool
$ ls /tmp/dl
$ yumdownloader --resolve labtool
$ ls
INPUT
