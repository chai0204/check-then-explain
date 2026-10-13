#!/usr/bin/env bash
# 練習機（ゲスト）の中で root として1回だけ走る。LinuC 主題1.10 の演習が使う初期状態を作る。
# 冪等に書く（もう在れば作り直さない）。vm reset --yes で練習機ごと消え、次回また走る。
set -uo pipefail

# ---- 演習01: 監査の的になる SUID バイナリを1つ仕込む ------------------------
#   /usr/bin/cat をそのまま SUID root で置く。一般ユーザが誰でも root 権限で
#   どのファイルも読める状態（/etc/shadow すら読める）。読者はこれを find で見つけて外す。
if [ ! -e /usr/local/bin/catfile ]; then
  cp /usr/bin/cat /usr/local/bin/catfile
  chown root:root /usr/local/bin/catfile
  chmod 4755 /usr/local/bin/catfile
fi

# ---- 演習02: 退職者のアカウント（まだ生きている。読者が無効化する） ---------
if ! id olduser >/dev/null 2>&1; then
  useradd -m -s /bin/bash olduser
  echo 'olduser:oldpass' | chpasswd
fi

# ---- 演習04: sudo を1コマンドだけ許す相手 -----------------------------------
if ! id deploy >/dev/null 2>&1; then
  useradd -m -s /bin/bash deploy
  echo 'deploy:deploy' | chpasswd
fi

# ---- 演習03: 止めるべき余計な待ち受け（古い echo サービス） -----------------
#   ncat で 2323/tcp に待ち受ける systemd サービス。読者が ss/lsof で見つけて止める。
if [ ! -e /etc/systemd/system/lab-echo.service ]; then
  cat > /etc/systemd/system/lab-echo.service <<'UNIT'
[Unit]
Description=lab 用の古い echo サービス（演習03で止める対象）
After=network.target

[Service]
ExecStart=/usr/bin/ncat -lk -p 2323 --sh-exec "/bin/echo linuc-echo"
Restart=always

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now lab-echo.service
fi

echo PROVISION_OK
