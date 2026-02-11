# Enmusiquer Backend (FastAPI)

## Setup

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e .
Copy-Item .env.example .env
```

## Run API

```powershell
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

## Run Migrations

```powershell
alembic upgrade head
```
