#!/usr/bin/env bash
# 演習 07 の判定。観測型（ex07 に渡した特権の一覧を尋ね、ex07 の中で実際に仮想の NIC を作って消す）。外（lab@host）で走り、練習機の中は lab-guest（qemu-guest-agent 経由・root）で見る。
set -uo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session   # ログインシェルの値に引きずられないよう固定する
prereq() { echo "前提不足: 練習機が応答しません（起動の途中か、止まっている）。外で vm start を打ち、起動を待ってからもう一度"; exit 2; }
# 練習機に届くかを先に1回だけ確かめる。lab-guest は届かないとき 125 を返すが、podman や docker run も
# 自分の失敗に 125 を使うので、コマンドごとの 125 を「届かない」と読むと取り違える（実測: podman inspect の「無い」が 125）
lab-guest true >/dev/null 2>&1 || prereq

st=$(lab-guest "docker inspect -f '{{.State.Running}} {{.HostConfig.Privileged}} {{json .HostConfig.CapAdd}} {{.HostConfig.NetworkMode}} {{json .HostConfig.SecurityOpt}}' ex07" 2>&1); rc=$?
echo "判定 : 観測型（ex07 に渡した特権の一覧を尋ね、ex07 の中で仮想の NIC を作って消した）"
if [ $rc -ne 0 ]; then
  echo "観測 : ex07 という名前のコンテナが無い"
  exit 1
fi
read -r running priv capadd netmode secopt <<<"$st"
echo "観測 : ex07 動いている=$running / --privileged=$priv / 足したケーパビリティ=$capadd / 網=$netmode / 制限の解除=$secopt"
[ "$running" = true ] || { echo "       動いていない"; exit 1; }
[ "$priv" = false ] || { echo "       --privileged で起動している（全部を渡している）"; exit 1; }
[ "$netmode" != host ] || { echo "       --network host で、練習機の網をそのまま使っている（作った NIC は練習機の網に入る）"; exit 1; }
case "$secopt" in
  *unconfined*|*disable*) echo "       --security-opt で seccomp・AppArmor などの制限を外している（--privileged が外すものの一部）"; exit 1 ;;
esac
n=$(tr -cd ',' <<<"$capadd" | wc -c)
[ "$capadd" != null ] && [ "$n" -eq 0 ] || { echo "       足したケーパビリティが1つではない"; exit 1; }
eff=$(lab-guest "docker exec ex07 grep CapEff /proc/1/status" 2>/dev/null | awk '{print $2}')
try=$(lab-guest 'docker exec ex07 sh -c "ip link add labchk0 type dummy && ip link del labchk0 && echo ok"' 2>&1 | tail -1)
echo "       ex07 の PID 1 の CapEff=$eff / 中で ip link add … type dummy → $try"
[ -n "$eff" ] || { echo "       ex07 の PID 1 の CapEff を読めない"; exit 1; }
# NET_ADMIN（0x1000）が立っていて、既定 + NET_ADMIN（0xa80435fb）の外のビットが無いこと（--cap-drop で減らすのはよい）
if ! (( (16#$eff & 16#1000) != 0 && (16#$eff & ~16#a80435fb) == 0 )); then
  case "$capadd" in
    *ALL*) echo "       ALL は1つではなく全部のケーパビリティを足す（CapEff が全部の 000001ffffffffff になる）" ;;
    *)     echo "       CapEff に CAP_NET_ADMIN が無いか、既定（00000000a80425fb）と CAP_NET_ADMIN の外の特権が入っている" ;;
  esac
  exit 1
fi
[ "$try" = ok ] || exit 1
echo "       → ケーパビリティを1つだけ足して、ネットワークの設定が通った"
exit 0
