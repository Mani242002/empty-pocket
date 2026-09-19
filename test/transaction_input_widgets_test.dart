import 'package:empty_pocket/app/theme/app_theme.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/utilities/currency_formatter.dart';
import 'package:empty_pocket/features/transactions/presentation/widgets/amount_calculator_field.dart';
import 'package:empty_pocket/features/transactions/presentation/widgets/transaction_type_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Transaction Input Widgets Tests', () {
    testWidgets('TransactionTypeToggle displays all segments and responds to taps', (tester) async {
      TransactionType currentType = TransactionType.expense;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return TransactionTypeToggle(
                  selectedType: currentType,
                  onTypeChanged: (newType) {
                    setState(() {
                      currentType = newType;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);

      // Tap on 'Income'
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      expect(currentType, TransactionType.income);

      // Tap on 'Transfer'
      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();
      expect(currentType, TransactionType.transfer);

      // Tap on 'Expense'
      await tester.tap(find.text('Expense'));
      await tester.pumpAndSettle();
      expect(currentType, TransactionType.expense);
    });

    testWidgets('AmountCalculatorField renders with dynamic currency and handles quick add', (tester) async {
      final controller = TextEditingController(text: '250');
      String? changedVal;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AmountCalculatorField(
              controller: controller,
              activeAccentColor: Colors.blue,
              onChanged: (val) {
                changedVal = val;
              },
            ),
          ),
        ),
      );

      // Check for AMOUNT label and prefix icon
      expect(find.text('AMOUNT'), findsOneWidget);
      expect(find.text(CurrencyFormatter.activeCurrency.symbol), findsAtLeastNWidgets(1));

      // Tap on '+₹500' or dynamic symbol
      final symbol = CurrencyFormatter.activeCurrency.symbol;
      final chipFinder = find.text('+$symbol' '500');
      expect(chipFinder, findsOneWidget);

      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // 250 + 500 = 750
      expect(controller.text, '750');
      expect(changedVal, '750');

      // Tap on '+100'
      final chip100 = find.text('+$symbol' '100');
      await tester.tap(chip100);
      await tester.pumpAndSettle();

      // 750 + 100 = 850
      expect(controller.text, '850');
      expect(changedVal, '850');
    });

    testWidgets('AmountCalculatorField validator rejects empty and invalid text', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Form(
              key: formKey,
              child: AmountCalculatorField(
                controller: controller,
                activeAccentColor: Colors.teal,
              ),
            ),
          ),
        ),
      );

      // Empty validation
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Please enter amount'), findsOneWidget);

      // Invalid characters (not a number)
      controller.text = 'abc';
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Invalid number'), findsOneWidget);

      // Valid number
      controller.text = '450.50';
      expect(formKey.currentState!.validate(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Invalid number'), findsNothing);

      // Valid math expression
      controller.text = '120 + 45';
      expect(formKey.currentState!.validate(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Invalid number'), findsNothing);
    });

    testWidgets('AmountCalculatorField allows typing math expression and evaluates on quick chip tap', (tester) async {
      final controller = TextEditingController();
      String? lastChanged;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AmountCalculatorField(
              controller: controller,
              activeAccentColor: Colors.blue,
              onChanged: (val) {
                lastChanged = val;
              },
            ),
          ),
        ),
      );

      // Enter math expression with operators into the field
      await tester.enterText(find.byType(TextFormField), '120 + 45');
      await tester.pumpAndSettle();

      // Operators (+, space) should be preserved by input formatters
      expect(controller.text, '120 + 45');

      // Tap +100 chip
      final symbol = CurrencyFormatter.activeCurrency.symbol;
      final chip100 = find.text('+$symbol' '100');
      await tester.tap(chip100);
      await tester.pumpAndSettle();

      // (120 + 45) = 165, then + 100 = 265
      expect(controller.text, '265');
      expect(lastChanged, '265');
      expect(controller.selection.baseOffset, 3);
    });

    testWidgets('AmountCalculatorField supports parentheses in expressions', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();
      String? lastChanged;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Form(
              key: formKey,
              child: AmountCalculatorField(
                controller: controller,
                activeAccentColor: Colors.blue,
                onChanged: (val) {
                  lastChanged = val;
                },
              ),
            ),
          ),
        ),
      );

      // Enter expression with parentheses
      await tester.enterText(find.byType(TextFormField), '(50 + 25) * 4');
      await tester.pumpAndSettle();

      expect(controller.text, '(50 + 25) * 4');
      expect(formKey.currentState!.validate(), isTrue);

      // Tap +100 quick chip
      final symbol = CurrencyFormatter.activeCurrency.symbol;
      final chip100 = find.text('+$symbol' '100');
      await tester.tap(chip100);
      await tester.pumpAndSettle();

      // (50 + 25) * 4 = 300, + 100 = 400
      expect(controller.text, '400');
      expect(lastChanged, '400');
    });
  });
}
