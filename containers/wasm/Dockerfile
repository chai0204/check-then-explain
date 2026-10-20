# syntax=docker/dockerfile:1.9

# ---- 段1: wasmtime の取り出しだけを行う捨て段 -------------------------------
#   実測（2026-09-30）: これを1段でやると xz-utils と tar.xz と展開後の
#   ディレクトリが最終イメージに残り、展開後 1013MB になった。
#   マルチステージにして、最終層にはバイナリ1本だけを持ち込む。
FROM lab-base:1.0.0 AS wasmtime-src
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends xz-utils \
 && rm -rf /var/lib/apt/lists/*
# バージョンと sha256 を固定する。ここを固定しないと半年後に
# 本文の出力と読者の画面がずれる（それが唯一の差別化なので譲れない）。
ADD --checksum=sha256:c71f7e0d30a92e418f0d17db7c6d8f6664c1ad764340a1278678f4209deab534 \
    https://github.com/bytecodealliance/wasmtime/releases/download/v49.0.1/wasmtime-v49.0.1-x86_64-linux.tar.xz \
    /tmp/wasmtime.tar.xz
RUN tar -xJf /tmp/wasmtime.tar.xz -C /tmp

# ---- 段2: 読者に配るイメージ -----------------------------------------------
FROM lab-base:1.0.0
USER root
ARG APT_SNAPSHOT=20260929T000000Z

# wabt    = wat2wasm / wasm2wat / wasm-objdump
# nodejs  = ブラウザ相当の WebAssembly API を CLI から叩くために入れる
#           （同じ .wasm を2つのホストで動かす回で必要。代替は無い）
RUN apt-get update \
 && apt-get install -y --no-install-recommends wabt nodejs \
 && rm -rf /var/lib/apt/lists/* /var/cache/man/*

COPY --from=wasmtime-src --chmod=0755 \
     /tmp/wasmtime-v49.0.1-x86_64-linux/wasmtime /usr/local/bin/wasmtime

COPY --chown=root:root --chmod=0555 lab/ /lab/
# ---- lab コマンドを最新にする（1.0.1、2026-10-20）--------------------
#   lab の正本は containers/base/bin/lab。土台（lab-base）から作り直すと上の層が全部作り直しになり、
#   本文の記録とずれうるので、最新の lab をここで重ねる。これより前の層は 1.0.0 とキャッシュで同一。
#   build: docker build --build-context labcmd=containers/base -t lab-wasm:<版> containers/wasm
COPY --from=labcmd --chown=root:root --chmod=0755 bin/lab /usr/local/bin/lab
ENV LAB_THEME=wasm LAB_VERSION=1.0.1 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/chai0204/lab-wasm:1.0.1
USER lab
