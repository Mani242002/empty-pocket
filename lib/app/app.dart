import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/presentation/widgets/app_lock_gate.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'presentation/screens/main_navigation_scaffold.dart';

/// The root application widget for EmptyPocket
class EmptyPocketApp extends ConsumerWidget {
  const EmptyPocketApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'EmptyPocket',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.15,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppLockGate(
        child: MainNavigationScaffold(),
      ),
    );
  }
}
