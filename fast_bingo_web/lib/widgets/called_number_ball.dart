import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/bingo_helpers.dart';

/// One ball bubble for the recent calls row or announcement.
/// Circular, colored by B-I-N-G-O column, white bold number, thin white border.
/// If [isLatest] is true, draws an outer glowing ring.
class CalledNumberBall extends StatelessWidget {
  final int number;
  final bool isLatest;
  final double size;

  const CalledNumberBall({
    super.key,
    required this.number,
    this.isLatest = false,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    final color = getColorForValue(number);
    final colIndex = getColumnFromValue(number);
    final letter = getColumnLetter(colIndex);

    return Container(
      width: isLatest ? size + 10 : size,
      height: isLatest ? size + 10 : size,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring for latest ball
          if (isLatest)
            Container(
              width: size + 8,
              height: size + 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.85),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.6),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),

          // Ball body
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                radius: 0.8,
                colors: [
                  Color.lerp(color, Colors.white, 0.45)!,
                  color,
                  Color.lerp(color, Colors.black, 0.3)!,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.9),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  letter,
                  style: TextStyle(
                    fontSize: size * 0.22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.0,
                  ),
                ),
                Text(
                  '$number',
                  style: AppTheme.ballNumberStyle.copyWith(
                    fontSize: size * 0.38,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
