import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/game.dart';
import '../../state/admin_state.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';

/// Form for creating a new game round (Admin only).
/// Collects card_price, total_award, and selects target win pattern.
class CreateGameForm extends StatefulWidget {
  const CreateGameForm({super.key});

  @override
  State<CreateGameForm> createState() => _CreateGameFormState();
}

class _CreateGameFormState extends State<CreateGameForm> {
  final _formKey = GlobalKey<FormState>();
  final _cardPriceController = TextEditingController(text: '10');
  final _totalAwardController = TextEditingController(text: '100');
  int? _selectedPatternId;

  @override
  void dispose() {
    _cardPriceController.dispose();
    _totalAwardController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPatternId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a target win pattern.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    final cardPrice = int.parse(_cardPriceController.text.trim());
    final totalAward = int.parse(_totalAwardController.text.trim());
    final authState = context.read<AuthState>();
    final adminState = context.read<AdminState>();

    final success = await adminState.createGame(
      cardPrice: cardPrice,
      totalAward: totalAward,
      patternId: _selectedPatternId!,
      token: authState.token,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game created successfully! Ready for players.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminState = context.watch<AdminState>();
    final patterns = adminState.patterns;

    // Set default pattern if not yet selected
    if (_selectedPatternId == null && patterns.isNotEmpty) {
      _selectedPatternId = patterns.first.id;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Form Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.badgeBackground.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.bingoButton.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppTheme.bingoButton,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New Bingo Round',
                          style: AppTheme.headerStyle.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Configure the entry price, prize award, and winning shape.',
                          style: AppTheme.emptyStateStyle.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Backend Error Banner ──────────────────────────────────────
            if (adminState.errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
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
                  ],
                ),
              ),

            // ── Numeric Fields (Card Price & Total Award) ─────────────────
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    controller: _cardPriceController,
                    label: 'Card Price (₿)',
                    icon: Icons.confirmation_number_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField(
                    controller: _totalAwardController,
                    label: 'Total Award (₿)',
                    icon: Icons.emoji_events_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Pattern Selection ─────────────────────────────────────────
            Text(
              'Select Target Win Pattern',
              style: AppTheme.subheaderStyle.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 8),

            if (patterns.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.badgeBackground.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Loading patterns...',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              )
            else
              Column(
                children: patterns.map((pattern) {
                  final isSelected = _selectedPatternId == pattern.id;
                  return _buildPatternRadioCard(pattern, isSelected);
                }).toList(),
              ),

            const SizedBox(height: 24),

            // ── Submit Button ─────────────────────────────────────────────
            ElevatedButton(
              onPressed: adminState.isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.bingoButton,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: adminState.isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Create Game',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.badgeBackground.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          icon: Icon(icon, color: AppTheme.bingoI, size: 20),
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          errorStyle: const TextStyle(fontSize: 11, color: AppTheme.errorRed),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Required';
          }
          final n = int.tryParse(value.trim());
          if (n == null || n <= 0) {
            return 'Must be > 0';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPatternRadioCard(PatternModel pattern, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPatternId = pattern.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.gradientEnd.withValues(alpha: 0.45)
              : AppTheme.badgeBackground.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.bingoButton : Colors.white.withValues(alpha: 0.12),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.bingoButton.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Mini 5x5 pattern shape preview
            _buildMiniPatternGrid(pattern.coveredCells, isSelected),
            const SizedBox(width: 12),
            // Pattern text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pattern.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pattern.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Radio<int>(
              value: pattern.id,
              groupValue: _selectedPatternId,
              activeColor: AppTheme.bingoButton,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedPatternId = val;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPatternGrid(List<int> coveredCells, bool isSelected) {
    final coveredSet = Set<int>.from(coveredCells);
    coveredSet.add(12); // Free space

    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF130D24),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? AppTheme.bingoButton.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.2),
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
                              ? (isSelected ? AppTheme.bingoN : AppTheme.cellMarked)
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
}
