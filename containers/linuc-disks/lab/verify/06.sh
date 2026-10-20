#!/usr/bin/env bash
# 演習 06 の判定。観測型（student として実際に mount と umount を打ち、結果を見る）。
# すでにマウントされていたら、先に root で外してから確かめる（誰がマウントしたかで umount の可否が変わるため）。
set -uo pipefail
lab-guest true >/dev/null 2>&1
[ $? -eq 125 ] && { echo "前提不足: 練習機が起動していません（外で vm start）"; exit 2; }
media=$(lab-guest 'blkid -p -o value -s TYPE /dev/sr0 2>/dev/null' 2>/dev/null)
if [ "$media" != iso9660 ]; then
  echo "前提不足: 光学ドライブ（/dev/sr0）にメディアが入っていません"
  echo "          外で: virsh change-media linuc sdb /usr/share/lab-disks/linuc-media.iso --insert"
  exit 2
fi

line=$(lab-guest 'findmnt --fstab -n -o SOURCE,FSTYPE,OPTIONS --target /media/cdrom 2>/dev/null' 2>/dev/null)
pre=$(lab-guest 'if findmnt /media/cdrom >/dev/null 2>&1; then umount /media/cdrom && echo 外した; fi' 2>/dev/null)
m=$(lab-guest -u student 'mount /media/cdrom 2>&1; echo "rc=$?"' 2>/dev/null)
m_rc=$(sed -n 's/^rc=//p' <<<"$m"); m_msg=$(sed '/^rc=/d' <<<"$m")
opts=$(lab-guest 'findmnt -n -o OPTIONS /media/cdrom 2>/dev/null' 2>/dev/null)
readme=$(lab-guest -u student 'head -1 /media/cdrom/README.TXT 2>/dev/null' 2>/dev/null)
u=$(lab-guest -u student 'umount /media/cdrom 2>&1; echo "rc=$?"' 2>/dev/null)
u_rc=$(sed -n 's/^rc=//p' <<<"$u"); u_msg=$(sed '/^rc=/d' <<<"$u")
# student が外せなかったときに、マウントしたまま残さない
lab-guest 'findmnt /media/cdrom >/dev/null 2>&1 && umount /media/cdrom' >/dev/null 2>&1

echo "判定 : 観測型（student として mount /media/cdrom と umount /media/cdrom を実際に打った）"
[ -n "$pre" ] && echo "       （判定の前にマウントされていたので、root で外してから確かめた）"
echo "観測 : /etc/fstab の行       = ${line:-（/media/cdrom の行が無い）}"
echo "       student の mount      = $([ "$m_rc" = 0 ] && echo 成功 || echo "失敗: ${m_msg:-?}")"
if [ "$m_rc" = 0 ]; then
  echo "       マウントのオプション  = ${opts:-?}"
  echo "       README.TXT の1行目    = ${readme:-（読めない）}"
  echo "       student の umount     = $([ "$u_rc" = 0 ] && echo 成功 || echo "失敗: ${u_msg:-?}")"
fi
ng=0
[ "$m_rc" = 0 ] || ng=1
if [ "$m_rc" = 0 ]; then
  case ",$opts," in *,ro,*) ;; *) echo "       → 読み書きできる形でマウントされた（ro ではない）"; ng=1;; esac
  [ -n "$readme" ] || { echo "       → マウントしたが中身が読めない"; ng=1; }
  [ "$u_rc" = 0 ] || ng=1
fi
# 起動時に勝手にマウントしないか（noauto）は、再起動しないと観測できないので fstab の行のオプションで見る
case ",$(awk '{print $3}' <<<"$line")," in *,noauto,*) ;;
  *) [ -n "$line" ] && echo "       → /etc/fstab の行に noauto が無い（起動時にマウントされる）"; ng=1;; esac
[ "$ng" = 0 ] || exit 1
echo "       一般ユーザが、自分でマウントして読み、自分で外せた"
echo "       → 許したのは sudo ではなく、/etc/fstab の行に書いたオプション"
exit 0
