import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Renders the signature deep purple-to-violet gradient with a subtle
/// repeating dot pattern texture to give depth and avoid a flat look.
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.gradientStart,
            AppTheme.gradientEnd,
          ],
        ),
      ),
      child: CustomPaint(
        painter: const _DotTexturePainter(),
        child: child,
      ),
    );
  }
}

class _DotTexturePainter extends CustomPainter {
  const _DotTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.dotColor
      ..style = PaintingStyle.fill;

    const spacing = 24.0;
    const radius = 1.5;

    for (double y = 8.0; y < size.height; y += spacing) {
      for (double x = 8.0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
