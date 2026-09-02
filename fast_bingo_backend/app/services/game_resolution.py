from dataclasses import dataclass
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.game import Game
from app.models.game_card import GameCard
from app.models.enums import GameStatus
from app.services.bingo_validator import validate_bingo, BingoOutcome, BingoResult


@dataclass(frozen=True)
class ClaimResolution:
    outcome: BingoOutcome
    reason: str
    should_broadcast_finish: bool


async def _try_finish_game(db: AsyncSession, game_id: int) -> bool:
    """
    Atomically flips ACTIVE -> FINISHED. Returns True only for whichever
    concurrent request actually performed the flip. If another claim
    already finished the game, this returns False and touches nothing --
    the DB's row-level locking on the UPDATE is what makes this safe
    even when two claims arrive in the same instant.
    """
    result = await db.execute(
        update(Game)
        .where(Game.id == game_id, Game.status == GameStatus.ACTIVE)
        .values(status=GameStatus.FINISHED)
    )
    return result.rowcount == 1


async def resolve_bingo_claim(
    db: AsyncSession,
    game: Game,
    game_card: GameCard,
    called_numbers: list[int],
    covered_cells: list[int],
) -> ClaimResolution:
    if game.status != GameStatus.ACTIVE:
        return ClaimResolution(BingoOutcome.LOST, "This game is no longer active", False)

    if game_card.is_winner:
        return ClaimResolution(BingoOutcome.LOST, "Already resolved", False)

    result: BingoResult = validate_bingo(game_card.card.grid, called_numbers, covered_cells)

    if result.outcome != BingoOutcome.WON:
        return ClaimResolution(result.outcome, result.reason, False)

    if not await _try_finish_game(db, game.id):
        return ClaimResolution(BingoOutcome.LOST, "Another player's claim was processed first", False)

    game_card.is_winner = True
    await db.commit()
    return ClaimResolution(BingoOutcome.WON, result.reason, True)