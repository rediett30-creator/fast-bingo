import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small stat badge: dark charcoal/navy translucent pill with icon + text.
/// Reused across screens for timer, card price, total award, game status, etc.
class StatBadge extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color? iconColor;
  final Color? textColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const StatBadge({
    super.key,
    this.icon,
    required this.text,
    this.iconColor,
    this.textColor,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.badgeBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: iconColor ?? Colors.white.withOpacity(0.9),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: AppTheme.badgeTextStyle.copyWith(
              color: textColor ?? AppTheme.badgeText,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: badge,
      );
    }
    return badge;
  }
}
