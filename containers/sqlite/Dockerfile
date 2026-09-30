# syntax=docker/dockerfile:1.9
FROM lab-base:1.0.0
USER root
ARG APT_SNAPSHOT=20260929T000000Z
RUN apt-get update \
 && apt-get install -y --no-install-recommends sqlite3 \
 && rm -rf /var/lib/apt/lists/*
# 教材資産は root 所有・読み取りのみ（読者が答えを書き換えられないようにする）
COPY --chown=root:root --chmod=0555 lab/ /lab/
ENV LAB_THEME=sqlite LAB_VERSION=1.0.0 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/OWNER/lab-sqlite:1.0.0
USER lab
