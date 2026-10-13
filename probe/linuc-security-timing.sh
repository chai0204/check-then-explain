#!/bin/bash
# 補足の記録（logs/linuc-security-xtra.log）。第8章の「RSA 4096 の鍵生成は数秒、ed25519 は一瞬」の裏付け。
# 時間は機械と KVM の有無で大きく変わるので、本文の端末ブロックには載せず、散文の根拠としてだけ残す。
# 練習機の中の対話ログインシェル（probe/linuc-security-drv.py）で3回ずつ測る。
#   docker cp probe/linuc-security-drv.py    <probe コンテナ>:/tmp/drv.py
#   docker cp probe/linuc-security-timing.sh <probe コンテナ>:/tmp/timing.sh
#   docker exec -u lab <probe コンテナ> bash -l /tmp/timing.sh > logs/linuc-security-xtra.log 2>&1
set -u
f=$(mktemp)
cat > "$f" <<'EOF'
TIMEFORMAT='%R 秒（rsa 4096）'; for i in 1 2 3; do rm -f /tmp/t_rsa /tmp/t_rsa.pub; time ssh-keygen -q -t rsa -b 4096 -N '' -f /tmp/t_rsa; done
TIMEFORMAT='%R 秒（ed25519）'; for i in 1 2 3; do rm -f /tmp/t_ed /tmp/t_ed.pub; time ssh-keygen -q -t ed25519 -N '' -f /tmp/t_ed; done
rm -f /tmp/t_rsa /tmp/t_rsa.pub /tmp/t_ed /tmp/t_ed.pub
EOF
chmod 644 "$f"
printf '========== 8. 鍵の生成時間（1.0.1・KVM なしの TCG） ==========\n'
scp -q /tmp/drv.py linuc:/tmp/drv.py
scp -q "$f" linuc:/tmp/gi-timing.txt
ssh linuc "python3 /tmp/drv.py /tmp/gi-timing.txt"
rm -f "$f"
