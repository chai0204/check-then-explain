#!/bin/bash
# LinuC 主題1.04（リポジトリとパッケージ管理）RPM 系の檻で、本文に載せる全コマンドを実際に通す。
# ここに出ない出力は本文に書かない（憲章 §3）。
#
# 章ごとに「檻を起動し直した直後」から打つ（Debian 系と同じ理由。driver: probe/linuc-packages-run.sh）。
#   bash /tmp/probe.sh env|ch1|ch5|ch6|ch7
set -u
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
S() { printf '\n\n========== %s ==========\n' "$*"; }

RPM_APP=/srv/lab-rpm/labapp-1.0-1.noarch.rpm
RPM_LIB=/srv/lab-rpm/liblab-1.0-1.noarch.rpm

sec_env() {
  S "0. 環境（RPM 系の檻・起動直後）"
  R lab env
  R 'id'
  R 'hostname'
  R 'head -2 /etc/os-release'
  R lab
  R 'lab ls'
}

sec_ch1() {
  S "ch1. パッケージは中身と、台帳への届け出でできている（RPM 系）"
  R 'ls -l /srv/lab-rpm/'
  R "file $RPM_APP"
  R "rpm -qpi $RPM_APP"
  R "rpm -qpl $RPM_APP"
  R "rpm -qpR $RPM_APP"
  echo; echo "---- 中身だけ置く ----"
  R "cd / && rpm2cpio $RPM_LIB | sudo cpio -idmv"
  R 'cd'
  R 'ls -l /usr/lib/liblab/liblab.sh'
  R 'rpm -q liblab; echo "exit=$?"'
  R 'rpm -qf /usr/lib/liblab/liblab.sh; echo "exit=$?"'
  echo; echo "---- rpm で入れる ----"
  R "sudo rpm -ivh $RPM_LIB"
  R 'rpm -q liblab'
  R 'rpm -qf /usr/lib/liblab/liblab.sh'
  R 'ls /var/lib/rpm/'
  R 'rpm -qa | wc -l'
  echo; echo "---- リポジトリ = 中身と目録（repodata） ----"
  R 'find /srv/lab-rpm -type f | sort'
  R 'yum list labapp'
}

sec_ch5() {
  S "ch5. yum（実体は dnf）は、目録を自分で取りに行く"
  R 'ls -l /usr/bin/yum /usr/bin/dnf'
  R 'ls -l /etc/yum.conf'
  R 'cat /etc/yum.conf'
  R 'rpm -qf /etc/yum.conf /etc/dnf/dnf.conf /usr/bin/yum'
  R 'yum --version | head -1'
  R 'ls -1 /etc/yum.repos.d/'
  R 'cat /etc/yum.repos.d/lab.repo'
  R "grep -A10 '^\\[baseos\\]' /etc/yum.repos.d/almalinux-baseos.repo"
  R 'yum repolist'
  R 'yum repolist all'
  echo; echo "---- 目録を引く ----"
  R "yum list installed 'lab*'"
  R "yum list available 'lab*'"
  R 'yum list labhello'
  R 'yum info labapp'
  R 'yum search liblab'
  R 'yum provides /usr/bin/labapp'
  R "yum provides '*/liblab.sh'"
  R 'rpm -qf /usr/bin/dig; echo "exit=$?"'
  R 'yum provides /usr/bin/dig'
  R 'yum deplist labapp'
  echo; echo "---- 入れる・消す ----"
  R 'sudo yum install -y labapp'
  R 'rpm -q labapp liblab'
  R 'yum list installed labapp liblab'
  R 'sudo yum remove -y labapp'
  R 'rpm -q labapp liblab; echo "exit=$?"'
  R 'grep clean_requirements_on_remove /etc/yum.conf'
  echo; echo "---- リポジトリを足す（ふつうこう考える） ----"
  R 'find /srv/lab-extra-rpm -type f | sort'
  R 'yum list labextra; echo "exit=$?"'
  R "printf '%s\\n' '[lab-extra]' 'name=lab extra (LinuC 1.04)' 'baseurl=file:///srv/lab-extra-rpm' 'gpgcheck=1' 'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-lab' | sudo tee /etc/yum.repos.d/lab-extra.repo"
  R 'sudo yum install -y labextra'
  R 'labextra'
  R 'yum repolist'
  echo; echo "---- 更新 ----"
  R 'yum check-update; echo "exit=$?"'
  R 'sudo yum update -y labhello'
  R 'labhello'
  R 'yum check-update; echo "exit=$?"'
  echo; echo "---- yumdownloader ----"
  R 'ls -l /usr/bin/yumdownloader'
  R 'cd ~/work'
  R 'yumdownloader labtool'
  R 'ls -l'
  R 'rpm -q labtool; echo "exit=$?"'
  R 'rpm -qpl labtool-1.0-1.noarch.rpm'
  R 'rpm -qpR labtool-1.0-1.noarch.rpm'
  R 'yumdownloader --resolve --destdir dl labtool'
  R 'ls -l dl/'
  R 'cd'
  echo; echo "---- 目録の置き場所 ----"
  R 'ls -ld /var/cache/dnf'
  R 'ls /var/cache/dnf/'
}

