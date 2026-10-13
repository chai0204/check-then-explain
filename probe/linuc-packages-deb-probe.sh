#!/bin/bash
# LinuC 主題1.04（リポジトリとパッケージ管理）Debian 系の檻で、本文に載せる全コマンドを実際に通す。
# ここに出ない出力は本文に書かない（憲章 §3）。
#
# 章ごとに「檻を起動し直した直後」から打つ。前の章で入れたものが次の章の出力を変えるため
# （例: 第1章で liblab を入れると、第2章の apt install labapp が liblab を新規に入れなくなる）。
# 起動し直しは probe/linuc-packages-run.sh がやる。この中では引数で節を選ぶ。
#   bash /tmp/probe.sh env|ch1|ch2|ch3|ch4
set -u
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
S() { printf '\n\n========== %s ==========\n' "$*"; }

DEB_APP=/srv/lab-repo/pool/main/l/labapp/labapp_1.0_all.deb
DEB_LIB=/srv/lab-repo/pool/main/libl/liblab/liblab_1.0_all.deb
DEB_H11=/srv/lab-repo/pool/main/l/labhello/labhello_1.1_all.deb

sec_env() {
  S "0. 環境（Debian 系の檻・起動直後）"
  R lab env
  R 'id'
  R 'hostname'
  R lab
  R 'lab ls'
}

sec_ch1() {
  S "ch1. パッケージは中身と、台帳への届け出でできている（Debian 系）"
  R 'ls -l /srv/lab-repo/pool/main/l/labapp/'
  R "file $DEB_APP"
  R "dpkg-deb -I $DEB_APP"
  R "dpkg-deb -c $DEB_APP"
  R "dpkg-deb -f $DEB_APP Package Version Depends"
  echo; echo "---- 中身だけ置く（ふつうこう考える） ----"
  R "sudo dpkg-deb -x $DEB_LIB /"
  R 'ls -l /usr/lib/liblab/liblab.sh'
  R '. /usr/lib/liblab/liblab.sh; lab_greet "ファイルは置けた"'
  R 'dpkg -l liblab; echo "exit=$?"'
  R 'dpkg -S /usr/lib/liblab/liblab.sh; echo "exit=$?"'
  echo; echo "---- dpkg で入れる ----"
  R "sudo dpkg -i $DEB_LIB"
  R 'dpkg -l liblab'
  R 'dpkg -S /usr/lib/liblab/liblab.sh'
  R 'ls /var/lib/dpkg/info/liblab.*'
  R 'cat /var/lib/dpkg/info/liblab.list'
  R 'cat /var/lib/dpkg/info/liblab.md5sums'
  R "grep -A10 '^Package: liblab\$' /var/lib/dpkg/status"
  R "grep -c '^Package: ' /var/lib/dpkg/status"
  echo; echo "---- リポジトリ = 中身（pool）と目録（dists） ----"
  R 'find /srv/lab-repo -type f | sort'
  R "zcat /srv/lab-repo/dists/lab/main/binary-amd64/Packages.gz | grep -A16 '^Package: labapp\$'"
  R 'ls -1 /var/lib/apt/lists/ | grep lab-repo'
  R 'apt-cache policy labapp'
  R 'dpkg -l labapp; echo "exit=$?"'
}

sec_ch2() {
  S "ch2. apt は目録を読み、台帳に書く"
  R 'apt-cache search liblab'
  R 'apt-cache show labapp'
  R 'apt-cache depends labapp'
  R 'apt-cache rdepends liblab'
  R 'apt-cache policy labhello'
  R 'apt-cache policy tree'
  R 'apt-cache depends tree'
  R 'apt show labapp'
  echo; echo "---- 入れる ----"
  R 'sudo apt install -y labapp'
  R 'labapp'
  R 'apt-mark showauto | grep lab'
  R 'apt-mark showmanual | grep lab'
  echo; echo "---- 消す（ふつうこう考える） ----"
  R 'sudo apt remove -y labapp'
  R 'dpkg -l labapp'
  R 'ls -l /etc/labapp.conf'
  R 'cat /etc/labapp.conf'
  R 'dpkg -s labapp | head -2'
  R 'sudo apt purge -y labapp'
  R 'dpkg -l labapp; echo "exit=$?"'
  R 'ls -l /etc/labapp.conf; echo "exit=$?"'
  R 'dpkg -l liblab'
  R 'sudo apt autoremove -y'
  R 'dpkg -l liblab; echo "exit=$?"'
  echo; echo "---- 更新 ----"
  R 'apt list --upgradable'
  R 'sudo apt-get -s upgrade'
  R 'labhello'
  R 'sudo apt install -y labhello'
  R 'labhello'
  R 'apt-cache policy labhello'
  echo; echo "---- apt と apt-get / apt-cache ----"
  R 'apt-cache show labhello | grep -E "^(Package|Version):"'
  R 'apt show labhello 2>/dev/null | grep -E "^(Package|Version):"'
  R 'apt-get download liblab'
  R 'ls -l *.deb'
  R 'dpkg -l liblab; echo "exit=$?"'
  R 'ls /var/cache/apt/archives/'
}

