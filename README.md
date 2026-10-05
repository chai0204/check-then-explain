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
docker run --rm -it --name lab-sqlite --cap-add NET_RAW \
  -v lab-sqlite-work:/home/lab/work -v lab-sqlite-state:/home/lab/.lab \
  lab-sqlite:1.0.0
```

bind mount を使わないので、**ホストのどのディレクトリから打っても結果は同じ**。

## 読者への配布（GHCR へ push した後）

```sh
docker run --rm -it --name lab-sqlite --pull=always --cap-add NET_RAW \
  -v lab-sqlite-work:/home/lab/work -v lab-sqlite-state:/home/lab/.lab \
  ghcr.io/OWNER/lab-sqlite:1.0.0
```

`-v ...-state` を省くと進捗が毎回消える。`--cap-add NET_RAW` は Podman の rootless が
この権限を既定で落とすため（Docker では冗長だが害はない）。
`--pull=always` は、読者の手元の古いキャッシュと本文のタグがずれる事故を防ぐために付ける。

## 未了

- GHCR への push（`OWNER` が未確定）
- 本番デプロイ（Cloudflare Workers）。`wrangler.jsonc` は未作成
- 全文検索（Pagefind）。3テーマ目から入れる方針
