import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../services/ws_service.dart';
import '../state/auth_state.dart';
import '../state/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/bingo_card_widget.dart';
import '../widgets/called_number_ball.dart';
import '../widgets/countdown_timer.dart';
import '../widgets/gradient_background.dart';
import '../widgets/stat_badge.dart';
import 'buy_cards_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final authState = context.read<AuthState>();
    context.read<GameState>().loadCurrentGame(authState.token);
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.badgeBackground,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final gameState = context.watch<GameState>();

    // Listen for transient toast messages
    if (gameState.bingoToastMessage != null) {
      final msg = gameState.bingoToastMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showToast(
          msg,
          isError:
              msg.toLowerCase().contains('lost') ||
              msg.toLowerCase().contains('late'),
        );
        gameState.clearToasts();
      });
    }

    if (gameState.wsToastMessage != null) {
      final msg = gameState.wsToastMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showToast(msg, isError: true);
        gameState.clearToasts();
      });
    }

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: gameState.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : gameState.hasNoGame
              ? _buildNoGameView()
              : gameState.currentGame == null
              ? _buildErrorView(gameState.errorMessage ?? 'Could not load game')
              : _buildGameView(gameState, authState),
        ),
      ),
    );
  }

  Widget _buildNoGameView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_empty_rounded,
                size: 64,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Game Open Right Now',
              style: AppTheme.headerStyle.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'A new bingo round will start soon. Pull or tap to check again!',
              style: AppTheme.emptyStateStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.bingoButton,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text(
              'Connection Issue',
              style: AppTheme.headerStyle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTheme.emptyStateStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameView(GameState gameState, AuthState authState) {
    final game = gameState.currentGame!;
    final isPending = gameState.status == GameStatus.pending;
    final isFinished = gameState.isGameFinished || gameState.isPoolExhausted;
    final isAllLost = gameState.isAllCardsLost;

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      color: AppTheme.bingoButton,
      backgroundColor: AppTheme.badgeBackground,
      child: Column(
        children: [
          _buildTopBar(game, gameState),

          _buildPatternCard(game),

          if (isPending && gameState.countdownStartsAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: CountdownTimerWidget(
                startsAtEpoch: gameState.countdownStartsAt!,
              ),
            )
          else
            _buildCalledNumbersRow(gameState),

          if (isFinished)
            _buildFinishedBanner(gameState, authState)
          else if (isAllLost)
            _buildAllCardsLostBanner(),

          Expanded(
            child: gameState.myCards.isEmpty
                ? _buildEmptyCardsCTA(game)
                : _buildCardsGrid(gameState),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(GameWithPattern game, GameState gameState) {
    final statusText = gameState.status == GameStatus.active
        ? 'LIVE'
        : gameState.status == GameStatus.pending
        ? 'PENDING'
        : 'FINISHED';

    final statusColor = gameState.status == GameStatus.active
        ? AppTheme.bingoN
        : gameState.status == GameStatus.pending
        ? AppTheme.bingoI
        : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Price & Award badges
          Row(
            children: [
              StatBadge(
                icon: Icons.confirmation_number_outlined,
                text: '${game.cardPrice} ₿',
                iconColor: AppTheme.bingoI,
              ),
              const SizedBox(width: 6),
              StatBadge(
                icon: Icons.emoji_events_outlined,
                text: '${game.totalAward} ₿',
                iconColor: const Color(0xFFFFD54F),
              ),
            ],
          ),

          // Right: Status badge & Buy Cards button
          Row(
            children: [
              StatBadge(
                text: statusText,
                textColor: statusColor,
                backgroundColor: AppTheme.badgeBackground,
              ),
              if (gameState.connectionState ==
                  WsConnectionState.reconnecting) ...[
                const SizedBox(width: 6),
                const StatBadge(
                  icon: Icons.sync,
                  text: 'Reconnecting',
                  textColor: AppTheme.bingoI,
                ),
              ],
              const SizedBox(width: 6),
              InkWell(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BuyCardsScreen(game: game),
                    ),
                  );
                  if (!mounted) return;
                  gameState.refreshMyCards();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.bingoButton,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.bingoButton.withValues(alpha: 0.35),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.add_shopping_cart,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Buy',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Pattern Card (Item 1: Small card on top, ample space, visual mini-grid) ─
  Widget _buildPatternCard(GameWithPattern game) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.badgeBackground.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Visual mini 5x5 pattern shape preview
          _buildMiniPatternGrid(game.pattern.coveredCells),
          const SizedBox(width: 12),
          // Pattern name & full untruncated description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.bingoI,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'TARGET',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        game.pattern.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  game.pattern.description,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPatternGrid(List<int> coveredCells) {
    final coveredSet = Set<int>.from(coveredCells);
    coveredSet.add(12); // Free space always covered

    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF130D24),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: List.generate(5, (r) {
          return Expanded(
            child: Row(
              children: List.generate(5, (c) {
                final idx = r * 5 + c;
                final isCovered = coveredSet.contains(idx);
                final isCenter = idx == 12;

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isCenter
                          ? const Color(0xFFFFD54F)
                          : isCovered
                          ? AppTheme.cellMarked
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCalledNumbersRow(GameState gameState) {
    final numbers = gameState.calledNumbers;

    if (numbers.isEmpty) {
      return Container(
        height: 56,
        alignment: Alignment.center,
        child: Text(
          gameState.status == GameStatus.active
              ? 'Waiting for first number...'
              : 'Game not started yet',
          style: AppTheme.emptyStateStyle.copyWith(fontSize: 12),
        ),
      );
    }

    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: numbers.length,
        itemBuilder: (context, index) {
          final number = numbers[index];
          final isLatest = index == 0; // Most recent is at index 0

          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: Center(
              child: CalledNumberBall(
                number: number,
                isLatest: isLatest,
                size: isLatest ? 44 : 38,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAllCardsLostBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.errorRed.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.lock_clock_rounded, color: Colors.white, size: 22),
          SizedBox(width: 8),
          Text(
            'GAME OVER — ALL YOUR CARDS ARE LOCKED',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishedBanner(GameState gameState, AuthState authState) {
    final isWinner =
        gameState.winnerUserId != null &&
        gameState.winnerUserId == authState.userId;
    final isPoolExhausted = gameState.isPoolExhausted;

    Color bannerColor;
    String title;
    String subtitle;
    IconData icon;

    if (isPoolExhausted) {
      bannerColor = Colors.grey.shade800;
      title = 'NO WINNER THIS ROUND';
      subtitle = 'All 75 numbers were called. Better luck next round!';
      icon = Icons.sentiment_dissatisfied;
    } else if (isWinner) {
      bannerColor = AppTheme.bingoN;
      title = '🎉 VICTORY! YOU WON!';
      subtitle = 'Total award won: ${gameState.currentGame?.totalAward ?? 0} ₿';
      icon = Icons.emoji_events;
    } else {
      bannerColor = AppTheme.bingoO;
      title = '🏆 GAME OVER — ${gameState.winnerName ?? "Player"} Won!';
      subtitle =
          'Winning Card #${gameState.winningCardId ?? ""} displayed below:';
      icon = Icons.celebration;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),

          // Render winning grid if someone else won
          if (!isWinner &&
              !isPoolExhausted &&
              gameState.winningGrid != null) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 180),
              child: BingoCardWidget(
                grid: gameState.winningGrid!,
                markedIndices: gameState.getCardMarks(
                  gameState.winningCardId ?? -1,
                ),
                readOnly: true,
                isWinningCard: true,
                cardId: gameState.winningCardId,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Empty Cards CTA ─────────────────────────────────────────────────────
  Widget _buildEmptyCardsCTA(GameWithPattern game) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.style_outlined,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Cards for This Round',
              style: AppTheme.headerStyle.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Pick your lucky cards to dab numbers and win ${game.totalAward} ₿!',
              style: AppTheme.emptyStateStyle.copyWith(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BuyCardsScreen(game: game)),
                );
                if (!mounted) return;
                context.read<GameState>().refreshMyCards();
              },
              icon: const Icon(Icons.shopping_cart, size: 18),
              label: const Text('Buy Cards Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.bingoButton,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Modest Vertical Cards Grid (Items 2 & 4: Interactive Dabbing & Grid) ──
  Widget _buildCardsGrid(GameState gameState) {
    final cards = gameState.myCards;
    final isLocked = gameState.isGameFinished || gameState.isPoolExhausted;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final gameCard = cards[index];
        final cardId = gameCard.card.id;
        final isLost = gameState.isCardLost(cardId);
        final lostReason = gameState.getCardLostReason(cardId);
        final userMarks = gameState.getCardMarks(cardId);
        final isWinner =
            gameCard.isWinner ||
            (gameState.isGameFinished && gameState.winningCardId == cardId);

        return BingoCardWidget(
          grid: gameCard.card.grid,
          markedIndices: userMarks,
          locked: isLocked,
          isLost: isLost,
          lostReason: lostReason,
          isWinningCard: isWinner,
          isBingoPending: gameState.isCardBingoPending(cardId),
          cardId: cardId,
          // Item 2: User taps cells to select/deselect them manually
          onCellTap: (cellIndex) {
            gameState.toggleCellMark(cardId, cellIndex);
          },
          // Item 3: User taps Bingo button for this card
          onBingoPressed: () {
            gameState.claimBingo(cardId);
          },
        );
      },
    );
  }
}
