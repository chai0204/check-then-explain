# syntax=docker/dockerfile:1.9
# 共通ベース。テーマ層はこれを FROM にして数行足すだけにする。
#   build: docker build -t lab-base:1.0.0 containers/base

# 動くタグは再現性にならないのでダイジェストで固定する（実測 2026-09-30）
FROM ubuntu:24.04@sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3

# 対話プロンプトを止める＝ビルドログをそのまま読者に見せられる形にする
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 TZ=Asia/Tokyo

# ---- 1) ca-certificates だけ既定リポジトリから入れる -----------------------
#   snapshot.ubuntu.com は http 指定でも 443 へリダイレクトするため HTTPS が必須。
#   ところが ubuntu:24.04 には ca-certificates が入っていない（minimal イメージ）。
#   つまり「時刻を固定するために先に CA が要る」という鶏卵になる。
#   CA の束はバージョン差が教材の出力に影響しないので、ここだけ非固定を許す。
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# ---- 2) ここから apt を「時刻」で固定する（版番号は1つも書かない） ---------
#   パッケージごとに =1.2.3 と書くと依存解決が壊れてビルドが落ちる。
#   時刻を決めれば版は決まる。更新操作は APT_SNAPSHOT の日付を上げることだけ。
ARG APT_SNAPSHOT=20260929T000000Z
RUN printf '%s\n' \
      'Types: deb' \
      "URIs: https://snapshot.ubuntu.com/ubuntu/${APT_SNAPSHOT}" \
      'Suites: noble noble-updates noble-security' \
      'Components: main universe' \
      'Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg' \
    > /etc/apt/sources.list.d/ubuntu.sources \
 && rm -f /etc/apt/sources.list.d/ubuntu.sources.orig

# ---- 3) man を復元する（公式 ubuntu は2重に man を殺している） -------------
#   a. dpkg の path-exclude が /usr/share/man を捨てている
#   b. /usr/bin/man 自体が dpkg-divert でスタブに差し替えられている
RUN rm -f /etc/dpkg/dpkg.cfg.d/excludes /etc/apt/apt.conf.d/docker-clean \
 && if dpkg-divert --list | grep -q '/usr/bin/man'; then \
      rm -f /usr/bin/man && dpkg-divert --quiet --remove --rename /usr/bin/man; \
    fi

# ---- 4) 共通パッケージ（全テーマで使うものだけ。固有は派生層へ） -----------
#   ここに入れるのは「全テーマで使うもの」だけ。ネットワーク系（tcpdump / iproute2 /
#   dnsutils / netcat）は TCP・VPN 回でしか使わないので、共通ベースには入れず
#   テーマ派生層に置く。実測では、これを共通に入れると展開後 711MB になり上限を超えた。
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash coreutils diffutils findutils grep sed gawk \
      curl less file tree jq xxd vim procps \
      time bc \
      man-db \
 && apt-get install -y --reinstall --no-install-recommends coreutils procps \
 && mandb -q \
 && rm -rf /var/lib/apt/lists/* /var/cache/man/* /var/cache/debconf/*-old

# ---- 5) 読者ユーザ。root を既定にしない -----------------------------------
#   sudo は入れるが、既定は非 root にする。sudo を打つ動作そのものが
#   「いま特権に入った」という教材になる。
#   落とし穴（実測 2026-09-30）: ubuntu:24.04 には既定で `ubuntu` ユーザー（UID 1000）が
#   入っている。22.04 には無かったので、useradd -u 1000 が
#   `useradd: UID 1000 is not unique` で落ちる。先に消す。
#   UID 1000 を使うのは、ホスト側の一般ユーザーと揃えてボリュームの所有者をずらさないため。
RUN userdel -r ubuntu 2>/dev/null || true \
 && useradd -m -u 1000 -s /bin/bash lab \
 && apt-get update \
 && apt-get install -y --no-install-recommends sudo \
 && echo 'lab ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/lab \
 && chmod 0440 /etc/sudoers.d/lab \
 && rm -rf /var/lib/apt/lists/*

# ---- 6) ボリュームのマウント先を先に lab 所有で作る -----------------------
#   落とし穴（実測 2026-09-30）: docker は空の名前付きボリュームをマウントするとき、
#   マウント先ディレクトリの所有者と権限をコピーする。ここで作っておかないと
#   ボリュームが root:root で作られ、lab ユーザーが進捗ファイルを書けなくなる
#   （`Permission denied` になり、ヒントの段が進まず達成も記録されない）。
RUN install -d -o lab -g lab -m 0755 /home/lab/.lab /home/lab/work

# ---- 7) 教材資産は root 所有・読み取りのみ（読者が答えを書き換えられない） --
COPY --chown=root:root --chmod=0755 bin/lab /usr/local/bin/lab
COPY --chown=root:root --chmod=0644 etc/99-lab.sh /etc/profile.d/99-lab.sh

ENV LAB_THEME=base LAB_HOME=/lab
USER lab
WORKDIR /home/lab
# ログインシェルにする＝ /etc/profile.d が走り、起動時に現在地が必ず出る。
# ENTRYPOINT にしないのは `docker run … lab check 03` を素通しさせるため。
CMD ["/bin/bash", "-l"]
