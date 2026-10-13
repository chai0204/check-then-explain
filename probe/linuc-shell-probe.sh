#!/bin/bash
# LinuC 主題1.06（シェルおよびスクリプト）の本文に載せる全コマンドを、檻の中で実際に通す。
# ここに出ない出力は本文に書かない（憲章 §3）。
#
# 記録の取り方（読者と同じ --hostname とボリューム2つで起動する。ボリューム名は linuc-shell- で始める）:
#   docker run -d --name linuc-shell-probe --hostname linuc \
#     -v linuc-shell-probe-work:/home/lab/work -v linuc-shell-probe-state:/home/lab/.lab \
#     lab-linuc-shell:1.0.2 sleep infinity
#   docker cp probe/linuc-shell-probe.sh linuc-shell-probe:/tmp/run.sh
#   docker exec -u lab -w /home/lab linuc-shell-probe bash /tmp/run.sh > logs/linuc-shell-probe.log 2>&1
#   docker rm -f linuc-shell-probe
#
# この主題は「いまどのシェルの中にいるか」で結果が変わる。だから本文の記録は、
# 読者の端末と同じ「対話するログインシェル」の中で打って取る（SESSION）。
#   - 疑似端末（script）の上で /bin/bash -l を起動する。docker run の CMD と同じ起動のしかた
#   - プロンプトを "$ " にして、記録が「$ コマンド」→ 出力 の形になるようにする
#     （PROMPT_COMMAND で毎回 "$ " に戻す。source ~/.bashrc で PS1 が戻されても崩れない）
#   - 入力は1行ずつ間を空けて打つ。"#sleep N" の行は打たずに N 秒待つ
#   - 端末の制御文字（行末の \r と色の指定）は落とす。画面に見える文字だけを残す
#   - 対話シェルでないと再現しないもの: alias の展開、$0 と $-、ログアウト時の表示、read -p の表示
# set -u は付けない（読者のシェルには付いていない）。
umask 022   # docker exec の umask は 0000、読者が入る docker run の端末は 0022（実測 2026-10-13）
R() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
S() { printf '\n\n========== %s ==========\n' "$*"; }
SESSION() {
  { sleep 1
    printf '%s\n' 'PROMPT_COMMAND='"'"'PS1="\$ "'"'"'; : __REC__'
    while IFS= read -r l; do
      case $l in "#sleep "*) sleep "${l#\#sleep }"; continue ;; esac
      sleep "${DELAY:-0.7}"; printf '%s\n' "$l"
    done
    sleep 1.5
  } | script -q -c "stty cols 200 rows 50; exec /bin/bash -l" /dev/null \
    | tr -d '\r' | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g; s/\x1b\][^\x07]*\x07//g' | sed '1,/__REC__/d'
}
# 入口の案内を、読者が docker run で入ったときと同じ形で記録する（exit を打つだけ）
BANNER() {
  { sleep 1.5; printf 'exit\n'; sleep 1; } \
    | script -q -c "stty cols 200 rows 50; exec /bin/bash -l" /dev/null \
    | tr -d '\r' | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g; s/\x1b\][^\x07]*\x07//g'
}

S "0. 環境"
R 'lab env'
printf '\n$ %s\n' '（docker run で入ったときの画面。/bin/bash -l が起動して、案内を出す）'
BANNER

