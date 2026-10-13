#!/usr/bin/env bash
# linuc-admin（主題1.08 システム管理）の初回準備。
# 練習機の中で root として1回だけ走る（外の vm が qemu-guest-agent 経由で流す）。
# vm reset --yes で練習機を工場出荷時に戻したあとは、次の起動でもう一度走る。
#
# ここで作るのは「演習の相手」だけにする。章の本文で読者が自分で作るもの（alice など）は作らない。
#   bob    … 演習02（所属を足す）。最初から proj-a と proj-b に入っている
#   dave   … 演習03（一時停止）。外の lab の鍵で ssh できる
#   eve    … 演習06（at と cron を1人だけ止める）
#   /etc/cron.daily/lab-backup.sh … 演習05。置いてあるのに毎日は走らない
#   /usr/local/bin/lab-report     … 演習07。呼ぶ側のロケールで出力が変わる
#   /home/student/lab08/          … 演習08。文字コードの違う3つのファイル
#
# グループ proj-a / proj-b の GID は 1101 / 1102 に固定する。番号を指定しないと 1001 から取られ、
# あとで作るユーザの「UID と同じ番号の私的グループ」とずれて、本文の id の出力が読みにくくなる。
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8

# ---- 演習02: 所属を足す相手 ---------------------------------------------------
groupadd -g 1101 proj-a
groupadd -g 1102 proj-b
useradd -m -s /bin/bash -c 'Bob (lab 02)' -G proj-a,proj-b bob

# ---- 演習03: 一時停止する相手（外の lab から鍵で入れる） ---------------------
useradd -m -s /bin/bash -c 'Dave (lab 03)' dave
install -d -m 0700 -o dave -g dave /home/dave/.ssh
install -m 0600 -o dave -g dave /home/student/.ssh/authorized_keys /home/dave/.ssh/authorized_keys
printf '%s\n' 'dave の作業メモ。アカウントを止めても、このファイルは残しておくこと。' > /home/dave/notes.txt
chown dave:dave /home/dave/notes.txt

# ---- 演習06: at と cron を止める相手 ------------------------------------------
useradd -m -s /bin/bash -c 'Eve (lab 06)' eve

# ---- 演習05: 置いてあるのに毎日は走らないスクリプト ---------------------------
cat > /etc/cron.daily/lab-backup.sh <<'EOF'
#!/bin/sh
# 毎日1回、記録を1行残す（演習05）。中身は変えなくてよい。
echo "$(date '+%F %T') lab-backup ran" >> /var/backups/lab-backup.log
EOF
chmod 0644 /etc/cron.daily/lab-backup.sh

# ---- 演習07: 呼ぶ側のロケールで出力が変わるスクリプト -------------------------
cat > /usr/local/bin/lab-report <<'EOF'
#!/bin/bash
# 毎朝の点検メモを作るスクリプト（演習07）。
# 呼ぶ人のロケールによって出力が変わってしまう。誰がどう呼んでも同じ出力にしたい。
mon=$(date | awk '{print $2}')      # 今月の英語3文字（Oct など）を取り出すつもり
echo "今月のログ: /var/log/archive/$mon"
echo "当番の順: $(printf '%s\n' bob Alice dave Carol | sort | paste -sd ' ')"
EOF
chmod 0755 /usr/local/bin/lab-report

# ---- 演習08: 文字コードの違う3つのファイル ------------------------------------
#   a.txt … Shift_JIS（Windows のメモ帳の古い既定）
#   b.txt … EUC-JP（古い Unix の既定）
#   c.txt … ISO-2022-JP（日本語メールの伝統的な形）
d=/home/student/lab08
install -d -o student -g student "$d"
printf '%s\n' '会議メモ: 来週の月曜に棚卸し。' '担当は佐藤さん。' | iconv -f UTF-8 -t SHIFT_JIS   > "$d/a.txt"
printf '%s\n' 'サーバ移行の手順書（第2版）。' '作業は夜間に行う。' | iconv -f UTF-8 -t EUC-JP      > "$d/b.txt"
printf '%s\n' '件名: 定期点検のお知らせ' '本文: 10月20日に停電があります。' | iconv -f UTF-8 -t ISO-2022-JP > "$d/c.txt"
chown student:student "$d"/*.txt
chmod 0644 "$d"/*.txt

echo PROVISION_OK
