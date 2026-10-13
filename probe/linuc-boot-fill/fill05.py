import pathlib as _pl, sys as _sys
_HERE = _pl.Path(__file__).resolve().parent
REPO = _HERE.parent.parent
_sys.path.insert(0, str(_HERE))
import re, sys
from bootlog import chunk, pre
G = '練習機の中（student@linuc）'
P = str(REPO / 'public/linuc-boot/theory/05-boot.html')
R = 'ブートの中継を、練習機の中から見る'
esp = pre(G, chunk('05', R, 'findmnt -n -o TARGET,FSTYPE,OPTIONS /boot/efi', 'sudo cat /boot/efi/EFI/ubuntu/grub.cfg'))
_a = chunk('05', R, 'systemd-analyze', 'systemd-analyze', raw=True)
_total = float(re.search(r'= ([\d.]+)s', _a).group(1))
analyze = f'''<p><code>systemd-analyze</code> は、カーネルと initramfs の段（kernel）と、systemd が既定のターゲットに着くまで（userspace）の時間を分けて出す。この練習機は KVM を使わないので、合わせて {round(_total)} 秒ほどかかった。</p>
<p>起動の途中にカーネルがコンソールへ書いた行（第1章・この章の始めの <code>[    0.000000] Linux version …</code> など）は、起動した後でも <code>dmesg</code> で読み返せる。
カーネルが自分の記録（リングバッファ）に残しているからである。</p>
{pre(G, chunk('05', R, 'dmesg | head -3', "sudo dmesg | grep -E 'Linux version|Command line|Run /init'"))}
<p>Ubuntu は、カーネルの記録を一般ユーザには読ませない設定なので、<code>sudo</code> を付けて読む。コンソールで見たカーネルの版・引数・<code>Run /init</code> の行が、同じ時刻の印（起動からの秒数）で残っている。</p>'''
BLOCKS = {'ESP': esp, 'ANALYZE': analyze}
if __name__ == '__main__':
    import bootfill
    bootfill.apply(P, BLOCKS)
    print('ok')
