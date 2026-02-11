"""add billing settings table

Revision ID: 20260211_0002
Revises: 20260211_0001
Create Date: 2026-02-11
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "20260211_0002"
down_revision: Union[str, Sequence[str], None] = "20260211_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "billing_settings",
        sa.Column("id", sa.BigInteger(), primary_key=True),
        sa.Column("billing_enabled", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("effective_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("changed_by", sa.String(length=100), nullable=True),
        sa.Column("change_reason", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.execute(
        "INSERT INTO billing_settings (id, billing_enabled, created_at, updated_at) "
        "VALUES (1, false, NOW(), NOW())"
    )


def downgrade() -> None:
    op.drop_table("billing_settings")
