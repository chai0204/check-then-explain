// giscus（GitHub Discussions をバックエンドにしたコメント欄）を挿入する。
//
// このサイトが外部ドメインから読む唯一のスクリプト。設定をここ1箇所に集め、
// 各ページは <div id="giscus"></div> を置くだけにしてある。
//
// 落ちても本文には影響しない。読み込みは async で、挿入位置も本文の後。
// giscus.app に到達できない環境では、コメント欄の枠だけが空で残る。
(function () {
  var slot = document.getElementById("giscus");
  if (!slot) return;

  var conf = {
    "data-repo": "GISCUS_REPO",
    "data-repo-id": "GISCUS_REPO_ID",
    "data-category": "Comments",
    "data-category-id": "GISCUS_CATEGORY_ID",

    // URL のパスごとにスレッドを分ける。章ごとに independent なコメント欄になる。
    // title 方式にすると、見出しを変えた瞬間に過去のコメントが迷子になる。
    "data-mapping": "pathname",
    "data-strict": "1",

    "data-reactions-enabled": "1",
    "data-emit-metadata": "0",

    // 入力欄を上に置く。コメントが増えても「書く」が埋もれない。
    "data-input-position": "top",

    // サイト側は prefers-color-scheme でダークを出しているので、giscus も追従させる。
    "data-theme": "preferred_color_scheme",
    "data-lang": "ja",
  };

  var s = document.createElement("script");
  s.src = "https://giscus.app/client.js";
  s.async = true;
  s.crossOrigin = "anonymous";
  for (var k in conf) s.setAttribute(k, conf[k]);
  slot.appendChild(s);
})();
