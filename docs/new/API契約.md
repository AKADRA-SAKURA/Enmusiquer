# Enmusiquer API契約（MVP）

作成日: 2026-02-11  
適用範囲: MVP のモバイルアプリ向け API（FastAPI / `/v1`）

---

## 1. 共通仕様

### 1.1 ベースURL

- 開発: `https://api-dev.example.com/v1`
- 本番: `https://api.example.com/v1`

### 1.2 認証

- 認証方式: Bearer Token（OAuth/OIDC 連携後のアクセストークン）
- ヘッダ: `Authorization: Bearer <token>`
- 認証必須エンドポイント:
  - `POST /tracks`
  - `POST /tracks/{track_id}/preference`
  - `POST /tracks/{track_id}/bookmark`
  - `GET /recommendations`
  - `PATCH /admin/billing-settings`（管理者トークン必須）

管理者API:

- ヘッダ: `X-Admin-Token: <admin token>`
- 対象: `PATCH /admin/billing-settings`

開発環境での暫定認証:

- `Authorization: Bearer dev-user-<user_id>`

### 1.3 文字コード/日時

- 文字コード: UTF-8
- 日時: ISO 8601（UTC、例: `2026-02-11T10:00:00Z`）

### 1.4 ページング

- クエリ: `page`, `per_page`
- 既定値: `page=1`, `per_page=20`
- 上限: `per_page<=50`

### 1.5 共通レスポンス形式

成功時:

```json
{
  "data": {},
  "meta": {}
}
```

失敗時:

```json
{
  "error": {
    "code": "string_code",
    "message": "human readable message"
  }
}
```

---

## 2. エラー仕様

### 2.1 HTTPステータス

- `400` バリデーションエラー
- `401` 認証エラー
- `403` 権限エラー
- `404` リソースなし
- `409` 重複/競合
- `422` 業務ルール違反
- `429` レート制限
- `500` サーバー内部エラー

### 2.2 エラーコード（MVP）

- `validation_error`
- `unauthorized`
- `forbidden`
- `not_found`
- `duplicate_track_source_url`
- `duplicate_resource`
- `rate_limited`
- `billing_disabled`
- `internal_error`

---

## 3. データモデル（API）

### 3.1 Track

```json
{
  "id": 1,
  "title": "string",
  "artist_display_name": "string",
  "source_url": "https://...",
  "source_type": "youtube|spotify|apple_music|soundcloud|other",
  "source_track_id": "string|null",
  "thumbnail_url": "https://...|null",
  "writer": "string|null",
  "composer": "string|null",
  "year": 2025,
  "record_info": "string|null",
  "usage_context": "string|null",
  "series_name": "string|null",
  "album_artist_name": "string|null",
  "tags": [
    { "id": 10, "name": "クール" }
  ],
  "created_by": 100,
  "created_at": "2026-02-11T10:00:00Z",
  "updated_at": "2026-02-11T10:00:00Z"
}
```

### 3.2 RankingItem

```json
{
  "rank": 1,
  "track": {},
  "score": 123
}
```

### 3.3 RecommendationItem

```json
{
  "track": {},
  "recommendation_score": 0.91,
  "tag_match_score": 0.80,
  "access_score": 0.20
}
```

---

## 4. エンドポイント契約

### 4.1 `GET /tracks`

目的: 新着/一覧取得  
認証: 不要

Query:

- `page` number
- `per_page` number
- `sort` enum: `newest`(既定) | `popular`

Response `200`:

```json
{
  "data": [
    {}
  ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 120
  }
}
```

### 4.2 `GET /tracks/{track_id}`

目的: 曲詳細取得  
認証: 不要

Response `200`:

```json
{
  "data": {}
}
```

### 4.3 `POST /tracks`

目的: 曲投稿  
認証: 必須

Request:

