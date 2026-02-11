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
