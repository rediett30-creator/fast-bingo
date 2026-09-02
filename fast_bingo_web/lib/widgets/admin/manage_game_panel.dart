import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/game.dart';
import '../../state/admin_state.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../bingo_card_widget.dart';
import '../called_number_ball.dart';
import '../countdown_timer.dart';
import '../stat_badge.dart';

/// Admin control panel for managing an active or pending bingo round.
/// Includes game deletion, start countdown triggering, live number monitoring,
/// and post-game reset.
class ManageGamePanel extends StatefulWidget {
  final GameWithPattern game;

  const ManageGamePanel({super.key, required this.game});

  @override
  State<ManageGamePanel> createState() => _ManageGamePanelState();
}

class _ManageGamePanelState extends State<ManageGamePanel> {
  final _countdownController = TextEditingController(text: '30');

  @override
  void dispose() {
    _countdownController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.badgeBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_forever_rounded, color: AppTheme.errorRed, size: 24),
            SizedBox(width: 8),
            Text('Delete Game', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete Game #${widget.game.id}? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final adminState = context.read<AdminState>();
      final success = await adminState.deleteGame(widget.game.id);
      if (success && mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Game deleted successfully.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    }
  }

  void _handleStartGame(BuildContext context) {
    int seconds = int.tryParse(_countdownController.text.trim()) ?? 30;
    // Client-side clamp 10 - 120
    seconds = seconds.clamp(10, 120);

    final authState = context.read<AuthState>();
    final adminState = context.read<AdminState>();

    adminState.startGame(
      countdownSeconds: seconds,
      token: authState.token,
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminState = context.watch<AdminState>();
    final game = adminState.currentGame ?? widget.game;
    final isPending = adminState.status == GameStatus.pending;
    final isActive = adminState.status == GameStatus.active;
    final isFinished = adminState.isGameFinished || adminState.isPoolExhausted || adminState.status == GameStatus.finished;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Backend Error Banner ────────────────────────────────────────
          if (adminState.errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.errorRed.withValues(alpha: 0.8),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      adminState.errorMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                    onPressed: adminState.clearErrorMessage,
                  ),
                ],
              ),
            ),

          // ── Game Overview Card ──────────────────────────────────────────
          _buildOverviewCard(game, adminState),
          const SizedBox(height: 16),

          // ── PENDING STATE: Delete & Start Game Controls ─────────────────
          if (isPending && !adminState.isCountdownActive) ...[
            _buildStartGameControl(context, adminState),
            const SizedBox(height: 16),
            _buildDeleteControl(context, adminState),
          ],

          // ── COUNTDOWN STATE ─────────────────────────────────────────────
          if (isPending && adminState.countdownStartsAt != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: CountdownTimerWidget(
                startsAtEpoch: adminState.countdownStartsAt!,
              ),
            ),
          ],

          // ── LIVE ACTIVE STATE: Number Feed ──────────────────────────────
          if (isActive || adminState.calledNumbers.isNotEmpty) ...[
            _buildLiveMonitorSection(adminState),
          ],

          // ── FINISHED / EXHAUSTED STATE: Result Summary & New Game ───────
          if (isFinished) ...[
            const SizedBox(height: 16),
            _buildResultSummary(context, adminState),
          ],
        ],
      ),
    );
  }

  // ── Overview Card ───────────────────────────────────────────────────────
  Widget _buildOverviewCard(GameWithPattern game, AdminState adminState) {
    final statusText = adminState.status == GameStatus.active
        ? 'LIVE'
        : adminState.status == GameStatus.pending
            ? 'PENDING'
            : 'FINISHED';

    final statusColor = adminState.status == GameStatus.active
        ? AppTheme.bingoN
        : adminState.status == GameStatus.pending
            ? AppTheme.bingoI
            : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.badgeBackground.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'GAME #${game.id}',
                    style: AppTheme.headerStyle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatBadge(
                    text: statusText,
                    textColor: statusColor,
                    backgroundColor: statusColor.withValues(alpha: 0.2),
                  ),
                ],
              ),
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
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          // Pattern info
          Row(
            children: [
              _buildMiniPatternGrid(game.pattern.coveredCells),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pattern: ${game.pattern.name}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      game.pattern.description,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPatternGrid(List<int> coveredCells) {
    final coveredSet = Set<int>.from(coveredCells);
    coveredSet.add(12);

    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF130D24),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
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

  // ── Start Game Controls ─────────────────────────────────────────────────
  Widget _buildStartGameControl(BuildContext context, AdminState adminState) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.badgeBackground.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.bingoButton.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.timer_outlined, color: AppTheme.bingoI, size: 20),
              SizedBox(width: 8),
              Text(
                'Start Game Countdown',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Countdown duration (10 – 120 seconds):',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _countdownController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      suffixText: 'seconds',
                      suffixStyle: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _handleStartGame(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.bingoButton,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                label: const Text(
                  'Start',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Delete Game Control ─────────────────────────────────────────────────
  Widget _buildDeleteControl(BuildContext context, AdminState adminState) {
    return OutlinedButton.icon(
      onPressed: adminState.isSubmitting ? null : () => _handleDelete(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.errorRed,
        side: BorderSide(color: AppTheme.errorRed.withValues(alpha: 0.7)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: const Icon(Icons.delete_outline, size: 18),
      label: Text(
        adminState.isSubmitting ? 'Deleting...' : 'Delete Pending Game',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    );
  }

  // ── Live Monitor Section ────────────────────────────────────────────────
  Widget _buildLiveMonitorSection(AdminState adminState) {
    final numbers = adminState.calledNumbers;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.badgeBackground.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.radar_rounded, color: AppTheme.bingoN, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Live Called Numbers Feed',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Text(
                '${numbers.length} called',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (numbers.isEmpty)
            Container(
              height: 56,
              alignment: Alignment.center,
              child: const Text(
                'Waiting for caller engine to draw numbers...',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            )
          else
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: numbers.length,
                itemBuilder: (context, index) {
                  final number = numbers[index];
                  final isLatest = index == 0;
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
            ),
        ],
      ),
    );
  }

  // ── Result Summary & New Game Action ────────────────────────────────────
  Widget _buildResultSummary(BuildContext context, AdminState adminState) {
    final hasWinner = adminState.winnerName != null;
    final isPoolExhausted = adminState.isPoolExhausted;

    Color bannerColor = hasWinner
        ? AppTheme.bingoN
        : isPoolExhausted
            ? Colors.grey.shade800
            : AppTheme.gradientEnd;
    String title = hasWinner
        ? '🏆 Game Completed — Winner: ${adminState.winnerName}'
        : isPoolExhausted
            ? 'All 75 Numbers Called — No Winner'
            : 'Game Finished';
    String subtitle = hasWinner
        ? 'Winning Card #${adminState.winningCardId ?? ""} claimed the prize'
        : isPoolExhausted
            ? 'The number pool was exhausted without any valid claim'
            : 'Round has concluded';

    return Container(
      padding: const EdgeInsets.all(14),
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
              Icon(hasWinner ? Icons.emoji_events : Icons.info_outline, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),

          // Render winning grid preview if available
          if (hasWinner && adminState.winningGrid != null) ...[
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxWidth: 180),
              child: BingoCardWidget(
                grid: adminState.winningGrid!,
                readOnly: true,
                isWinningCard: true,
                cardId: adminState.winningCardId,
              ),
            ),
          ],

          const SizedBox(height: 14),

          // "New Game" button -> switches back to CreateGameForm
          ElevatedButton.icon(
            onPressed: () {
              adminState.resetToCreateForm();
            },
            icon: const Icon(Icons.add, color: Colors.white, size: 20),
            label: const Text(
              'Create Next Game',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.badgeBackground,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
