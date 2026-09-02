import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The core 5×5 Bingo Card widget used across all screens.
/// Features:
/// - B-I-N-G-O color-coded header row
/// - 25 cells (interactive user selection/deselection, marked coral pop, index 12 free-space star)
/// - Green full-pill "Bingo" action button (when not readOnly)
/// - Locked/dimmed post-game state
/// - Frosted glass / mirror locked overlay when a card is lost/invalidated
/// - Multi-select highlight state (for Buy Cards screen)
/// - Responsive scaling for vertical modest grid view
class BingoCardWidget extends StatelessWidget {
  final List<int?> grid; // 25 elements, index 12 is null (free space)
  final Set<int> markedIndices; // Indices (0-24) currently marked by user
  final bool readOnly;
  final bool locked;
  final bool isSelected;
  final bool isWinningCard;
  final bool isBingoPending;
  final bool isLost;
  final String? lostReason;
  final VoidCallback? onBingoPressed;
  final VoidCallback? onTap;
  final void Function(int cellIndex)? onCellTap;
  final int? cardId;

  const BingoCardWidget({
    super.key,
    required this.grid,
    this.markedIndices = const {},
    this.readOnly = false,
    this.locked = false,
    this.isSelected = false,
    this.isWinningCard = false,
    this.isBingoPending = false,
    this.isLost = false,
    this.lostReason,
    this.onBingoPressed,
    this.onTap,
    this.onCellTap,
    this.cardId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppTheme.gridPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isWinningCard
                ? const Color(0xFFFFD54F)
                : isLost
                    ? AppTheme.errorRed
                    : isSelected
                        ? AppTheme.cardSelectedBorder
                        : AppTheme.gridPanelBorder,
            width: isWinningCard ? 3.5 : (isSelected || isLost) ? 2.5 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isWinningCard
                  ? const Color(0xFFFFD54F).withValues(alpha: 0.45)
                  : isLost
                      ? AppTheme.errorRed.withValues(alpha: 0.3)
                      : isSelected
                          ? AppTheme.cardSelectedBorder.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.2),
              blurRadius: isWinningCard || isSelected ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(7.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Card Header Info ──────────────────────────────────────
                  if (cardId != null && !readOnly)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CARD #$cardId',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.cellNumberText,
                              letterSpacing: 0.6,
                            ),
                          ),
                          if (isWinningCard)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD54F),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'WINNER!',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4A3400),
                                ),
                              ),
                            )
                          else if (isLost)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'LOST',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // ── B-I-N-G-O Header Row ──────────────────────────────────
                  _buildBingoHeader(),
                  const SizedBox(height: 4),

                  // ── 5x5 Number Grid ──────────────────────────────────────
                  _buildGrid(context),

                  // ── Bingo Button (if not readOnly) ────────────────────────
                  if (!readOnly) ...[
                    const SizedBox(height: 6),
                    _buildBingoButton(),
                  ],
                ],
              ),
            ),

            // ── Normal Locked / Dim Overlay (when game finished) ────────────
            if (locked && !isWinningCard && !isLost)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

            // ── Locked Mirror / Frosted Glass Overlay (when card lost) ───────
            if (isLost)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xCC1A0826), // dark tinted translucent glass
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.errorRed.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.errorRed.withValues(alpha: 0.8),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              color: AppTheme.errorRed,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'CARD LOCKED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (lostReason != null && lostReason!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              lostReason!,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Selection checkmark indicator badge ─────────────────────────
            if (isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppTheme.bingoButton,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBingoHeader() {
    return Row(
      children: List.generate(5, (col) {
        final color = AppTheme.bingoColors[col];
        final letter = AppTheme.bingoLetters[col];
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Text(
                letter,
                style: AppTheme.bingoHeaderLetterStyle.copyWith(
                  fontSize: readOnly ? 9 : 11,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Column(
        children: List.generate(5, (row) {
          return Expanded(
            child: Row(
              children: List.generate(5, (col) {
                final index = row * 5 + col;
                final value = (index < grid.length) ? grid[index] : null;
                final isFreeSpace = index == 12 || value == null;
                final isMarked = markedIndices.contains(index) || isFreeSpace;

                return Expanded(
                  child: _buildCell(
                    index: index,
                    value: value,
                    isFreeSpace: isFreeSpace,
                    isMarked: isMarked,
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCell({
    required int index,
    required int? value,
    required bool isFreeSpace,
    required bool isMarked,
  }) {
    Color bgColor;
    Color textColor;

    if (isFreeSpace) {
      bgColor = isMarked ? AppTheme.cellMarked : AppTheme.cellUnmarked;
      textColor = Colors.white;
    } else if (isMarked) {
      bgColor = AppTheme.cellMarked;
      textColor = AppTheme.cellMarkedText;
    } else {
      bgColor = AppTheme.cellUnmarked;
      textColor = AppTheme.cellNumberText;
    }

    final cellWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: isMarked
            ? Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1)
            : null,
        boxShadow: isMarked
            ? [
                BoxShadow(
                  color: AppTheme.cellMarked.withValues(alpha: 0.4),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Center(
        child: isFreeSpace
            ? Icon(
                Icons.star_rounded,
                color: isMarked ? Colors.white : AppTheme.freeSpaceStar,
                size: readOnly ? 12 : 16,
              )
            : Text(
                '$value',
                style: (isMarked ? AppTheme.cellMarkedStyle : AppTheme.cellNumberStyle).copyWith(
                  fontSize: readOnly ? 9 : 13,
                  color: textColor,
                ),
              ),
      ),
    );

    // If interactive, allow tapping individual cells to select / deselect
    if (!readOnly && !locked && !isLost && onCellTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onCellTap!(index),
        child: cellWidget,
      );
    }

    return cellWidget;
  }

  Widget _buildBingoButton() {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: (locked || isLost || isBingoPending) ? null : onBingoPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.bingoButton,
          disabledBackgroundColor: isLost ? Colors.grey.shade700 : Colors.grey.shade400,
          elevation: isLost ? 0 : 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child: isBingoPending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flash_on, color: Colors.white, size: 15),
                  const SizedBox(width: 3),
                  Text(
                    isLost ? 'LOCKED' : 'BINGO',
                    style: AppTheme.buttonTextStyle.copyWith(
                      fontSize: 13,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
