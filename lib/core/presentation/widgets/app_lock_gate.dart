import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../features/settings/presentation/state/backup_provider.dart';
import '../../services/security_service.dart';

final securityServiceProvider = Provider<SecurityService>((ref) => SecurityService());

class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  bool _isUnlocked = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLockStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isLockEnabled = ref.read(appLockProvider);
    if (!isLockEnabled) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (mounted) {
        setState(() {
          _isUnlocked = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      _checkLockStatus();
    }
  }

  Future<void> _checkLockStatus() async {
    final isLockEnabled = ref.read(appLockProvider);
    if (!isLockEnabled) {
      if (mounted) setState(() => _isUnlocked = true);
      return;
    }

    if (!_isUnlocked && !_isAuthenticating) {
      await _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    try {
      final security = ref.read(securityServiceProvider);
      final success = await security.authenticate(
        reason: 'Authenticate to access your EmptyPocket financial vault',
      );

      if (mounted) {
        setState(() {
          _isUnlocked = success;
          _isAuthenticating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLockEnabled = ref.watch(appLockProvider);

    // If lock is disabled or user is authenticated, show the app
    if (!isLockEnabled || _isUnlocked) {
      return widget.child;
    }

    // Otherwise show the secure Vault Lock Screen
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Security Shield Emblem
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryEmerald.withAlpha(25),
                  border: Border.all(color: AppColors.primaryEmerald.withAlpha(80), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryEmerald.withAlpha(40),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.primaryEmerald,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'EmptyPocket Vault',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Biometric authentication or device PIN is required to access your offline records.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              // Unlock Action Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isAuthenticating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.fingerprint_rounded, size: 24),
                  label: Text(
                    _isAuthenticating ? 'Verifying...' : 'Unlock Vault',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  onPressed: _isAuthenticating ? null : _authenticate,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
