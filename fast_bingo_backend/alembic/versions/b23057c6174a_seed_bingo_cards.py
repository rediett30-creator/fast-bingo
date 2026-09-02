"""seed bingo cards

Revision ID: b23057c6174a
Revises: 657a39b0cd74
Create Date: 2026-08-29 19:03:48.246190

"""
import random
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b23057c6174a'
down_revision: Union[str, Sequence[str], None] = '657a39b0cd74'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Declare light representation of cards table for bulk operations
cards_table = sa.table(
    'cards',
    sa.column('grid', sa.JSON)
)


def generate_single_card() -> list[int | None]:
    """Generates a standard 5x5 Bingo grid flattened into a 25-element list."""
    b = random.sample(range(1, 16), 5)
    i = random.sample(range(16, 31), 5)
    n = random.sample(range(31, 46), 4)  # Only 4 numbers needed; center is FREE
    g = random.sample(range(46, 61), 5)
    o = random.sample(range(61, 76), 5)

    
    return [
        b[0], i[0], n[0], g[0], o[0],     
        b[1], i[1], n[1], g[1], o[1],     
        b[2], i[2], None, g[2], o[2],      
        b[3], i[3], n[2], g[3], o[3],     
        b[4], i[4], n[3], g[4], o[4]      
    ]


def generate_unique_cards(total_cards: int = 1000) -> list[dict[str, list[int | None]]]:
    """Generates a list of unique bingo card dictionaries ready for database insertion."""
    # Fixed seed guarantees identical card generation across environments
    random.seed(42)

    seen_cards = set()
    card_records = []

    while len(card_records) < total_cards:
        grid = generate_single_card()
        grid_tuple = tuple(grid)

        if grid_tuple not in seen_cards:
            seen_cards.add(grid_tuple)
            card_records.append({'grid': grid})

    return card_records


def upgrade() -> None:
    """Upgrade schema - Seed 1000 unique bingo cards."""
    cards_data = generate_unique_cards(1000)
    op.bulk_insert(cards_table, cards_data)


def downgrade() -> None:
    """Downgrade schema - Remove seeded cards."""
    op.execute(cards_table.delete())