S "1. 起動ファイルはシェルの生まれ方で決まる（1.06.1）"
SESSION <<'IN'
echo $0
shopt login_shell
echo $-
bash -l
#sleep 1
shopt login_shell
exit
bash
shopt login_shell
exit
grep -n -A6 'profile.d' /etc/profile
ls -1 /etc/profile.d/
head -3 /etc/profile.d/99-lab.sh
grep -E '^(lab|alice|bob):' /etc/passwd
grep SHELL /etc/default/useradd
sudo sed -i '1i echo "[/etc/profile]"' /etc/profile
sudo sed -i '1i echo "[/etc/bash.bashrc]"' /etc/bash.bashrc
sudo sed -i '1i echo "[~/.profile]"' /home/alice/.profile
sudo sed -i '1i echo "[~/.bashrc]"' /home/alice/.bashrc
sudo sed -i '1i echo "[~/.bash_logout]"' /home/alice/.bash_logout
sudo head -1 /etc/profile /etc/bash.bashrc /home/alice/.profile /home/alice/.bashrc /home/alice/.bash_logout
sudo -iu alice
#sleep 1.5
exit
#sleep 0.5
su - alice
#sleep 1
alice
#sleep 1.5
exit
#sleep 0.5
su alice
#sleep 1
alice
#sleep 1.5
pwd
exit
#sleep 0.5
sudo -iu alice
#sleep 1.5
bash
exit
exit
#sleep 0.5
sudo -iu alice true
sudo -u alice bash -c 'echo こんにちは'
sed -n '1,12p' /etc/profile
sudo grep -n -A5 'if running bash' /home/alice/.profile
sudo grep -n -B1 -A3 'not running interactively' /home/alice/.bashrc
sudo cat /home/alice/.bash_logout
exit
IN

S "1b. ~/.bash_profile を作ると ~/.profile が読まれなくなる（1.06.1）"
SESSION <<'IN'
sudo -iu alice
#sleep 1.5
ll -d ~
printf 'echo "[~/.bash_profile]"\nPATH="$HOME/bin:$PATH"\n' > ~/.bash_profile
cat ~/.bash_profile
exit
#sleep 0.5
sudo -iu alice
#sleep 1.5
ll -d ~
type ll
exit
#sleep 0.5
echo 'echo "[~/.bash_login]"' | sudo tee /home/alice/.bash_login
sudo -iu alice true
sudo rm /home/alice/.bash_profile
sudo -iu alice true
sudo rm /home/alice/.bash_login
sudo -iu alice true
printf 'echo "[~/.bash_profile]"\nPATH="$HOME/bin:$PATH"\n. ~/.profile\n' | sudo -u alice tee /home/alice/.bash_profile
sudo -iu alice
#sleep 1.5
ll -d ~
exit
#sleep 0.5
sudo sed -i '/^echo "\[.*\]"$/d' /etc/profile /etc/bash.bashrc /home/alice/.profile /home/alice/.bashrc /home/alice/.bash_logout
sudo rm /home/alice/.bash_profile
sudo -iu alice true
head -1 /etc/profile
exit
IN

S "2. 子のシェルは親を書き換えられない — source・export・PATH・alias（1.06.1）"
SESSION <<'IN'
mkdir -p ~/try && cd ~/try
echo "alias hi='echo やあ'" >> ~/.bashrc
tail -1 ~/.bashrc
hi
bash ~/.bashrc
hi
source ~/.bashrc
hi
type hi
x=1
bash -c 'echo "子から見た x=[$x]"'
export x
bash -c 'echo "子から見た x=[$x]"'
bash -c 'x=2; echo "子の中で x=$x"'; echo "親の x=$x"
declare -p x PATH
y=2; declare -p y
env | grep -E '^(x|y)='
cat > go.sh <<'END'
cd /tmp
export GREETING=やあ
END
bash go.sh; pwd; echo "GREETING=[$GREETING]"
. ./go.sh; pwd; echo "GREETING=[$GREETING]"
cd ~/try
type source .
sh -c '. ./go.sh; pwd'
sh -c 'source ./go.sh'
alias yo='echo よう'
yo
bash -ic yo
bash -ic hi
printf '#!/bin/bash\nhi\n' > usehi.sh
bash usehi.sh; echo "終了ステータス $?"
alias ll
type ll
unalias yo
yo
echo $PATH
type ls cd
cat > here.sh <<'END'
#!/bin/bash
echo "ここにいる"
END
chmod +x here.sh
here.sh
./here.sh
mkdir -p ~/bin && cp here.sh ~/bin/here
here
grep -n -A2 'HOME/bin' ~/.profile
. ~/.profile
echo $PATH
here
PATH="$PATH:$HOME/try"; echo $PATH
exit
IN

