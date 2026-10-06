# 壊して覚える — 手を動かして仕組みを見る技術教材

本文のコマンドが、読者の画面に**本文と同じ文字を出す**ことを約束するシリーズ。
そのためにイメージのダイジェストと apt の時刻を固定し、載せる出力はすべて
そのイメージの中で実際に打った記録にしている。

設計の正本は `~/life/works/learning-series/`（private）。

## いま読めるもの

| テーマ | 内容 | 規模 |
|---|---|---|
| SQLite | サーバのいないデータベースがどこまで普通のファイルなのか | 理論5章 + 演習5本 / 約2時間 |
| WASM | 41バイトのバイナリを手で書いて、それが何もできないことを確かめる | 理論5章 + 演習5本 / 約2時間20分 |

## 構成

```
public/                  サイト（素の HTML。ビルドステップなし）
├── index.html           トップ
├── shared/              全テーマ共通（style.css / theory.js）
└── <theme>/
    ├── index.html       実践編の入口
    ├── chapters.js      章一覧（進捗バーが使う）
    └── theory/          理論編の章・用語辞書
containers/
├── base/                共通ベースイメージ + lab コマンド
└── <theme>/             テーマ派生層 + 演習一式（tasks/verify/hints/solutions/seed）
logs/                    実機完走の記録（本文の素材。ここに無いコマンドは本文に書かない）
probe/                   挙動の探索と、模範解答どおりに全演習を解く検証スクリプト
tools/                   公開前の機械検査（check.mjs）とローカル確認用サーバ
```

## 開発

```sh
# イメージを作る（共通ベース → テーマ層の順）
docker build -t lab-base:1.0.0   containers/base
docker build -t lab-sqlite:1.0.0 containers/sqlite
docker build -t lab-wasm:1.0.0   containers/wasm

# 模範解答どおりに全演習を解いて、判定が通ることを確かめる
docker run --rm -v "$PWD/probe:/probe:ro" lab-sqlite:1.0.0 bash /probe/db-solve-all.sh
docker run --rm -v "$PWD/probe:/probe:ro" lab-wasm:1.0.0   bash /probe/wa-solve-all.sh

# 公開前の機械検査（error が1件でもあれば公開しない）
node tools/check.mjs public

# ローカルで表示を確認する（Workers と同じパス解決規則）
node tools/serve.mjs public 8788
```

## 手元でローカルビルドしたイメージを試す

GHCR へ push する前は **`--pull=always` を付けてはいけない**。レジストリに無いので落ちる。

```
docker: Error response from daemon: pull access denied for lab-sqlite,
repository does not exist or may require 'docker login'
```

```sh
docker run --rm -it --name lab-sqlite \
  -v lab-sqlite-work:/home/lab/work -v lab-sqlite-state:/home/lab/.lab \
  lab-sqlite:1.0.0
```

bind mount を使わないので、**ホストのどのディレクトリから打っても結果は同じ**。

## 読者への配布（GHCR へ push した後）

```sh
docker run --rm -it --name lab-sqlite --pull=always \
  -v lab-sqlite-work:/home/lab/work -v lab-sqlite-state:/home/lab/.lab \
  ghcr.io/OWNER/lab-sqlite:1.0.0
```

`-v ...-state` を省くと進捗が毎回消える。
`--pull=always` は、読者の手元の古いキャッシュと本文のタグがずれる事故を防ぐために付ける。

podman でも同じコマンドが通る（`docker` を `podman` に置き換える）。
**podman 5.8.6 rootless で SQLite 編の全5演習の判定が通ることを実測した**（2026-10-06）。
Rancher Desktop / Colima と、WASM 編の podman は未検証。

## 未了

- シリーズ名の確定（リポジトリ名・サイトタイトル）
- GHCR への push（`OWNER` が未確定）
- 本番デプロイ（Cloudflare Workers）。`wrangler.jsonc` は未作成
- コメント機能の設定値（giscus は実装済み。`GISCUS_REPO` 等3つがプレースホルダ）
- CSP ヘッダー（`public/_headers`）。giscus を入れたので
  `script-src`/`frame-src` に `https://giscus.app` が要る。未設定なので今は制限なし
- 全文検索（Pagefind）。3テーマ目から入れる方針

## 付録: `--cap-add NET_RAW` を外した理由（2026-10-06 実測）

初版では読者に `--cap-add NET_RAW` を打たせ、本文に
「Podman の rootless がこの権限を既定で落とすため」と書いていた。実測したら**何もしていなかった**。

| 構成 | CapBnd | CapPrm | CapEff |
|---|---|---|---|
| docker 29.8.0・NET_RAW なし・uid 1000 | `a80425fb` | 0 | 0 |
| docker 29.8.0・NET_RAW あり・uid 1000 | `a80425fb` | 0 | 0 |
| docker 29.8.0・NET_RAW あり・uid 0 | `a80425fb` | `a80425fb` | `a80425fb` |
| podman 5.8.6 rootless・uid 1000 | `800405fb` | 0 | 0 |

- `CAP_NET_RAW`（bit 13）は **Docker の既定14個に最初から入っている**。
  `--cap-add` しても `CapBnd` が1ビットも変わらない
- イメージは `USER lab`（uid 1000）で動く。**非 root の execve では permitted/effective が落ちる**ので、
  bounding に入っていても使えない。上の表の1行目と2行目が完全に同一なのがその証拠
- SQLite / WASM の演習はネットワークを一切使わない。`ping` / `tcpdump` / `netem` はどの課題文にも無い

ネットワーク系テーマ（TCP / HTTPS / VPN）で非 root に `ping` を使わせるなら、
`--cap-add` ではなくイメージ側の `setcap cap_net_raw+ep` か ambient capability が要る。
**Docker の `--cap-add` は ambient を設定しない**（上の表で `CapAmb` が常に 0）。
