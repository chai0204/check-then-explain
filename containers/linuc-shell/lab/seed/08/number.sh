#!/bin/bash
# 引数で渡した名前を、番号付きで1行ずつ表示する。名前の下に区切り線を引く。
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
