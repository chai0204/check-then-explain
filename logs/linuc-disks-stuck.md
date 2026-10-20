# LinuC 主題1.05（linuc-disks 1.1.0）— 「ふつうこう考える」の出どころ

各章の `div.naive` は、著者が練習機で実際にそう打って外れた記録だけから作った（創作した誤答は書かない。
prompts.md §3.2・§3.4）。打った記録は、本文と同じ打ち方で取った通しの記録
`logs/linuc-disks-seq.log` の、その章の節にそのまま入っている（本文の出力はそこから写した）。

| 章 | 予想 | 打ったもの | 実際に起きたこと | 最初に詰まった記録 |
|---|---|---|---|---|
| 1 | `df` に装置の名前を渡せば、その装置の空きが分かる | `df -h /dev/vdb` | `/dev` の devtmpfs の行が返った（`df` はファイルの置き場所のファイルシステムを答える） | 1.1.0 の章立ての下調べ（2026-10-20） |
| 2 | マウントした `/mnt` に書けば `vdb1` に保存される | `echo … > /mnt/memo.txt` | `Permission denied`。作ったばかりの ext4 のいちばん上は root のもの | 同上（第2章の流れを student で打った） |
| 3 | 区画を消せば中身も消え、作り直しても空 | `fdisk` の `d`・`w` のあと、同じ位置に `n` で作り直す | 第2章の `memo.txt` がそのまま読めた。`fdisk` が ext4 の印を消すかと聞いた | 同上 |
| 4 | `parted` も、`quit` で抜ければ何も変わらない | `parted` の対話で `rm 6` → `quit` | 6番は表から消えていた（打った瞬間に書く） | 1.0.x の下調べ（第3章 parted）を 1.1.0 で打ち直した |
| 5 | Size − Used = Avail | `df -h`・`df -m`（vdb6 の ext4） | 26MiB 合わない。root 用の予約 5% と ext4 自身の取り置き（reserved_clusters） | 1.0.x（旧第6章）。取り置きの分は 1.1.0 で `tune2fs -l` と `/sys/fs/ext4` で突き止めた |
| 6 | `/dev/sdb` はいつも A の USB メモリ | A を抜いて B を挿し、A を挿し直して `mount /dev/sdb` | B（ext4、STICK_B）がマウントされた | 1.0.x（旧第8章） |
| 7 | ラベルで指せばいつも安全 | `e2label /dev/vdb2 BOOT` | 練習機の `/etc/fstab` の `LABEL=BOOT` が vdb2 を指した。`findmnt --verify` は種類の食い違いしか言わない | 1.0.x の旧第6章は vdb2 の ext3 に BOOT と付けていた。1.1.0 の下調べで、それが練習機自身の `/etc/fstab` の `LABEL=BOOT` と重なっていたと気づいた（1.1.0 では第5章で NEWBOOT と付け、第7章で意図して重ねて戻す） |
| 8 | tmpfs は size だけメモリを取る | `mount -t tmpfs -o size=4G`（メモリ 1.4GiB） | マウントでき、`free` はほぼ動かない | 1.0.x（旧第7章） |
| 9 | LV を広げれば使える量も増える | `lvextend -L +800M` のあと `df` | 箱は 1.37GiB、`df` は 574M のまま | 1.0.x（旧第5章） |
| 10 | 同じ種類のファイルなら ROTA も同じ | `lsblk -d -o …,ROTA,…` | sda だけ 0（SATA の申告 `rotation_rate='1'`） | 1.0.x（旧第1章） |
| 11 | ドライバを外せば、挿し直しても使えない | `modprobe -r uas` のあと抜き差し | `usb_storage`・`uas` が戻り、sdb ができた（udev が modalias で読み込む） | 1.0.x（旧第2章） |

## 1.1.0 で本文に足した、詰まった記録（div.naive にはしていないもの）

- `lsblk` の見出しが2行に割れる（NAME の列の中身が見出しより短いとき、NAME より後ろの見出しが次の行に回る。`findmnt` の TARGET も同じ。端末に出すときだけ）。第3章・第10章に注記した
- `insmod udf` が `Unknown symbol in module` で失敗し、理由は `dmesg` にしか出ない。第11章に入れた
- `/etc/modprobe.d` の既存ファイルの中身を `tee` や `>` で書き換えても udev が気づかない（ファイルを足す・消す、`sed -i` のように置き換えるのは気づく）。第11章に入れた
- `blacklist usb_storage` だけでは、`uas` の依存として読み込まれる。第11章に入れた
- 光学ドライブからメディアを抜いても `lsblk` の SIZE が前の大きさのまま。第10章に入れた
- `sudo reboot` の直後に `vm start` を打つと、止まりかけの練習機に入って切れることがある。第7章に「20 秒ほど待つ」と書いた
- `gdisk` で区切った直後の `lsblk` で FSTYPE・PARTTYPENAME が空のことがある（udev が読み終わる前）。記録の道具は区画の表を書いたあと 3 秒待つ（読者の手の速さと同じくらい）