S "3. && と || は直前の数だけを見る — リストとコマンド置換（1.06.1）"
SESSION <<'IN'
mkdir -p ~/try && cd ~/try
true; echo $?
false; echo $?
cd /nonexistent; pwd
cd /nonexistent && pwd
mkdir /forbidden || echo "作れなかった"
grep -q '^alice:' /etc/passwd && echo いる || echo いない
mkdir newdir && cp /nonexistent newdir/ || echo "mkdir に失敗した"
ls -d newdir
mkdir newdir2 && { cp /nonexistent newdir2/ || echo "cp に失敗した"; }
echo "今日は $(date +%F)"
echo "わたしは `id -un`"
echo "外 $(echo "内 $(id -un)")"
n=$(wc -l < /etc/passwd); echo "passwd は $n 行"
ls -A1 /etc/skel
files=$(ls -A1 /etc/skel); echo $files
echo "$files"
x=1; y=$(x=2; echo $x); echo "x=$x y=$y"
v=$(false); echo "終了ステータス $?"
echo "[$(printf 'a\n\n\n')]"
(cd /tmp; pwd); pwd
{ cd /tmp; pwd; }; pwd
cd ~/try
exit
IN

S "4. 先頭行を読むのはカーネル — #!・chmod・chown・置き場所・PATH（1.06.2）"
SESSION <<'IN'
mkdir -p ~/try && cd ~/try
cat > hello.sh <<'END'
#!/bin/sh
function say {
    echo "こんにちは、$1"
}
say "$(id -un)"
echo "\$0 は $0"
END
ls -l hello.sh
./hello.sh; echo "終了ステータス $?"
bash hello.sh; echo "終了ステータス $?"
chmod +x hello.sh; ls -l hello.sh
./hello.sh; echo "終了ステータス $?"
head -1 hello.sh; ls -l /bin/sh
sh hello.sh; echo "終了ステータス $?"
sed -i '1s|.*|#!/bin/bash|' hello.sh; head -1 hello.sh
./hello.sh
sh hello.sh; echo "終了ステータス $?"
. ./hello.sh
type say
printf 'echo "BASH_VERSION=[$BASH_VERSION]"\n' > noshebang.sh; chmod +x noshebang.sh
./noshebang.sh
sh noshebang.sh
chmod 700 hello.sh; ls -l hello.sh
chmod u=rwx,go=rx hello.sh; ls -l hello.sh
chmod go-x hello.sh; ls -l hello.sh
chmod 755 hello.sh
hello.sh
sudo cp hello.sh /usr/local/bin/hello
ls -l /usr/local/bin/hello
hello
sudo -u alice hello
sudo chmod 711 /usr/local/bin/hello; ls -l /usr/local/bin/hello
sudo -u alice hello; echo "終了ステータス $?"
sudo cp /usr/bin/id /usr/local/bin/myid; sudo chmod 711 /usr/local/bin/myid; ls -l /usr/local/bin/myid
sudo -u alice myid -un
sudo chmod 755 /usr/local/bin/hello
chown lab /usr/local/bin/hello
sudo chown alice:alice /usr/local/bin/hello; ls -l /usr/local/bin/hello
sudo chown root:root /usr/local/bin/hello; ls -l /usr/local/bin/hello
cat > report.sh <<'END'
#!/bin/bash
echo "作成日: $(date +%F)"
END
sudo cp report.sh /usr/local/bin/report; sudo chmod 755 /usr/local/bin/report
sudo -u alice mkdir /home/alice/bin
printf '#!/bin/sh\necho "1999-12-31"\n' | sudo -u alice tee /home/alice/bin/date
sudo chmod 755 /home/alice/bin/date
report
sudo -u alice report
sudo -iu alice report
sudo -iu alice bash -c 'echo $PATH'
su - alice
#sleep 1
alice
#sleep 1.5
echo $PATH
type date
report
exit
#sleep 0.5
sed -i '1a PATH=/usr/bin:/bin' report.sh; head -2 report.sh
sudo cp report.sh /usr/local/bin/report
sudo -iu alice report
exit
IN

