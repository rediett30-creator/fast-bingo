import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Live countdown widget that computes remaining time against an absolute
/// epoch timestamp (`startsAt` in seconds), avoiding drift from message latency.
class CountdownTimerWidget extends StatefulWidget {
  final double startsAtEpoch; // in seconds
  final VoidCallback? onFinished;

  const CountdownTimerWidget({
    super.key,
    required this.startsAtEpoch,
    this.onFinished,
  });

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updateRemaining();
    });
  }

  @override
  void didUpdateWidget(covariant CountdownTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startsAtEpoch != widget.startsAtEpoch) {
      _updateRemaining();
    }
  }

  void _updateRemaining() {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final diff = (widget.startsAtEpoch - nowSeconds).ceil();
    final remaining = diff > 0 ? diff : 0;

    if (remaining != _remainingSeconds) {
      setState(() {
        _remainingSeconds = remaining;
      });
      if (remaining <= 0) {
        _timer?.cancel();
        widget.onFinished?.call();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.badgeBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_outlined,
            color: AppTheme.bingoI,
            size: 28,
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GAME STARTING IN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                _formatTime(_remainingSeconds),
                style: AppTheme.headerStyle.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.bingoI,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
