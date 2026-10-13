-- 記事の台帳の形。行は catalog/articles.sql に置く。
-- 正本はこの2つの SQL の文。node tools/catalog.mjs が SQLite（Node 組み込みの node:sqlite・メモリ上）に読み込み、
-- トップの記事一覧と各記事のホームを焼き出す。更新するのは管理者だけで、読者に配るのは焼き出した静的なページだけ
-- （検索と絞り込みはブラウザの中で動く。読み取り専用なので、ネットにデータベースを置く必要が無い）。
-- 完了推定時間は表に持たない。章の「所要 N分」と演習の est_min を生成のたびに数える（手で持つとずれる）。

CREATE TABLE article (
  slug        TEXT PRIMARY KEY,                       -- URL の名前（/slug/ が記事ホーム）
  title       TEXT NOT NULL,                          -- 記事名
  status      TEXT NOT NULL CHECK (status IN ('確認済み', 'ドラフト', '修正中')),
                                                      -- 確認済み = 著者が読者として通した / ドラフト = まだ通していない / 修正中 = 直している途中
  cert        TEXT,                                   -- 関連資格（無ければ NULL）
  cert_exam   TEXT,                                   -- 試験の区分（例: '101'。NULL 可）
  cert_order  TEXT,                                   -- 資格の中の並び（例: '1.02'）。前後の記事のリンクに使う
  difficulty  TEXT NOT NULL CHECK (difficulty IN ('入門', '初級', '中級', '上級')),
  method      TEXT NOT NULL CHECK (method IN ('読むだけ', '演習あり（コンテナ）', '演習あり（仮想マシン）')),
  created     TEXT NOT NULL CHECK (created GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
  updated     TEXT NOT NULL CHECK (updated GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND updated >= created),
                                                      -- 最終更新日 = 中身（本文・演習）を直した日。並べ替えの既定の鍵
  summary     TEXT NOT NULL,                          -- 概要（2〜3文）
  audience    TEXT NOT NULL,                          -- 想定読者
  outcomes    TEXT NOT NULL,                          -- 得られるもの（1行に1つ）
  CHECK ((cert IS NULL) = (cert_order IS NULL))
);

CREATE TABLE article_domain (                         -- 関連領域（1記事に複数）
  slug    TEXT NOT NULL REFERENCES article(slug),
  domain  TEXT NOT NULL CHECK (domain IN ('サーバー', 'ネットワーク', 'セキュリティ', 'DB', 'ウェブ', 'OSS')),
  PRIMARY KEY (slug, domain)
);

CREATE TABLE article_related (                        -- 関連記事（資格の前後は cert_order から自動で出すので、ここには入れない）
  slug     TEXT NOT NULL REFERENCES article(slug),
  related  TEXT NOT NULL REFERENCES article(slug),
  PRIMARY KEY (slug, related),
  CHECK (slug <> related)
);

CREATE TABLE cert (                                   -- 資格の地図（出題範囲との対応表）があれば、その URL
  name     TEXT PRIMARY KEY,
  map_url  TEXT
);