sec_ch3() {
  S "ch3. 目録は、自分で取りに行くまで古いまま"
  R 'cat /etc/apt/sources.list'
  R 'ls -l /etc/apt/sources.list.d/'
  R 'cat /etc/apt/sources.list.d/ubuntu.sources'
  R 'find /srv/lab-repo/dists -type f | sort'
  R 'head -9 /srv/lab-repo/dists/lab/Release'
  R 'ls -1 /var/lib/apt/lists/ | grep -v -e lock -e partial -e auxfiles'
  echo; echo "---- 1行足す（ふつうこう考える） ----"
  R 'find /srv/lab-extra -type f | sort'
  R "echo 'deb file:/srv/lab-extra extra main' | sudo tee /etc/apt/sources.list.d/lab-extra.list"
  R 'apt-cache policy labextra'
  R 'sudo apt install -y labextra; echo "exit=$?"'
  echo; echo "---- 取りに行く。が、署名が無いと受け取らない ----"
  R 'sudo apt update; echo "exit=$?"'
  R 'ls -1 /var/lib/apt/lists/ | grep lab-extra; echo "exit=$?"'
  R "echo 'deb [trusted=yes] file:/srv/lab-extra extra main' | sudo tee /etc/apt/sources.list.d/lab-extra.list"
  R 'sudo apt update'
  R 'ls -1 /var/lib/apt/lists/ | grep lab-extra'
  R 'apt-cache policy labextra'
  R 'sudo apt install -y labextra'
  R 'labextra'
  echo; echo "---- apt-file ----"
  R 'dpkg -S liblab.sh; echo "exit=$?"'
  R 'apt-file search liblab.sh'
  R 'apt-file search bin/labapp'
  R 'apt-file list labapp'
  R 'apt-file search labextra'
  R 'apt-file search bin/dig; echo "exit=$?"'
  R 'ls -1 /var/lib/apt/lists/ | grep Contents'
  R 'grep -v "^//" /etc/apt/apt.conf.d/60lab-apt-file'
  R 'sudo apt-file update'
}

sec_ch4() {
  S "ch4. dpkg は台帳しか見ない"
  R "sudo dpkg -i $DEB_APP; echo \"exit=\$?\""
  R 'dpkg -l labapp liblab'
  R 'labapp; echo "exit=$?"'
  R 'sudo apt install -y labhello; echo "exit=$?"'
  R 'sudo apt --fix-broken install -y'
  R 'dpkg -l labapp liblab'
  R 'labapp'
  echo; echo "---- 台帳を引く ----"
  R 'dpkg -l | head -8'
  R "dpkg -l 'lab*'"
  R 'dpkg -L labapp'
  R 'dpkg -S /usr/bin/labapp'
  R 'dpkg -S labapp.conf'
  R 'dpkg -s labapp'
  R "dpkg -c $DEB_H11"
  R "dpkg -I $DEB_H11"
  echo; echo "---- 台帳と照らし合わせる（dpkg -V） ----"
  R 'dpkg -V labapp; echo "exit=$?"'
  R "echo 'greeting=\"こんにちは\"' | sudo tee -a /etc/labapp.conf"
  R "echo '# 書き足した' | sudo tee -a /usr/bin/labapp"
  R 'dpkg -V labapp; echo "exit=$?"'
  R 'sudo apt install -y --reinstall labapp'
  R 'dpkg -V labapp; echo "exit=$?"'
  echo; echo "---- 消す ----"
  R 'sudo dpkg -r liblab; echo "exit=$?"'
  R 'sudo dpkg -r labapp'
  R 'dpkg -l labapp | tail -1'
  R 'ls -l /etc/labapp.conf'
  R 'sudo dpkg -P labapp'
  R 'dpkg -l labapp; echo "exit=$?"'
  R 'sudo dpkg -P liblab'
  echo; echo "---- dpkg-reconfigure ----"
  R 'cat /etc/timezone; ls -l /etc/localtime'
  R 'env -u TZ date -d @1790812800'
  R 'sudo debconf-show tzdata'
  R "printf '5\n78\n' | sudo dpkg-reconfigure -f teletype tzdata"
  R 'cat /etc/timezone; ls -l /etc/localtime'
  R 'env -u TZ date -d @1790812800'
  R 'sudo debconf-show tzdata'
}

case "${1:-}" in
  env) sec_env ;;
  ch1) sec_ch1 ;;
  ch2) sec_ch2 ;;
  ch3) sec_ch3 ;;
  ch4) sec_ch4 ;;
  *) echo "使い方: bash probe.sh env|ch1|ch2|ch3|ch4" >&2; exit 2 ;;
esac
