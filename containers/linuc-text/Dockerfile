# syntax=docker/dockerfile:1.9
# LinuC 主題1.03（GNU と Unix のコマンド）用の檻。
# 一般ユーザ lab のまま、テキストを流す・切る・並べる・書き換える・vi で直す。
# パッケージは足さない。出題範囲の19個のフィルタも grep / sed / xargs / vim / nano も
# lab-linuc-base に全部入っていて、man も全部読める（実測 2026-10-13）。
# 足すのは練習用のテキスト（~/text）と演習（/lab）だけ。
#
# 1.0.1（2026-10-13）: 事実確認で見つかった誤りを、演習の解答とヒント（lab/）で直した。
#   ~/text の層は 1.0.0 と同じ（キャッシュのまま。本文に載せた日付も変わらない）。
FROM lab-linuc-base:1.0.0
USER root

# ---- 1) 理論編の練習用テキスト ------------------------------------------------
#   ~/text はボリュームの外に置く。起動し直すたびに元の中身へ戻るので、
#   どの章から読み始めても本文と同じ画面が出る（ボリュームに置くと前回の操作が残る）。
#   TAB・最後の改行が無いファイル・CRLF は見た目で区別できないので、スクリプトで作る。
#   演習より先に置く。演習を直すたびにこの層が作り直されると、本文に載せた ls -l の日付が変わるため。
COPY --chown=root:root --chmod=0555 text/mktext.sh /usr/local/lib/lab-text/mktext.sh
USER lab
#   WORKDIR はここで決める。後ろに置くと /home/lab の更新時刻が変わる層ができうるため（本文の ls -ld .. に出る）。
WORKDIR /home/lab
RUN bash /usr/local/lib/lab-text/mktext.sh /home/lab/text
USER root

# ---- 2) 演習。root 所有・読み取りのみ（読者が判定を書き換えられない） ----------
COPY --chown=root:root --chmod=0555 lab/ /lab/
#   配布ファイル（seed）だけは 0755 にする。root 所有なので読者が元を書き換えられないのは同じ。
#   0555 のままだと、lab reset が cp -r で写した ~/work/NN のファイルが読み取り専用になる
#   （lab start は写した後に chmod u+w するが、lab reset はしない）。vi の :wq が
#   E45: 'readonly' option is set で通らなくなった（実測 2026-10-13）。
COPY --chown=root:root --chmod=0755 lab/seed/ /lab/seed/

USER lab
LABEL org.opencontainers.image.source=https://github.com/chai0204/check-then-explain
LABEL org.opencontainers.image.description="LinuC 主題1.03（GNU と Unix のコマンド）を手で確かめる学習用コンテナ"
LABEL org.opencontainers.image.licenses=MIT
ENV LAB_THEME=linuc-text LAB_VERSION=1.0.1 LAB_APT_SNAPSHOT=20260929T000000Z \
    LAB_IMAGE=ghcr.io/chai0204/lab-linuc:text-1.0.1
CMD ["/bin/bash", "-l"]
