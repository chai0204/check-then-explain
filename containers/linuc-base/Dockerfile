# syntax=docker/dockerfile:1.9
# LinuC 用の共通層（コンテナで足りる主題 1.02 / 1.03 / 1.04 / 1.06 が FROM にする）。
#   build: docker build -t lab-linuc-base:1.0.0 containers/linuc-base
#
# lab-base との違いは1点だけ: **入っている全パッケージの man を読めるようにする**。
# LinuC は man を引けることが出題範囲そのもの（1.03.1）なので、ここは削れない。
FROM lab-base:1.0.0
USER root

# ---- 1) man を全パッケージ分戻す ------------------------------------------
#   lab-base は dpkg の path-exclude を外した**後で**入れたパッケージの man しか持たない。
#   ubuntu:24.04 に最初から入っていた grep / sed / findutils / tar / gzip / bash /
#   util-linux などは man が無く、`man grep` が No manual entry になる
#   （lab-base で実測 2026-10-13。lab-linuc-services では util-linux だけ個別に入れ直していた）。
#
#   全パッケージを apt-get install --reinstall すると直るが、層が +373MB になった
#   （実測 2026-10-13: 605MB → 978MB。同じ中身のファイルが上の層にもう一度書かれるため）。
#   そこで、入っているのと**同じ版**の .deb を取得し、/usr/share/man だけを取り出す。
#   一括で `apt-get download a=1 b=2 …` とすると、1件でも版が見つからないと全件が落ちた
#   （実測 2026-10-13: 146 個中 0 個）。1件ずつ取り、取れなかったものは名前を出す。
#
#   /var/cache/apt/*.bin も消す。apt-get update が作る索引のキャッシュで約 97MB あり、
#   lists だけ消しても層に残る（実測 2026-10-13。lab-base の各層にも同じものが残っている）。
RUN apt-get update \
 && mkdir -p /tmp/debs && cd /tmp/debs \
 && dpkg-query -W -f='${binary:Package}=${Version}\n' > /tmp/want \
 && while read -r p; do apt-get download "$p" >/dev/null 2>&1 || echo "$p" >> /tmp/miss; done < /tmp/want \
 && for f in /tmp/debs/*.deb; do \
      dpkg-deb --fsys-tarfile "$f" | tar -x -C / --wildcards './usr/share/man/*' 2>/dev/null || true; \
    done \
 && echo "man 復元: 対象 $(wc -l < /tmp/want) 個 / 取得 $(ls /tmp/debs | wc -l) 個" \
 && if [ -s /tmp/miss ]; then echo "取得できなかった版:"; cat /tmp/miss; fi \
 && cd / && rm -rf /tmp/debs /tmp/want /tmp/miss /var/lib/apt/lists/* /var/cache/apt/*.bin

# ---- 2) LinuC の全コースで使うもの ------------------------------------------
#   manpages       : regex(7) / hier(7) など、出題範囲が名指しする基本ページ
#   nano           : 1.03.5 の「標準のエディタを切り替える」で vi 以外を1つ要る
#   psmisc         : killall / pstree / fuser
#   bash-completion: Tab 補完。打ち間違いで本文と違う画面になるのを減らす
RUN apt-get update \
 && apt-get install -y --no-install-recommends manpages nano psmisc bash-completion \
 && mandb -q \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin /var/cache/apt/archives/*.deb

ENV LAB_THEME=linuc-base LAB_APT_SNAPSHOT=20260929T000000Z
USER lab
WORKDIR /home/lab
CMD ["/bin/bash", "-l"]
