import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../state/buy_cards_state.dart';
import '../theme/app_theme.dart';
import '../widgets/bingo_card_widget.dart';
import '../widgets/gradient_background.dart';

/// Screen allowing players to browse available cards for the round,
/// multi-select cards, view running price totals, and purchase.
/// Gracefully handles partial failures (e.g. 409 race conditions).
class BuyCardsScreen extends StatefulWidget {
  final GameWithPattern game;

  const BuyCardsScreen({super.key, required this.game});

  @override
  State<BuyCardsScreen> createState() => _BuyCardsScreenState();
}

class _BuyCardsScreenState extends State<BuyCardsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BuyCardsState>().loadCards(widget.game.id);
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<BuyCardsState>().loadMore(widget.game.id);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handlePurchase() async {
    final buyState = context.read<BuyCardsState>();
    final allSuccess = await buyState.purchaseSelected(widget.game.id);

    if (!mounted) return;

    if (allSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cards purchased successfully! Good luck! 🎉'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      Navigator.of(context).pop();
    } else {
      // Partial failure occurred: show dialog with exact details
      _showPartialFailureDialog(buyState);
    }
  }

  void _showPartialFailureDialog(BuyCardsState buyState) {
    final results = buyState.lastPurchaseResults;
    final successes = results.where((r) => r.success).toList();
    final failures = results.where((r) => !r.success).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.badgeBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.bingoI, size: 28),
            SizedBox(width: 10),
            Text(
              'Purchase Summary',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (successes.isNotEmpty) ...[
              Text(
                '✅ ${successes.length} card(s) purchased successfully!',
                style: const TextStyle(
                  color: AppTheme.successGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (failures.isNotEmpty) ...[
              const Text(
                '⚠️ The following cards could not be purchased:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...failures.map((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      '• Card #${f.cardId}: ${f.errorMessage}',
                      style: const TextStyle(
                        color: AppTheme.errorRed,
                        fontSize: 13,
                      ),
                    ),
                  )),
            ],
          ],
        ),
        actions: [
          if (failures.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _handlePurchase(); // Retry remaining failed selections
              },
              child: const Text(
                'Retry Failed',
                style: TextStyle(
                  color: AppTheme.bingoI,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (successes.isNotEmpty) {
                Navigator.of(context).pop(); // Return to dashboard
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.bingoButton,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buyState = context.watch<BuyCardsState>();
    final selectedCount = buyState.selectedCount;
    final totalPrice = selectedCount * widget.game.cardPrice;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Header Bar ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Your Cards',
                            style: AppTheme.headerStyle.copyWith(fontSize: 18),
                          ),
                          Text(
                            'Price: ${widget.game.cardPrice} ₿ per card',
                            style: AppTheme.emptyStateStyle.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (buyState.cards.isNotEmpty)
                      Text(
                        '${buyState.cards.length}/${buyState.total} Available',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),

              // ── Cards Grid ──────────────────────────────────────────────
              Expanded(
                child: buyState.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : buyState.errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
                                  const SizedBox(height: 12),
                                  Text(
                                    buyState.errorMessage!,
                                    style: AppTheme.emptyStateStyle,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => buyState.loadCards(widget.game.id),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : buyState.cards.isEmpty
                            ? Center(
                                child: Text(
                                  'No cards available for this game',
                                  style: AppTheme.emptyStateStyle,
                                ),
                              )
                            : GridView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.88,
                                ),
                                itemCount: buyState.cards.length + (buyState.hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= buyState.cards.length) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                    );
                                  }

                                  final card = buyState.cards[index];
                                  final isSelected = buyState.selectedCardIds.contains(card.id);

                                  return BingoCardWidget(
                                    grid: card.grid,
                                    readOnly: true,
                                    isSelected: isSelected,
                                    cardId: card.id,
                                    onTap: () {
                                      buyState.toggleSelection(card.id);
                                    },
                                  );
                                },
                              ),
              ),

              // ── Floating Bottom Purchase Bar ────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.badgeBackground,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$selectedCount card${selectedCount == 1 ? '' : 's'} selected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Total: $totalPrice ₿',
                          style: const TextStyle(
                            color: AppTheme.bingoI,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: (selectedCount == 0 || buyState.isPurchasing)
                          ? null
                          : _handlePurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.bingoButton,
                        disabledBackgroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      ),
                      child: buyState.isPurchasing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Buy ($totalPrice ₿)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
