"""upgrade user model

Revision ID: 5a7f3af247b3
Revises: 557251cdce7f
Create Date: 2026-08-30 11:18:04.595072

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '5a7f3af247b3'
down_revision: Union[str, Sequence[str], None] = '557251cdce7f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # telegram_id: INTEGER -> BIGINT
    op.alter_column(
        "users",
        "telegram_id",
        existing_type=sa.Integer(),
        type_=sa.BigInteger(),
        existing_nullable=False,
    )

    # username: NOT NULL -> NULL
    op.alter_column(
        "users",
        "username",
        existing_type=sa.String(),
        nullable=True,
    )

    # Create PostgreSQL enum
    user_role_enum = sa.Enum(
        "user",
        "admin",
        name="userrole",
    )
    user_role_enum.create(op.get_bind(), checkfirst=True)

    # role: VARCHAR -> userrole
    op.execute(
        """
        ALTER TABLE users
        ALTER COLUMN role TYPE userrole
        USING role::text::userrole
        """
    )

    # Set default role
    op.alter_column(
        "users",
        "role",
        existing_type=user_role_enum,
        server_default=sa.text("'user'"),
        existing_nullable=False,
    )

    # Add telegram_id index
    op.create_index(
        "ix_users_telegram_id",
        "users",
        ["telegram_id"],
        unique=False,
    )


def downgrade() -> None:
    # Remove telegram_id index
    op.drop_index(
        "ix_users_telegram_id",
        table_name="users",
    )

    # Remove role default
    op.alter_column(
        "users",
        "role",
        server_default=None,
    )

    # role: userrole -> VARCHAR
    op.execute(
        """
        ALTER TABLE users
        ALTER COLUMN role TYPE VARCHAR
        USING role::text
        """
    )

    # Drop PostgreSQL enum
    sa.Enum(
        "user",
        "admin",
        name="userrole",
    ).drop(
        op.get_bind(),
        checkfirst=True,
    )

    # telegram_id: BIGINT -> INTEGER
    op.alter_column(
        "users",
        "telegram_id",
        existing_type=sa.BigInteger(),
        type_=sa.Integer(),
        existing_nullable=False,
    )

    # Restore username NOT NULL
    op.execute(
        """
        UPDATE users
        SET username = ''
        WHERE username IS NULL
        """
    )

    op.alter_column(
        "users",
        "username",
        existing_type=sa.String(),
        nullable=False,
    )