sec_ch6() {
  S "ch6. rpm は台帳を引き、台帳と照らし合わせる"
  R 'rpm -qa | wc -l'
  R "rpm -qa 'lab*'"
  R 'rpm -q labhello'
  R 'rpm -q labapp; echo "exit=$?"'
  R 'rpm -qi labhello'
  R 'rpm -ql labhello'
  R 'rpm -qf /usr/bin/labhello'
  R 'sudo yum install -y labapp'
  R 'rpm -ql labapp'
  R 'rpm -qc labapp'
  R 'rpm -qd labapp'
  R 'rpm -qR labapp'
  R 'rpm -q --provides liblab'
  R 'rpm -q --whatrequires liblab'
  R 'rpm -ql labtool; echo "exit=$?"'
  R 'rpm -qpl /srv/lab-rpm/labtool-1.0-1.noarch.rpm'
  R 'rpm -qpi /srv/lab-rpm/labtool-1.0-1.noarch.rpm | head -4'
  echo; echo "---- 照らし合わせる（ふつうこう考える） ----"
  R 'rpm -V labhello'
  R 'rpm -V labhello; echo "exit=$?"'
  R 'rpm -V nosuchpkg; echo "exit=$?"'
  R "echo 'greeting=\"こんにちは\"' | sudo tee -a /etc/labapp.conf"
  R 'labapp'
  R 'sudo chmod 0644 /usr/bin/labhello'
  R 'labhello; echo "exit=$?"'
  R 'rpm -V labapp labhello; echo "exit=$?"'
  R 'sudo yum reinstall -y labhello'
  R 'rpm -V labhello; echo "exit=$?"'
  R 'labhello'
  R 'sudo yum reinstall -y labapp'
  R 'rpm -V labapp; echo "exit=$?"'
  R 'ls -l /etc/labapp.conf*'
  R 'sudo rpm -e labapp'
  R 'ls -l /etc/labapp.conf*'
  R 'sudo rpm -ivh /srv/lab-rpm/labapp-1.0-1.noarch.rpm'
  R 'rpm -Va | wc -l'
  R 'rpm -Va'
  echo; echo "---- rpm2cpio ----"
  R 'rpm2cpio /srv/lab-rpm/labtool-1.0-1.noarch.rpm | cpio -t'
  R 'cd ~/work && rpm2cpio /srv/lab-rpm/labtool-1.0-1.noarch.rpm | cpio -idmv'
  R 'ls -l ~/work/usr/bin/labtool'
  R 'rpm -qf ~/work/usr/bin/labtool; echo "exit=$?"'
  R 'rpm -q labtool; echo "exit=$?"'
}

