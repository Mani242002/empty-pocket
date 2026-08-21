import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:empty_pocket/app/app.dart';

void main() {
  testWidgets('EmptyPocket app shell loads and displays dashboard destinations',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EmptyPocketApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify app brand title is displayed
    expect(find.text('EmptyPocket'), findsOneWidget);

    // Verify Net Balance section exists
    expect(find.text('TOTAL NET BALANCE'), findsOneWidget);

    // Verify 4 Navigation destinations exist
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Tap on Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Verify Settings screen elements
    expect(find.text('Theme Mode'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('100% On-Device (Encrypted SQLite)'), findsOneWidget);

    // Tap on Transactions tab
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();

    // Verify Transactions screen elements
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
  });
}
