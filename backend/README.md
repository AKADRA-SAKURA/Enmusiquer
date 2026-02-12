# Enmusiquer Backend (FastAPI)

## Setup

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e .
pip install -e .[dev]
Copy-Item .env.example .env
```

## Run API

```powershell
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

## Local Auth Token (MVP)

- Protected endpoints accept local token format:
  - `Authorization: Bearer dev-user-<user_id>`
- Example:
  - `Authorization: Bearer dev-user-1`

## Run Migrations

```powershell
alembic upgrade head
```

## Seed MVP Data

```powershell
python scripts/seed_mvp.py
```

## Run Tests

```powershell
pytest -q
```

## Billing Flag Admin API

- Set `ADMIN_API_TOKEN` in `.env`
- Call `PATCH /v1/admin/billing-settings` with header:
  - `X-Admin-Token: <ADMIN_API_TOKEN>`

## Docker (local)

```powershell
cd backend
docker build -t enm-backend:local .
docker run --rm -p 8000:8000 --env-file .env enm-backend:local
```

## Build/Push to ECR (GitHub Actions)

- Workflow: `.github/workflows/backend-image.yml`
- Trigger: `workflow_dispatch`
- Required inputs:
  - `aws_role_to_assume`: GitHub OIDC で Assume する IAM ロール ARN
  - `aws_region`: 例 `ap-northeast-1`
  - `ecr_repository`: 例 `enm/backend`
  - `image_tag`: 例 `20260212-1`

イメージを push した後は、Terraform 側で `api_image_tag` を更新して反映します。
