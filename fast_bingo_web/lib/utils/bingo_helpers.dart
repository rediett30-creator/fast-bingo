import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Maps bingo numbers (1-75) to their column index (0-4 = B/I/N/G/O).
int getColumnFromValue(int value) {
  if (value <= 15) return 0; // B
  if (value <= 30) return 1; // I
  if (value <= 45) return 2; // N
  if (value <= 60) return 3; // G
  return 4; // O
}

/// Returns the B-I-N-G-O color for a given column index (0-4).
Color getColumnColor(int columnIndex) {
  return AppTheme.bingoColors[columnIndex.clamp(0, 4)];
}

/// Returns the B-I-N-G-O color for a given bingo number value (1-75).
Color getColorForValue(int value) {
  return getColumnColor(getColumnFromValue(value));
}

/// Returns the B/I/N/G/O letter for a column index.
String getColumnLetter(int columnIndex) {
  return AppTheme.bingoLetters[columnIndex.clamp(0, 4)];
}

/// Given a flat grid index (0-24), returns the column index (0-4).
int getColumnFromGridIndex(int gridIndex) {
  return gridIndex % 5;
}
