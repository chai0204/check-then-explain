#!/bin/bash
# LinuC 主題1.06 の本文を、読者と同じ打ち方で第1章から第8章まで通して打った記録。
#
# 読者は docker run の PID 1 の bash -l の中で、章をまたいで同じシェルのまま打つ（PID 1 で exit すると
# コンテナごと消えるので、入り直さない）。章ごとに新しいシェルで取った記録（linuc-shell-probe.sh など）では、
# 章をまたいで残る状態（PATH・alias・関数・変数・cd 先）の影響が見えない。そこで本文の端末ブロックに出てくる
# 「読者が打つもの」を本文の順に1つのシェルへ打ち込み、本文の出力と同じになるかを確かめる（2026-10-13）。
#
# 入力は本文（public/linuc-shell/theory/01〜08）から seqinput.py で書き出したもので、手で足したものは無い。
#   - "$ " の行・"> " の続きの行・入れ子のシェルで打った行・su のパスワード・read -p への答え
#   - "# ==== 章のファイル名 ====" は区切りのためのコメント（bash は何もしない）
#   - "#sleep N" は打たずに待つ（ログインや su の後）。最後の exit は記録を終えるためのもの（第8章の後）
# 記録の取り方（読者と同じ --hostname とボリューム2つで起動する。ボリュームは既存の probe4 を使い回す）:
#   docker run -d --name linuc-shell-probe4 --hostname linuc \
#     -v linuc-shell-probe4-work:/home/lab/work -v linuc-shell-probe4-state:/home/lab/.lab \
#     lab-linuc-shell:1.0.2 sleep infinity
#   docker cp probe/linuc-shell-seq.sh linuc-shell-probe4:/tmp/run.sh
#   docker exec -u lab -w /home/lab linuc-shell-probe4 bash /tmp/run.sh > logs/linuc-shell-seq.log 2>&1
#   docker rm -f linuc-shell-probe4
umask 022   # docker exec の umask は 0000、読者が入る docker run の端末は 0022
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
printf '\n\n========== %s ==========\n' "第1章から第8章まで、1つのログインシェルで通して打つ"
SESSION <<'IN'
# ==== 01-startup.html ====
echo $0
shopt login_shell
echo $-
bash -l
#sleep 1
shopt login_shell
exit
#sleep 0.5
bash
shopt login_shell
exit
#sleep 0.5
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
#sleep 0.5
exit
#sleep 0.5
sudo -iu alice true
sudo -u alice bash -c 'echo こんにちは'
MANWIDTH=80 man bash | grep -A6 'invoked as an interactive login shell'
sed -n '1,12p' /etc/profile
sudo grep -n -A5 'if running bash' /home/alice/.profile
sudo grep -n -B1 -A3 'not running interactively' /home/alice/.bashrc
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
MANWIDTH=80 man bash | grep -A2 'When an interactive login shell exits'
sudo cat /home/alice/.bash_logout
sudo sed -i '/^echo "\[.*\]"$/d' /etc/profile /etc/bash.bashrc /home/alice/.profile /home/alice/.bashrc /home/alice/.bash_logout
sudo rm /home/alice/.bash_profile
sudo -iu alice true
head -1 /etc/profile
# ==== 02-source.html ====
mkdir -p ~/try && cd ~/try
echo "alias hi='echo やあ'" >> ~/.bashrc
tail -1 ~/.bashrc
hi
bash ~/.bashrc
hi
cp ~/.bashrc /tmp/bashrc.copy; echo 'alias hi' >> /tmp/bashrc.copy
bash /tmp/bashrc.copy; echo "終了ステータス $?"
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
export z=3; bash -c 'echo "z=[$z]"'
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
bash -c 'shopt expand_aliases'
bash -ic 'shopt expand_aliases'
printf 'alias hi3="echo alias が展開された"\nhi3\n' > a.sh
bash a.sh; echo "終了ステータス $?"
printf 'shopt -s expand_aliases\nalias hi3="echo alias が展開された"\nhi3\n' > a2.sh
bash a2.sh
sh a.sh
bash --posix a.sh
alias ls='ls -l'
ls -d /etc
\ls -d /etc
command ls -d /etc
/usr/bin/ls -d /etc
unalias ls
alias ls
alias ls='ls --color=auto'
alias ll = 'ls -l'; echo "終了ステータス $?"
x = 1
x=no; [ "$x"="yes" ] && echo "空白が無いと、いつも真"
[ "$x" = "yes" ] || echo "空白があれば、正しく偽"
echo "alias zz='echo /etc/profile で定義した alias'" | sudo tee -a /etc/profile
bash -l -c 'alias zz'
bash -c 'alias zz'
sudo sed -i '/^alias zz=/d' /etc/profile; tail -1 /etc/profile
grep -n -E '^ *(PS1|HISTSIZE)=' ~/.bashrc
echo 'HISTSIZE=0' >> ~/.bashrc
HISTFILE=/tmp/hist-demo bash
echo 履歴に残すか
history
exit
#sleep 0.5
ls -l /tmp/hist-demo
sed -i '/^HISTSIZE=0$/d' ~/.bashrc
HISTFILE=/tmp/hist-demo2 bash
echo 履歴に残すか
exit
#sleep 0.5
cat /tmp/hist-demo2
echo $PATH
type ls cd
MANWIDTH=80 man bash | grep -A10 'If the command name contains no slashes'
type -a echo
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
OLDPATH=$PATH
PATH="$PATH:$HOME/try"; echo $PATH
PATH=$OLDPATH; echo $PATH
(PATH="/usr/bin;/opt/tools/bin"; echo "$PATH"; ls /)
$PATH=$PATH:/opt/tools/bin
# ==== 03-lists.html ====
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
echo "外 `echo \`id -un\``"
ls -A1 /etc/skel
files=$(ls -A1 /etc/skel); echo $files
echo "$files"
x=1; y=$(x=2; echo $x); echo "x=$x y=$y"
v=$(false); echo "終了ステータス $?"
echo "[$(printf 'a\n\n\n')]"
(cd /tmp; pwd); pwd
{ cd /tmp; pwd; }; pwd
cd ~/try
# ==== 04-script.html ====
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
mkdir -p fbin
printf '#!/bin/sh\necho "function が受け取った引数: $# 個: $*"\n' > fbin/function; chmod +x fbin/function
PATH="$HOME/try/fbin:$PATH" sh hello.sh
sed -i '1s|.*|#!/bin/bash|' hello.sh; head -1 hello.sh
./hello.sh
sh hello.sh; echo "終了ステータス $?"
. ./hello.sh
type say
printf 'echo "BASH_VERSION=[$BASH_VERSION]"\n' > noshebang.sh; chmod +x noshebang.sh
./noshebang.sh
sh noshebang.sh
sh -c ./noshebang.sh
chmod 700 hello.sh; ls -l hello.sh
chmod u=rwx,go=rx hello.sh; ls -l hello.sh
chmod go-x hello.sh; ls -l hello.sh
chmod 755 hello.sh
(umask 077; chmod 644 hello.sh; chmod +x hello.sh; ls -l hello.sh)
(umask 077; chmod 644 hello.sh; chmod a+x hello.sh; ls -l hello.sh)
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
sudo usermod -aG staff alice; id alice
sudo -u alice bash -c umask
sudo -u alice bash -c 'cd /tmp && touch g.txt && chgrp staff g.txt && ls -l g.txt'
sudo -u alice bash -c 'cd /tmp && chown :alice g.txt && ls -l g.txt'
sudo -u alice bash -c 'cd /tmp && chgrp lab g.txt'
sudo -u alice bash -c 'cd /tmp && chown lab g.txt'
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
# ==== 05-args.html ====
mkdir -p ~/try && cd ~/try
touch "my file.txt"
cat > cpall.sh <<'END'
#!/bin/bash
cp $* /tmp/
END
bash cpall.sh "my file.txt"; echo "終了ステータス $?"
sed -i 's/\$\*/"$@"/' cpall.sh; cat cpall.sh
bash cpall.sh "my file.txt"; ls -l "/tmp/my file.txt"
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
set -- "my file.txt" b; for a in $@; do echo "[$a]"; done
cat > ten.sh <<'END'
#!/bin/bash
echo "\$# = $#"
echo "\$10 = $10"
echo "\${10} = ${10}"
END
bash ten.sh a b c d e f g h i j
a=(x y z)
echo ${a[1]}
echo $a[1]
echo $a
echo ${a[@]}; echo ${#a[@]}
sh -c 'a=(x y z)'
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
sh sh.sh a b c d; echo "終了ステータス $?"
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
# ==== 06-status.html ====
mkdir -p ~/try && cd ~/try
ls /nonexistent; echo $?
echo $?
grep -q lab /etc/passwd; echo $?
grep -q nosuchuser /etc/passwd; echo $?
grep -q lab /nonexistent; echo $?
nosuchcommand; echo $?
expr 2 + 3; echo "終了ステータス $?"
expr 2 - 2; echo "終了ステータス $?"
expr 3 \* 4
i=0; i=$(expr $i + 1); echo $i
expr --help | grep -A1 'Exit status'
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
bash -c 'exit 300'; echo $?
# ==== 07-loops.html ====
mkdir -p ~/try && cd ~/try
for i in 1 2 3; do echo "i=$i"; done
for f in /etc/host*; do echo "$f"; done
seq 3
seq 2 5
seq 1 2 9
seq -w 8 10
seq -s , 5
for i in $(seq 1 3); do echo "$i 回目"; done
printf '1\n2\n' > list.txt; for x in $(cat list.txt); do echo "$x"; echo 9 >> list.txt; done; cat list.txt
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
printf '%s\n' 'C:\temp' | { read p; echo "$p"; }
printf '%s\n' 'C:\temp' | { read -r p; echo "$p"; }
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
seq 1 2 10
case restart in start) echo "start に当たった" ;; *) echo "その他に入った" ;; esac
# ==== 08-function.html ====
mkdir -p ~/try && cd ~/try
wave() { echo "やあ、$1"; }
wave alice
type wave
function bye { echo "またね、$1"; }
bye bob
bash -c 'wave alice'; echo "終了ステータス $?"
function hi2() { echo "function と () を両方付けても書ける"; }
hi2
sh -c 'function f() { echo x; }; f'
date() { echo "関数の date が先に動いた"; }
date
type date
unset -f date
type date
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
