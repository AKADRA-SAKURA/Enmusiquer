from datetime import datetime, timezone
import logging

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import get_db
from app.models.billing_setting import BillingSetting


logger = logging.getLogger(__name__)
router = APIRouter()


class BillingStatusData(BaseModel):
    billing_enabled: bool
    effective_at: datetime | None = None
    can_charge_now: bool


class BillingStatusResponse(BaseModel):
    data: BillingStatusData


class BillingUpdateRequest(BaseModel):
    billing_enabled: bool
    effective_at: datetime | None = None
    changed_by: str = Field(min_length=1, max_length=100)
    change_reason: str | None = Field(default=None, max_length=2000)


class BillingUpdateData(BaseModel):
    billing_enabled: bool
    effective_at: datetime | None = None
    changed_by: str | None = None
    change_reason: str | None = None
    updated_at: datetime


class BillingUpdateResponse(BaseModel):
    data: BillingUpdateData


def get_or_create_billing_setting(db: Session) -> BillingSetting:
    setting = db.query(BillingSetting).order_by(BillingSetting.id.asc()).first()
    if setting is None:
        setting = BillingSetting(billing_enabled=False)
        db.add(setting)
        db.commit()
        db.refresh(setting)
    return setting


def can_charge_now(setting: BillingSetting) -> bool:
    if not setting.billing_enabled:
        return False
    if setting.effective_at is None:
        return True
    return setting.effective_at <= datetime.now(timezone.utc)


def require_admin_token(x_admin_token: str | None = Header(default=None, alias="X-Admin-Token")) -> None:
    if not settings.admin_api_token:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="admin_api_token is not configured",
        )
    if x_admin_token != settings.admin_api_token:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="forbidden")


@router.get("/system/billing-status", response_model=BillingStatusResponse)
def get_billing_status(db: Session = Depends(get_db)) -> BillingStatusResponse:
    setting = get_or_create_billing_setting(db)
    return BillingStatusResponse(
        data=BillingStatusData(
            billing_enabled=setting.billing_enabled,
            effective_at=setting.effective_at,
            can_charge_now=can_charge_now(setting),
        )
    )


@router.patch(
    "/admin/billing-settings",
    response_model=BillingUpdateResponse,
    dependencies=[Depends(require_admin_token)],
)
def update_billing_setting(
    payload: BillingUpdateRequest,
    db: Session = Depends(get_db),
) -> BillingUpdateResponse:
    setting = get_or_create_billing_setting(db)

    setting.billing_enabled = payload.billing_enabled
    setting.effective_at = payload.effective_at
    setting.changed_by = payload.changed_by
    setting.change_reason = payload.change_reason
    db.add(setting)
    db.commit()
    db.refresh(setting)

    logger.info(
        "billing flag changed: enabled=%s effective_at=%s changed_by=%s",
        setting.billing_enabled,
        setting.effective_at,
        setting.changed_by,
    )

    return BillingUpdateResponse(
        data=BillingUpdateData(
            billing_enabled=setting.billing_enabled,
            effective_at=setting.effective_at,
            changed_by=setting.changed_by,
            change_reason=setting.change_reason,
            updated_at=setting.updated_at,
        )
    )
