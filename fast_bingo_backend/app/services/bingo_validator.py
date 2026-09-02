from dataclasses import dataclass
from enum import Enum
from typing import Optional


class BingoOutcome(str, Enum):
    WON = "won"
    LOST = "lost"   
    LATE = "late"   


@dataclass(frozen=True)
class BingoResult:
    outcome: BingoOutcome
    reason: str


def validate_bingo(
    card_grid: list[Optional[int]],
    called_numbers: list[int],
    covered_cells: list[int],
) -> BingoResult:
    if not called_numbers:
        return BingoResult(BingoOutcome.LOST, "No numbers have been called yet")

    called_set = set(called_numbers)
    last_called = called_numbers[-1]

    pattern_values = {card_grid[i] for i in covered_cells if card_grid[i] is not None}

    pattern_complete = all(
        card_grid[i] is None or card_grid[i] in called_set
        for i in covered_cells
    )

    if not pattern_complete:
        return BingoResult(BingoOutcome.LOST, "Pattern is not fully covered by called numbers")

    if last_called not in pattern_values:
        return BingoResult(
            BingoOutcome.LATE,
            f"Pattern was already complete before {last_called} was called — claim came too late",
        )

    return BingoResult(BingoOutcome.WON, "Pattern completed by the most recent call")