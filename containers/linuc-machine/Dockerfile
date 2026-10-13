# syntax=docker/dockerfile:1.9
# LinuC の仮想マシン型の檻（システム系5コースの土台）。
#   外側（lab-linuc-vmhost）に、練習機のディスクと、外から練習機に入る鍵を載せる。
#
#   1) docker build -t lab-linuc-vmhost:1.0.0 containers/linuc-machine/host
#   2) bash containers/linuc-machine/guest/make-guest.sh      （build/ にディスクと鍵ができる）
#   3) docker build -t lab-linuc-machine:1.0.0 containers/linuc-machine
#
# コースはこれを FROM にして、演習（/lab）と、必要なら練習機の定義（/etc/lab-vm/domain.xml.in）と
# 初回の準備（/etc/lab-vm/provision.sh）を足す。
FROM lab-linuc-vmhost:1.0.0
USER root

# 練習機のディスク（読み取り専用の土台）。実行時は ~/vm/linuc.qcow2 という差分を上に重ねて使うので、
# 読者が何をしても土台は変わらず、vm reset --yes でいつでも工場出荷時に戻せる。
COPY --chown=root:root --chmod=0444 build/linuc-guest.qcow2 /var/lib/lab-vm/linuc-guest.qcow2
COPY --chown=root:root --chmod=0444 build/linuc-guest.sha256 /var/lib/lab-vm/linuc-guest.sha256

# 外の lab から練習機の student に入る鍵と、練習機のホスト鍵（初回の確認を省くため）。
# 鍵はイメージに入るので誰でも読めるが、練習機の ssh はこのコンテナの 127.0.0.1 にしか開いていない。
COPY --chown=lab:lab --chmod=0600 build/lab_ed25519 /home/lab/.ssh/id_ed25519
COPY --chown=lab:lab --chmod=0644 build/lab_ed25519.pub /home/lab/.ssh/id_ed25519.pub
COPY --chown=lab:lab --chmod=0644 build/known_hosts /home/lab/.ssh/known_hosts

USER lab
