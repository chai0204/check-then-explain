#!/bin/bash
# LinuC 主題1.04 RPM 系の檻: ネットにつながっていない読者の代わりに、名前を引けない檻で打つ（2026-10-20 の作り直しから）。
# 理論編の目次・第10章の表（yum makecache・yum clean all）の裏づけ。
# 節（========== 題 ==========）ごとに檻を起動し直す。
#   bash probe/linuc-packages-rpm-offline.sh（または bash probe/linuc-packages-run.sh offline）
cd "$(dirname "$0")/.." || exit 1
exec python3 -I probe/linuc-packages-seq.py --script /dev/stdin --cage rpm --offline \
  --out logs/linuc-packages-rpm-offline.log \
  --note "ネットにつながっていないときに、本文と違って出るところ（節ごとに檻を起動し直した）" <<'INPUT'
========== 第9章・第10章: 練習用のリポジトリからは、ネットが無くても入る・上げられる ==========
$ sudo yum install labhello
Is this ok [y/N]: y
$ printf '%s\n' '[lab-updates]' 'name=lab updates (LinuC 1.04)' 'baseurl=file:///srv/lab-updates-rpm' 'gpgcheck=1' 'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-lab-updates' | sudo tee /etc/yum.repos.d/lab-updates.repo
$ sudo yum update labhello
Is this ok [y/N]: y
Is this ok [y/N]: y
$ labhello
========== 第10章の表: yum makecache は AlmaLinux 本体の分を確かめに行くので、ネットが無いと失敗する ==========
$ sudo yum makecache
$ echo $?
========== 第10章の表: ネットが無いときに yum clean all を打つと、lab から入れる操作も止まる ==========
$ sudo yum clean all
$ sudo yum install labhello
$ echo $?
INPUT
