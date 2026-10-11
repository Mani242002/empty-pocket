import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/presentation/widgets/app_lock_gate.dart';
import 'package:empty_pocket/features/settings/presentation/state/backup_provider.dart';

class _UnavailableAppLockNotifier extends AppLockNotifier {
  @override
  Future<bool> build() async => throw StateError('preferences unavailable');
}

void main() {
  testWidgets('does not reveal app content when lock state cannot be read', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockProvider.overrideWith(_UnavailableAppLockNotifier.new),
        ],
        child: const MaterialApp(
          home: AppLockGate(child: Text('Protected financial data')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vault status unavailable'), findsOneWidget);
    expect(find.text('Protected financial data'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('lock error screen remains scrollable with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockProvider.overrideWith(_UnavailableAppLockNotifier.new),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 360),
              textScaler: TextScaler.linear(2),
            ),
            child: const AppLockGate(child: Text('Protected financial data')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Vault status unavailable'), findsOneWidget);
  });
}
