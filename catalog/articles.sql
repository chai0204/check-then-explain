-- 記事の台帳（行）。形は catalog/schema.sql。書き換えたら node tools/catalog.mjs で、トップと記事ホームと道しるべを作り直す。
-- 最終更新日（updated）は中身（本文・演習）を直した日。道しるべだけの変更では動かさない。

INSERT INTO cert (name, map_url) VALUES ('LinuC レベル1', '/linuc/');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-boot', 'Linux の起動・仮想化・プロセス', 'ドラフト', 'LinuC レベル1', '101', '1.01', '初級', '演習あり（仮想マシン）', '2026-10-13', '2026-10-13',
  '（下書き待ち）',
  '（下書き待ち）',
  '（下書き待ち）');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-boot', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-files', 'ファイルとパーミッション', 'ドラフト', 'LinuC レベル1', '101', '1.02', '初級', '演習あり（コンテナ）', '2026-10-13', '2026-10-13',
  '（下書き待ち）',
  '（下書き待ち）',
  '（下書き待ち）');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-files', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-text', 'コマンドラインとテキスト処理', 'ドラフト', 'LinuC レベル1', '101', '1.03', '初級', '演習あり（コンテナ）', '2026-10-13', '2026-10-13',
  '（下書き待ち）',
  '（下書き待ち）',
  '（下書き待ち）');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-text', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-packages', 'パッケージ管理（apt と yum）', 'ドラフト', 'LinuC レベル1', '101', '1.04', '初級', '演習あり（コンテナ）', '2026-10-13', '2026-10-13',
  '（下書き待ち）',
  '（下書き待ち）',
  '（下書き待ち）');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-packages', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-disks', 'ハードウェアとディスク', 'ドラフト', 'LinuC レベル1', '101', '1.05', '初級', '演習あり（仮想マシン）', '2026-10-13', '2026-10-13',
  '（下書き待ち）',
  '（下書き待ち）',
  '（下書き待ち）');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-disks', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-shell', 'シェルとスクリプト', 'ドラフト', 'LinuC レベル1', '102', '1.06', '初級', '演習あり（コンテナ）', '2026-10-13', '2026-10-13',
  '（下書き待ち）',
  '（下書き待ち）',
  '（下書き待ち）');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-shell', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-network', 'ネットワークの基礎', 'ドラフト', 'LinuC レベル1', '102', '1.07', '初級', '演習あり（仮想マシン）', '2026-10-13', '2026-10-13',
  '（下書き待ち）',
  '（下書き待ち）',
  '（下書き待ち）');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-network', 'ネットワーク');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-network', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-admin', 'アカウント・ジョブ・ロケール', 'ドラフト', 'LinuC レベル1', '102', '1.08', '初級', '演習あり（仮想マシン）', '2026-10-13', '2026-10-13',
  '（下書き待ち）',
  '（下書き待ち）',
  '（下書き待ち）');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-admin', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-services', '時刻・ログ・メール', 'ドラフト', 'LinuC レベル1', '102', '1.09', '初級', '演習あり（コンテナ）', '2026-10-12', '2026-10-13',
  '（下書き待ち）',
  '（下書き待ち）',
  '（下書き待ち）');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-services', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-security', 'セキュリティ', 'ドラフト', 'LinuC レベル1', '102', '1.10', '初級', '演習あり（仮想マシン）', '2026-10-13', '2026-10-13',
  '（下書き待ち）',
  '（下書き待ち）',
  '（下書き待ち）');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-security', 'セキュリティ');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-security', 'サーバー');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'linuc-oss', 'オープンソースの文化', 'ドラフト', 'LinuC レベル1', '102', '1.11', '入門', '読むだけ', '2026-10-13', '2026-10-13',
  '（下書き待ち）',
  '（下書き待ち）',
  '（下書き待ち）');
INSERT INTO article_domain (slug, domain) VALUES ('linuc-oss', 'OSS');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'sqlite', 'SQLite', '確認済み', NULL, NULL, NULL, '中級', '演習あり（コンテナ）', '2026-09-30', '2026-10-08',
  '（下書き待ち）',
  '（下書き待ち）',
  '（下書き待ち）');
INSERT INTO article_domain (slug, domain) VALUES ('sqlite', 'DB');

INSERT INTO article (slug, title, status, cert, cert_exam, cert_order, difficulty, method, created, updated, summary, audience, outcomes) VALUES (
  'wasm', 'WebAssembly（WASM）', 'ドラフト', NULL, NULL, NULL, '中級', '演習あり（コンテナ）', '2026-09-30', '2026-10-08',
  '（下書き待ち）',
  '（下書き待ち）',
  '（下書き待ち）');
INSERT INTO article_domain (slug, domain) VALUES ('wasm', 'ウェブ');