```json
{
  "source_url": "https://...",
  "title": "string",
  "artist_display_name": "string",
  "source_type": "youtube",
  "source_track_id": "string",
  "thumbnail_url": "https://...",
  "writer": "string",
  "composer": "string",
  "year": 2025,
  "record_info": "string",
  "usage_context": "string",
  "series_name": "string",
  "album_artist_name": "string",
  "tag_ids": [1, 2, 3]
}
```

備考:

- `source_url` は正規化後に一意判定する
- 重複時は `409 duplicate_track_source_url`

Response `201`:

```json
{
  "data": {}
}
```

### 4.4 `GET /tags`

目的: タグ一覧/検索  
認証: 不要

Query:

- `q` string（部分一致）
- `page` number
- `per_page` number

Response `200`:

```json
{
  "data": [
    { "id": 1, "name": "クール" }
  ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 200
  }
}
```

### 4.5 `GET /search/tracks`

目的: キーワード検索  
認証: 不要

Query:

- `q` string（必須）
- `page` number
- `per_page` number

Response `200`: `GET /tracks` と同形式

### 4.6 `POST /search/tracks/by-tags`

目的: 複数タグAND検索  
認証: 不要

Request:

```json
{
  "tag_ids": [1, 2, 3],
  "page": 1,
  "per_page": 20
}
```

Response `200`: `GET /tracks` と同形式

### 4.7 `POST /tracks/{track_id}/preference`

目的: Like/Skip 登録  
認証: 必須

Request:

```json
{
  "preference_type": "like"
}
```

備考:

- `preference_type` は `like` または `skip`
- 同一ユーザー・同一曲は上書き更新（重複作成しない）

Response `200`:

```json
{
  "data": {
    "track_id": 1,
    "preference_type": "like"
  }
}
```

### 4.8 `POST /tracks/{track_id}/bookmark`

目的: あとで聴く保存  
認証: 必須

Response `200`:

```json
{
  "data": {
    "track_id": 1,
    "bookmarked": true
  }
}
```

備考:

- 既に保存済みの場合でも成功レスポンスを返す（冪等）

### 4.9 `GET /recommendations`

目的: おすすめ曲取得  
認証: 必須

Query:

- `page` number
- `per_page` number

スコア計算（MVP）:

- `recommendation_score = tag_match_score * 0.8 + access_score * 0.2`

Response `200`:

```json
{
  "data": [
    {}
  ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 100
  }
}
```

### 4.10 `GET /rankings`

目的: 人気ランキング取得  
認証: 不要

Query:

- `period` enum: `daily` | `weekly` | `monthly`（既定: `weekly`）
- `limit` number（既定: `20`, 上限: `100`）

Response `200`:

```json
{
  "data": [
    {}
  ],
  "meta": {
    "period": "weekly",
    "limit": 20
  }
}
```

### 4.11 `GET /system/billing-status`

目的: 課金可否フラグの取得（クライアント表示制御用）  
認証: 不要

Response `200`:

```json
{
  "data": {
    "billing_enabled": false,
    "effective_at": "2026-03-01T00:00:00Z",
    "can_charge_now": false
  }
}
```

### 4.12 `PATCH /admin/billing-settings`

目的: 課金開始フラグの更新  
認証: 管理者トークン必須（`X-Admin-Token`）

Request:

```json
{
  "billing_enabled": true,
  "effective_at": "2026-03-01T00:00:00Z",
  "changed_by": "akadra",
  "change_reason": "release start"
}
```

Response `200`:

```json
{
  "data": {
    "billing_enabled": true,
    "effective_at": "2026-03-01T00:00:00Z",
    "changed_by": "akadra",
    "change_reason": "release start",
    "updated_at": "2026-02-11T12:00:00Z"
  }
}
```

---

## 5. 補足（実装ルール）

- OpenAPI ドキュメントを `/docs` で公開（`ENABLE_DOCS=true` の場合）
- 破壊的変更は `v2` を切って対応する
- 監査対象操作:
  - 曲投稿
  - モデレーション操作
  - 課金有効化フラグ変更