S "5. 引数は渡す側で切られている — \$0 \$1 \$# \$@ \$* shift（1.06.2）"
SESSION <<'IN'
mkdir -p ~/try && cd ~/try
cat > args.sh <<'END'
#!/bin/bash
echo "\$0 = $0"
echo "\$# = $#"
echo "\$1 = $1"
echo "\$2 = $2"
echo '--- for a in "$@"'
for a in "$@"; do echo "[$a]"; done
echo '--- for a in "$*"'
for a in "$*"; do echo "[$a]"; done
echo '--- for a in $*'
for a in $*; do echo "[$a]"; done
END
chmod +x args.sh
./args.sh "my file.txt" b
./args.sh my file.txt b
touch "my file.txt"
cat > cpall.sh <<'END'
#!/bin/bash
cp $* /tmp/
END
bash cpall.sh "my file.txt"; echo "終了ステータス $?"
sed -i 's/\$\*/"$@"/' cpall.sh; cat cpall.sh
bash cpall.sh "my file.txt"; ls -l "/tmp/my file.txt"
cat > ten.sh <<'END'
#!/bin/bash
echo "\$# = $#"
echo "\$10 = $10"
echo "\${10} = ${10}"
END
bash ten.sh a b c d e f g h i j
cat > sh.sh <<'END'
#!/bin/bash
echo "はじめ:     \$# = $#  \$1 = $1  \$@ = $@"
shift
echo "shift 後:   \$# = $#  \$1 = $1  \$@ = $@"
shift 2
echo "shift 2 後: \$# = $#  \$1 = $1"
shift 5
echo "shift 5 の終了ステータス = $?  \$# = $#"
END
bash sh.sh a b c d
cat > each.sh <<'END'
#!/bin/bash
while [ $# -gt 0 ]; do
    echo "残り $# 個: [$1]"
    shift
done
END
bash each.sh one "two three" four
set -- x "y z"; echo $#; echo "$2"
cat > need.sh <<'END'
#!/bin/bash
if [ $# -ne 1 ]; then
    echo "使い方: $(basename "$0") 名前" >&2
    exit 1
fi
echo "こんにちは、$1"
END
bash need.sh; echo "終了ステータス $?"
bash need.sh alice
bash need.sh alice bob 2> /dev/null; echo "終了ステータス $?"
exit
IN

S "6. 返せるのは 0〜255 の数1つ — \$? exit test if（1.06.2）"
SESSION <<'IN'
mkdir -p ~/try && cd ~/try
ls /nonexistent; echo $?
echo $?
grep -q lab /etc/passwd; echo $?
grep -q nosuchuser /etc/passwd; echo $?
grep -q lab /nonexistent; echo $?
nosuchcommand; echo $?
printf '#!/bin/bash\nexit 3\n' > ret.sh; bash ret.sh; echo $?
sed -i 's/exit 3/exit 255/' ret.sh; bash ret.sh; echo $?
sed -i 's/exit 255/exit 256/' ret.sh; cat ret.sh; bash ret.sh; echo $?
sed -i 's/exit 256/exit 257/' ret.sh; bash ret.sh; echo $?
bash -c 'exit -1'; echo $?
printf '#!/bin/bash\nls /nonexistent\necho おわり\n' > last.sh; bash last.sh; echo "終了ステータス $?"
test -f /etc/passwd; echo $?
[ -f /etc/passwd ]; echo $?
[ -d /etc/passwd ]; echo $?
[ -e /nonexistent ]; echo $?
[ ! -e /nonexistent ]; echo $?
[ -r /etc/shadow ]; echo $?
[ -x /usr/bin/ls ]; echo $?
[ -s /etc/passwd ]; echo $?
[ -z "" ]; echo $?; [ -n "" ]; echo $?
[ 1 -eq 01 ]; echo $?; [ 1 = 01 ]; echo $?
[ 10 -gt 9 ]; echo $?; [ 10 \> 9 ]; echo $?
[ "abc" != "abd" ]; echo $?
x=; [ $x = yes ]; echo $?
[ "$x" = yes ]; echo $?
[1 -eq 1]; echo $?
type [ test [[
ls -l /usr/bin/[ /usr/bin/test
cat > kind.sh <<'END'
#!/bin/bash
if [ -d "$1" ]; then
    echo "$1 はディレクトリ"
elif [ -f "$1" ]; then
    echo "$1 はふつうのファイル"
else
    echo "$1 は見つからない"
    exit 1
fi
END
bash kind.sh /etc; bash kind.sh /etc/passwd; bash kind.sh /nonexistent; echo "終了ステータス $?"
if grep -q '^alice:' /etc/passwd; then echo "alice は居る"; fi
[ -f /etc/passwd ] && [ -r /etc/passwd ] && echo "読める"
[ -f /etc/passwd -a -r /etc/shadow ]; echo $?
exit
IN

S "7. パイプの先で数えた数は持ち帰れない — for while case read seq（1.06.2）"
SESSION <<'IN'
mkdir -p ~/try && cd ~/try
for i in 1 2 3; do echo "i=$i"; done
for f in /etc/host*; do echo "$f"; done
seq 3
seq 2 5
seq 1 2 9
seq -w 8 10
seq -s , 5
for i in $(seq 1 3); do echo "$i 回目"; done
for ((i = 0; i < 3; i++)); do echo "i=$i"; done
n=0; while [ $n -lt 3 ]; do echo "n=$n"; n=$((n + 1)); done
until [ $n -eq 0 ]; do n=$((n - 1)); echo "n=$n"; done
printf 'alice\nbob\ncarol\n' > names.txt
while read -r name; do echo "名前: $name"; done < names.txt
cat > count.sh <<'END'
#!/bin/bash
n=0
cat names.txt | while read -r name; do
    n=$((n + 1))
    echo "読んだ: $name (n=$n)"
done
echo "合計: $n"
END
bash count.sh
cat > count2.sh <<'END'
#!/bin/bash
n=0
while read -r name; do
    n=$((n + 1))
done < names.txt
echo "合計: $n"
END
bash count2.sh
read a b c <<< "1 2 3 4 5"; echo "a=$a b=$b c=$c"
IFS=: read -r user pw uid rest < /etc/passwd; echo "$user の UID は $uid"
cat > yn.sh <<'END'
#!/bin/bash
read -p "続けますか? [y/n] " ans
case "$ans" in
    [yY]|[yY][eE][sS]) echo "続けます" ;;
    [nN]*)             echo "やめます" ;;
    *)                 echo "y か n で答えてください"; exit 1 ;;
esac
END
bash yn.sh
#sleep 0.5
yes
echo No | bash yn.sh
echo maybe | bash yn.sh; echo "終了ステータス $?"
for i in 1 2 3 4 5; do [ $i -eq 2 ] && continue; [ $i -eq 4 ] && break; echo $i; done
exit
IN

S "8. 関数は子ではない — function local return bash -x bash -v（1.06.2）"
SESSION <<'IN'
mkdir -p ~/try && cd ~/try
wave() { echo "やあ、$1"; }
wave alice
type wave
function bye { echo "またね、$1"; }
bye bob
bash -c 'wave alice'; echo "終了ステータス $?"
cat > fn.sh <<'END'
#!/bin/bash
greet() {
    local who=$1
    echo "こんにちは、$who（関数の中で \$0 = $0、\$# = $#）"
    return 3
}
greet alice bob
echo "greet の終了ステータス = $?"
echo "関数の外で who = [$who]"
END
bash fn.sh
cat > ex.sh <<'END'
#!/bin/bash
stop() { echo "関数の中で exit します"; exit 5; }
stop
echo "ここは表示されない"
END
bash ex.sh; echo "終了ステータス $?"
cat > number.sh <<'END'
#!/bin/bash
line() {
    for ((i = 0; i < 20; i++)); do printf '-'; done
    printf '\n'
}
i=1
for name in "$@"; do
    echo "$i: $name"
    line
    i=$((i + 1))
done
END
bash number.sh alice bob carol
bash -x number.sh alice bob 2>&1 | head -12
bash -x number.sh alice bob 2>&1 | grep -E '^\+ (i=|echo)'
bash -v number.sh alice 2>&1 | head -14
sed -i '/^line() {/a\    local i' number.sh; sed -n '2,6p' number.sh
bash number.sh alice bob carol
set -x; echo "$HOME"; set +x
exit
IN

S "9. 最終環境"
R 'lab env'
