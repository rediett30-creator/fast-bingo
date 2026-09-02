"""seed common patterns

Revision ID: 69686335d382
Revises: b23057c6174a
Create Date: 2026-08-29 19:10:19.878259

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '69686335d382'
down_revision: Union[str, Sequence[str], None] = 'b23057c6174a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Declare light representation of patterns table
patterns_table = sa.table(
    'patterns',
    sa.column('name', sa.String),
    sa.column('description', sa.String),
    sa.column('covered_cells', sa.JSON)
)

# Standard famous bingo shapes defined by 0-24 grid indices
DEFAULT_PATTERNS = [
    {
        "name": "Full House (Blackout)",
        "description": "Cover all 25 spaces on the bingo card.",
        "covered_cells": list(range(25))
    },
    {
        "name": "Four Corners",
        "description": "Cover the four outermost corners of the card.",
        "covered_cells": [0, 4, 20, 24]
    },
    {
        "name": "Letter X",
        "description": "Cover both diagonal lines crossing through the center.",
        "covered_cells": [0, 4, 6, 8, 12, 16, 18, 20, 24]
    },
    {
        "name": "Letter L",
        "description": "Cover the leftmost column (B) and the bottom row.",
        "covered_cells": [0, 5, 10, 15, 20, 21, 22, 23, 24]
    },
    {
        "name": "Letter T",
        "description": "Cover the top row and the center vertical column (N).",
        "covered_cells": [0, 1, 2, 3, 4, 7, 12, 17, 22]
    },
    {
        "name": "Letter Z",
        "description": "Cover the top row, main reverse diagonal, and bottom row.",
        "covered_cells": [0, 1, 2, 3, 4, 8, 12, 16, 20, 21, 22, 23, 24]
    },
    {
        "name": "Letter H",
        "description": "Cover the left column, middle row, and right column.",
        "covered_cells": [0, 4, 5, 9, 10, 11, 12, 13, 14, 15, 19, 20, 24]
    },
    {
        "name": "Letter C",
        "description": "Cover the top row, left column, and bottom row.",
        "covered_cells": [0, 1, 2, 3, 4, 5, 10, 15, 20, 21, 22, 23, 24]
    },
    {
        "name": "Letter E",
        "description": "Cover the top row, middle row, bottom row, and left column.",
        "covered_cells": [0, 1, 2, 3, 4, 5, 10, 11, 12, 13, 14, 15, 20, 21, 22, 23, 24]
    },
    {
        "name": "Plus Sign (Cross)",
        "description": "Cover the middle horizontal row and middle vertical column.",
        "covered_cells": [2, 7, 10, 11, 12, 13, 14, 17, 22]
    },
    {
        "name": "Outer Frame",
        "description": "Cover all outer edge squares to create a picture frame.",
        "covered_cells": [0, 1, 2, 3, 4, 5, 9, 10, 14, 15, 19, 20, 21, 22, 23, 24]
    },
    {
        "name": "Inner Square",
        "description": "Cover the 3x3 block surrounding the center FREE space.",
        "covered_cells": [6, 7, 8, 11, 12, 13, 16, 17, 18]
    },
    {
        "name": "Postage Stamp",
        "description": "Cover the 2x2 block in the top-right corner.",
        "covered_cells": [3, 4, 8, 9]
    },
    {
        "name": "Four Corner Stamps",
        "description": "Cover 2x2 blocks in all four corners of the card.",
        "covered_cells": [0, 1, 3, 4, 5, 6, 8, 9, 15, 16, 18, 19, 20, 21, 23, 24]
    },
    {
        "name": "Hollow Diamond",
        "description": "Cover outer diamond points around the center space.",
        "covered_cells": [2, 6, 8, 10, 14, 16, 18, 22]
    },
    {
        "name": "Pyramid",
        "description": "Cover a filled triangle starting from top center down to row 3.",
        "covered_cells": [2, 6, 7, 8, 10, 11, 12, 13, 14]
    },
    {
        "name": "Checkerboard",
        "description": "Cover alternating squares starting from index 0.",
        "covered_cells": [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24]
    },
    {
        "name": "Top and Bottom Goalposts",
        "description": "Cover both the top-most and bottom-most horizontal lines.",
        "covered_cells": [0, 1, 2, 3, 4, 20, 21, 22, 23, 24]
    }
]


def upgrade() -> None:
    """Upgrade schema - Seed common bingo patterns."""
    op.bulk_insert(patterns_table, DEFAULT_PATTERNS)


def downgrade() -> None:
    """Downgrade schema - Remove seeded patterns."""
    op.execute(patterns_table.delete())