import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:empty_pocket/app/theme/app_theme.dart';
import 'package:empty_pocket/features/ai_assistant/presentation/screens/ai_settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AiSettingsScreen Revamp & Responsiveness Tests', () {
    testWidgets('renders cleanly on 320dp compact mobile width without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ProviderScope(
            child: AiSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Providers & BYOK Vault'), findsOneWidget);
      expect(find.text('ACTIVE ENGINE'), findsWidgets);
      expect(find.text('Intelligence Engine Hub'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly on 390dp standard mobile and allows switching categories', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProviderScope(
            child: AiSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Providers & BYOK Vault'), findsOneWidget);

      // Tap 'Speed & Open' category filter
      final speedChip = find.text('Speed & Open');
      expect(speedChip, findsOneWidget);
      await tester.ensureVisible(speedChip);
      await tester.tap(speedChip);
      await tester.pumpAndSettle();

      // Should show Groq, OpenRouter, DeepSeek
      expect(find.text('Groq (Fast LPUs)'), findsWidgets);
      expect(find.text('Meta / OpenRouter'), findsWidgets);
      expect(find.text('DeepSeek'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly on 768dp tablet width constrained to 720dp max-width', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ProviderScope(
            child: AiSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Providers & BYOK Vault'), findsOneWidget);
      expect(find.text('100% Private BYOK Architecture'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening info dialog displays BYOK Security & Privacy details', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ProviderScope(
            child: AiSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find info button in AppBar
      final infoButton = find.byIcon(Icons.info_outline_rounded);
      expect(infoButton, findsOneWidget);
      await tester.tap(infoButton);
      await tester.pumpAndSettle();

      expect(find.text('BYOK Security & Privacy'), findsOneWidget);
      expect(find.text('Hardware-Backed Encryption'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();
      expect(find.text('BYOK Security & Privacy'), findsNothing);
    });

    testWidgets('selecting Custom Endpoint shows Base URL presets and custom model manager', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ProviderScope(
            child: AiSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Filter to Local / Sovereign
      final localChip = find.text('Local / Sovereign');
      await tester.ensureVisible(localChip);
      await tester.tap(localChip);
      await tester.pumpAndSettle();

      // Tap Custom Endpoint tile
      final customTile = find.text('Custom Endpoint');
      expect(customTile, findsWidgets);
      await tester.ensureVisible(customTile.first);
      await tester.tap(customTile.first);
      await tester.pumpAndSettle();

      // Check presets exist
      expect(find.text('Ollama (Localhost)'), findsOneWidget);
      expect(find.text('LM Studio'), findsOneWidget);
      expect(find.text('vLLM'), findsOneWidget);

      // Tap a preset chip
      final lmStudioChip = find.text('LM Studio');
      await tester.ensureVisible(lmStudioChip);
      await tester.tap(lmStudioChip);
      await tester.pumpAndSettle();

      expect(find.text('http://10.0.2.2:1234/v1'), findsOneWidget);
    });
  });
}
