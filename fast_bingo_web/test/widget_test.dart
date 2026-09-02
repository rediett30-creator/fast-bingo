import 'package:flutter_test/flutter_test.dart';
import 'package:fast_bingo_web/main.dart';

void main() {
  testWidgets('Fast Bingo App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FastBingoApp());
    expect(find.text('FAST BINGO'), findsOneWidget);
  });
}
