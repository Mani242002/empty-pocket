import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'features/overlay/presentation/screens/floating_bubble_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: EmptyPocketApp(),
    ),
  );
}

/// Dedicated entrypoint for the Android 24/7 Floating Bubble / System Alert Window
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FloatingBubbleOverlayApp());
}
