"""add first_name

Revision ID: 557251cdce7f
Revises: 69686335d382
Create Date: 2026-08-29 19:52:08.385932

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '557251cdce7f'
down_revision: Union[str, Sequence[str], None] = '69686335d382'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("first_name", sa.String(), nullable=True),
    )

    op.execute(
        "UPDATE users SET first_name = '' WHERE first_name IS NULL"
    )

    op.alter_column(
        "users",
        "first_name",
        existing_type=sa.String(),
        nullable=False,
    )


def downgrade() -> None:
    op.drop_column("users", "first_name")