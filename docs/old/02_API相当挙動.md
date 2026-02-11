# API相当挙動（Controller単位）

本システムはJSON APIではなく、HTML描画/リダイレクト中心のサーバーサイドMVCです。  
ここでは「API相当」として、各Actionの入力・処理・出力を整理します。

## 共通

- 入力形式: 主に `params`（フォーム/クエリ/URLパラメータ）
- 出力形式: `render`（暗黙描画）または `redirect_to`
- CSRF保護: 有効（`protect_from_forgery`）
- 根拠: `app/controllers/application_controller.rb:4`

## ApplicationController

| Action/Hook | 入力 | 処理 | 出力 |
|---|---|---|---|
| `configure_permitted_parameters` | Devise params | `user_name`, `icon_url` などを許可 | Deviseの受理パラメータ更新 |
| `after_sign_in_path_for` | 認証後ユーザー | `User`ならトップへ | `hello_index_path` へリダイレクト |
| `after_sign_out_path_for` | サインアウト後 | 通常ユーザーはログイン画面へ | `new_user_session_path` |

根拠:
- `app/controllers/application_controller.rb:9`
- `app/controllers/application_controller.rb:23`
- `app/controllers/application_controller.rb:33`

## HelloController

| Action | 入力 | 処理 | 出力 |
|---|---|---|---|
| `index` | なし | 最新3件とLike上位3件取得 | `hello/index` 表示 |
| `create/show/search/mypage/link` | なし | 空実装 | 暗黙描画（テンプレートがあれば） |

備考:
- ルート `hello/about` はあるが `about` Actionが未実装。  
  根拠: `config/routes.rb:10`, `app/controllers/hello_controller.rb:3`

根拠:
- `app/controllers/hello_controller.rb:4`
- `app/controllers/hello_controller.rb:5`

## TweetsController

認証:
- `index/show/artist/ranking` 以外は `authenticate_user!` 必須。  
  根拠: `app/controllers/tweets_controller.rb:2`

| Action | 主入力 | 主処理 | 主出力 |
|---|---|---|---|
| `index` | `page` | 全曲を作成日降順、20件ページング | 一覧描画 |
| `artist` | `format`（楽曲ID） | 該当IDのartistを取得し同artist曲を列挙 | 一覧描画 |
| `ranking` | なし | Like件数で上位3曲抽出 | ランキング描画 |
| `new` | なし | 新規Tweetとタグ一覧準備 | 投稿フォーム描画 |
| `create` | `tweet_params` + `movieurl` | 投稿者設定、`movieurl`末尾11文字化、保存 | 成功:編集へ / 失敗:newへ |
| `show` | `id` | 楽曲・いいね新規・コメント一覧/新規取得 | 詳細描画 |
| `edit` | `id` | 楽曲・タグ一覧取得 | 編集フォーム描画 |
| `update` | `id`, `tweet_params` | 更新 | 成功:show / 失敗:new |
| `destroy` | `id` | 削除 | `index` へリダイレクト |

`tweet_params`:
- `:title, :artist, :writer, :composer, :year, :published, :record, :image, :used, :movieurl, tag_ids[]`
- 根拠: `app/controllers/tweets_controller.rb:65`

注意:
- 所有者チェックがControllerにないため、URL直叩き防御が弱い。  
  根拠: `app/controllers/tweets_controller.rb:49`, `app/views/tweets/show.html.erb:5`

根拠:
- `app/controllers/tweets_controller.rb:5`
- `app/controllers/tweets_controller.rb:9`
- `app/controllers/tweets_controller.rb:14`
- `app/controllers/tweets_controller.rb:22`
- `app/controllers/tweets_controller.rb:26`
- `app/controllers/tweets_controller.rb:31`
- `app/controllers/tweets_controller.rb:37`
- `app/controllers/tweets_controller.rb:49`
- `app/controllers/tweets_controller.rb:58`

## TagsController

認証:
- `index/search` 以外は `authenticate_user!` 必須。  
  根拠: `app/controllers/tags_controller.rb:2`

