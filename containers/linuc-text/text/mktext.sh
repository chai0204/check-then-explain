#!/bin/bash
# 理論編（第1〜10章）で使う練習用のテキストを ~/text に作る。
# 本文の出力はすべて、このスクリプトが作ったファイルに対して打った記録である。
# 中身を1文字でも変えたら、probe を取り直して本文を合わせること。
#
# ファイルをリポジトリに直接置かずにここで作るのは、見た目では区別できない3種類
# （TAB / 最後の改行が無い / CRLF）を確実に作るため。エディタで保存すると変わってしまう。
set -eu
d=${1:?usage: mktext.sh DIR}
mkdir -p "$d/files/sub"
cd "$d"

# ---- 第4・5章: 並べ替えと重複（大文字で始まる語を1つ混ぜる） ----
printf '%s\n' banana apple cherry apple apple banana Durian > fruits.txt

# ---- 第5章: CSV（点数に 9 と 100 を混ぜる。文字順と数の順が分かれる） ----
printf '%s\n' 'id,name,dept,score' '1,Sato,dev,72' '2,Suzuki,sales,9' \
  '3,Takahashi,dev,100' '4,Tanaka,hr,85' '5,Ito,sales,85' > scores.csv

# ---- 第5章: join と paste（id が揃っていない2つの表） ----
printf '%s\n' '1 Sato' '2 Suzuki' '3 Takahashi' > names.txt
printf '%s\n' '1 sato@example.com' '3 takahashi@example.com' '4 ito@example.com' > mails.txt

# ---- 第5章: 空白で桁を揃えた表（cut -d' ' が空の欄を数える） ----
printf '%s\n' 'alice   23  tokyo' 'bob     7   osaka' 'carol   41  nagoya' > spaces.txt

# ---- 第5・6章: TAB 区切り ----
printf 'name\tage\tcity\nalice\t23\ttokyo\nbob\t7\tosaka\n' > tabs.txt

# ---- 第6章: 行頭が TAB、行の途中は次の TAB 位置（16桁目）までの空白（unexpand が変えるのは行頭だけ） ----
printf 'list:\n\tapple   red\n\tbanana  yellow\n' > indent.txt

# ---- 第4章: 見た目では分からない3種類 ----
printf 'first line\nsecond line' > notail.txt   # 最後の改行が無い
printf 'line1\r\nline2\r\n' > win.txt          # CRLF（Windows の改行）
printf 'line1\nline2\n' > unix.txt             # LF
printf '%s\n' first '' third > blank.txt       # 空行を含む

# ---- 第5・8章: アクセスログ（空白区切り。9列目がステータス） ----
cat > access.log <<'LOG'
192.168.1.10 - - [13/Oct/2026:09:00:01 +0900] "GET /index.html HTTP/1.1" 200 512
192.168.1.11 - - [13/Oct/2026:09:00:03 +0900] "GET /about.html HTTP/1.1" 200 734
192.168.1.10 - - [13/Oct/2026:09:00:07 +0900] "GET /missing HTTP/1.1" 404 128
192.168.1.12 - - [13/Oct/2026:09:01:15 +0900] "POST /login HTTP/1.1" 302 0
192.168.1.10 - - [13/Oct/2026:09:01:20 +0900] "GET /index.html HTTP/1.1" 200 512
192.168.1.13 - - [13/Oct/2026:09:02:02 +0900] "GET /admin HTTP/1.1" 403 256
192.168.1.11 - - [13/Oct/2026:09:02:40 +0900] "GET /missing HTTP/1.1" 404 128
192.168.1.10 - - [13/Oct/2026:09:03:05 +0900] "GET /api/data HTTP/1.1" 500 64
192.168.1.12 - - [13/Oct/2026:09:03:30 +0900] "GET /index.html HTTP/1.1" 200 512
192.168.1.14 - - [13/Oct/2026:09:04:11 +0900] "GET /missing HTTP/1.1" 404 128
LOG

# ---- 第9章: サーバのログ（ERROR が本文に出てくる INFO 行を1つ混ぜる） ----
cat > server.log <<'LOG'
2026-10-13 09:00:01 INFO  server started on port 8080
2026-10-13 09:00:05 WARN  disk usage 85%
2026-10-13 09:01:10 ERROR connection refused from 10.0.0.5
2026-10-13 09:02:00 INFO  user alice logged in
2026-10-13 09:02:30 INFO  retry finished after ERROR in job 42
2026-10-13 09:03:00 ERROR timeout after 30s
2026-10-13 09:04:00 info  lowercase level from old client
2026-10-13 09:05:00 WARNING deprecated option -x
2026-10-13 09:06:00 INFO  peer 10.0.0.50 connected
LOG

# ---- 第9章: . が「任意の1文字」であることを見る ----
printf '%s\n' 10.0.0.5 10.0.0.50 110.0.0.5 ip-10-0-0-5 > ips.txt

# ---- 第6章: sed で書き換える設定ファイル ----
cat > app.conf <<'CONF'
# app.conf - 練習用の設定ファイル
host=localhost
port=8080
port_admin=8081
# debug=true
log_level=info
url=http://localhost:8080/?lang=ja
CONF

# ---- 第6章: fmt で折り返す文 ----
printf '%s\n' 'Text streams flow from one command to the next. Each filter reads its input, changes it a little, and writes the result for the next command.' > poem.txt
printf '%s\n' '日本語の文には単語の間に空白が無いので、どこで折り返せばよいかを fmt は知らない。' > jp.txt

# ---- 第10章: vi で直すファイル ----
printf '%s\n' apple banana cherry date > memo.txt

# ---- 第2章: 実行の仕方を比べるスクリプト（わざと実行権を付けない） ----
printf '%s\n' '#!/bin/bash' 'echo "hello from $0"' > hello.sh
printf '%s\n' 'cd /tmp' 'echo "スクリプトの中では $PWD"' > cdtest.sh
printf '%s\n' '#!/bin/bash' 'echo "子のプロセスから見た GREETING=[$GREETING]"' > child.sh
chmod 644 hello.sh cdtest.sh child.sh

# ---- 第8章: 名前に空白を含むファイル ----
: > "files/report 2026.txt"
: > files/memo.txt
: > "files/old data.tmp"
: > files/cache.tmp
: > "files/sub/a b c.tmp"
: > files/sub/keep.txt

# ---- 日付を固定する ----
#   本文には ls -l と pr のヘッダの日付が出る。ビルドした時刻のままだと、
#   イメージを作り直すたびに本文と違う画面になるので、決まった時刻にそろえる。
#   ~/text の親（ホームディレクトリ）も第2章の ls -ld .. に出るのでそろえる。
find "$d" -exec touch -h -d '2026-10-13 09:00:00' {} +
touch -d '2026-10-13 09:00:00' "$d/.."
