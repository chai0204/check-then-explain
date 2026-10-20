# syntax=docker/dockerfile:1.9
FROM lab-base:1.0.0
USER root
ARG APT_SNAPSHOT=20260929T000000Z
RUN apt-get update \
 && apt-get install -y --no-install-recommends sqlite3 \
 && rm -rf /var/lib/apt/lists/*
# 教材資産は root 所有・読み取りのみ（読者が答えを書き換えられないようにする）
COPY --chown=root:root --chmod=0555 lab/ /lab/
# ---- lab コマンドを最新にする（1.0.1、2026-10-20）--------------------
#   lab の正本は containers/base/bin/lab。土台（lab-base）から作り直すと上の層が全部作り直しになり、
#   本文の記録とずれうるので、最新の lab をここで重ねる。これより前の層は 1.0.0 とキャッシュで同一。
#   build: docker build --build-context labcmd=containers/base -t lab-sqlite:<版> containers/sqlite
COPY --from=labcmd --chown=root:root --chmod=0755 bin/lab /usr/local/bin/lab
ENV LAB_THEME=sqlite LAB_VERSION=1.0.1 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/chai0204/lab-sqlite:1.0.1
USER lab