sec_ch7() {
  S "ch7. rpm は依存を解かない。署名は鍵があって初めて確かめられる"
  R "sudo rpm -ivh $RPM_APP; echo \"exit=\$?\""
  R "sudo rpm -ivh $RPM_LIB $RPM_APP"
  R 'sudo rpm -e liblab; echo "exit=$?"'
  R 'sudo rpm -e --nodeps liblab'
  R 'labapp; echo "exit=$?"'
  R 'rpm -V labapp; echo "exit=$?"'
  R "sudo rpm -ivh $RPM_LIB"
  R 'sudo rpm -e labapp liblab'
  R 'rpm -q labapp liblab; echo "exit=$?"'
  echo; echo "---- -i / -U / -F ----"
  R 'rpm -q labhello labtool-data; echo "exit=$?"'
  R 'sudo rpm -ivh /srv/lab-rpm/labhello-1.1-1.noarch.rpm; echo "exit=$?"'
  R 'sudo rpm -Fvh /srv/lab-rpm/labtool-data-1.0-1.noarch.rpm; echo "exit=$?"'
  R 'rpm -q labtool-data; echo "exit=$?"'
  R 'sudo rpm -Fvh /srv/lab-rpm/labhello-1.1-1.noarch.rpm'
  R 'sudo rpm -Uvh /srv/lab-rpm/labtool-data-1.0-1.noarch.rpm'
  R 'rpm -q labhello labtool-data'
  R 'yum list installed labhello labtool-data'
  echo; echo "---- 署名（ふつうこう考える） ----"
  R 'ls -l /srv/lab-files/'
  R 'rpm -K /srv/lab-files/labnosig-1.0-1.noarch.rpm; echo "exit=$?"'
  R 'rpm -K /srv/lab-tools-rpm/lab-mathtools-1.0-1.noarch.rpm; echo "exit=$?"'
  R 'rpm -K /srv/lab-files/tree-1.8.0-10.el9.x86_64.rpm; echo "exit=$?"'
  R 'rpm -Kv /srv/lab-files/labnosig-1.0-1.noarch.rpm'
  R 'rpm -Kv /srv/lab-tools-rpm/lab-mathtools-1.0-1.noarch.rpm'
  R 'rpm -Kv /srv/lab-files/tree-1.8.0-10.el9.x86_64.rpm'
  R "rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\\t%{SUMMARY}\\n'"
  R 'head -3 /srv/lab-tools-rpm/RPM-GPG-KEY-lab-tools'
  R 'sudo rpm --import /srv/lab-tools-rpm/RPM-GPG-KEY-lab-tools'
  R "rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\\t%{SUMMARY}\\n'"
  R 'rpm -K /srv/lab-tools-rpm/lab-mathtools-1.0-1.noarch.rpm; echo "exit=$?"'
  echo; echo "---- 中身を1バイト変えると ----"
  R 'cp /srv/lab-files/tree-1.8.0-10.el9.x86_64.rpm ~/work/tree-copy.rpm'
  R "printf 'A' | dd of=\$HOME/work/tree-copy.rpm bs=1 seek=55888 conv=notrunc status=none"
  R 'rpm -K ~/work/tree-copy.rpm; echo "exit=$?"'
  R 'rpm -Kv ~/work/tree-copy.rpm'
  echo; echo "---- 署名が無くても入る ----"
  R 'sudo rpm -ivh /srv/lab-files/labnosig-1.0-1.noarch.rpm'
  R "rpm -q --qf '%{NAME}: %{RSAHEADER:pgpsig}\\n' labnosig labhello"
}

case "${1:-}" in
  env) sec_env ;;
  ch1) sec_ch1 ;;
  ch5) sec_ch5 ;;
  ch6) sec_ch6 ;;
  ch7) sec_ch7 ;;
  *) echo "使い方: bash probe.sh env|ch1|ch5|ch6|ch7" >&2; exit 2 ;;
esac