| Action | 主入力 | 主処理 | 主出力 |
|---|---|---|---|
| `index` | `search` | タグ名LIKE検索または全件昇順 | 一覧描画 |
| `new` | なし | 新規Tag準備 | 作成フォーム描画 |
| `search` | `format`（タグID） | 指定タグ取得 | タグ詳細描画 |
| `create` | `tag[tag]` | 作成者ID付与して保存 | 成功:index / 失敗:new |
| `destroy` | `id` | タグ削除 | `index`へ |

根拠:
- `app/controllers/tags_controller.rb:6`
- `app/controllers/tags_controller.rb:17`
- `app/controllers/tags_controller.rb:22`
- `app/controllers/tags_controller.rb:35`

## SearchController

| Action | 主入力 | 主処理 | 主出力 |
|---|---|---|---|
| `search` | `search`, `page` | 曲関連カラムにOR-LIKE検索、20件ページング | 検索結果描画 |
| `tagsearch` | `tag_ids[]`, `page` | タグAND一致フィルタで曲ID抽出して一覧化 | 絞り込み結果描画 |

内部メソッド:
- `selected_tags_params`: `params.require(:tag_ids)`
- `filter(selected_tag_ids)`: 各候補曲が選択タグを全て含むか判定

根拠:
- `app/controllers/search_controller.rb:5`
- `app/controllers/search_controller.rb:11`
- `app/controllers/search_controller.rb:29`
- `app/controllers/search_controller.rb:33`
- `app/controllers/search_controller.rb:39`

## LikesController

| Action | 主入力 | 主処理 | 主出力 |
|---|---|---|---|
| `create` | `tweet_id` | `current_user.likes.create` | `redirect_back` |
| `destroy` | `tweet_id` | `Like.find_by(...).destroy` | `redirect_back` |

注意:
- 認証フィルタ未定義。`current_user` 前提のため未ログイン直接アクセスで不整合が起きる可能性。  
  根拠: `app/controllers/likes_controller.rb:2`

根拠:
- `app/controllers/likes_controller.rb:3`
- `app/controllers/likes_controller.rb:8`

## CommentsController

| Action | 主入力 | 主処理 | 主出力 |
|---|---|---|---|
| `create` | `tweet_id`, `comment[comment]` | 対象曲にコメント作成、`current_user.id` 付与 | 成否ともに `redirect_back`（flashあり） |

認証:
- `authenticate_user!` 必須  
  根拠: `app/controllers/comments_controller.rb:2`

根拠:
- `app/controllers/comments_controller.rb:4`
- `app/controllers/comments_controller.rb:20`

## UsersController

| Action | 主入力 | 主処理 | 主出力 |
|---|---|---|---|
| `show` | `id`, `page` | `current_user.tweets` を表示用取得、`params[:id]` でユーザー取得、いいね取得 | マイページ描画 |
| `edit` | なし | 空実装 | 暗黙描画 |
| `update` | `user[user_name, icon_url]` | `current_user` 更新 | 成功:show / 失敗:edit |

注意:
- `show` が `params[:id]` より `current_user` を優先して投稿一覧を作るため、URLのIDと表示内容が一貫しない可能性。  
  根拠: `app/controllers/users_controller.rb:4`, `app/controllers/users_controller.rb:5`
- 認証フィルタがなく、未ログインで `current_user.tweets` を呼ぶ設計。  
  根拠: `app/controllers/users_controller.rb:4`

## RegistrationsController（Devise拡張）

| Action | 入力 | 処理 | 出力 |
|---|---|---|---|
| `after_update_path_for` | 更新後resource | 遷移先上書き | `user_path(resource)` |

根拠:
- `app/controllers/registrations_controller.rb:4`

## ルーティング不整合（重要）

- `GET /hello/about -> hello#about` だが Action未定義。  
  根拠: `config/routes.rb:10`, `app/controllers/hello_controller.rb:3`
- `GET /tags/:tag_id/tweets -> tweets#search` だが Action未定義。  
  根拠: `config/routes.rb:46`, `app/controllers/tweets_controller.rb:4`

