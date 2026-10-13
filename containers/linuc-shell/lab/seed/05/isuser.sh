#!/bin/bash
# 使い方: isuser.sh ユーザ名
# そのユーザが /etc/passwd に居れば 0、居なければ 1 で終わる。
# 引数が無ければ 2 で終わる。
grep "^$1:" /etc/passwd > /dev/null
echo "調べました: $1"
