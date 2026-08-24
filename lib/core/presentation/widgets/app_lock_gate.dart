import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../features/settings/presentation/state/backup_provider.dart';
import '../../services/security_service.dart';

final securityServiceProvider = Provider<SecurityService>((ref) => SecurityService());

class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  static bool isSessionUnlocked = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLockStatus();
    });
  }

  Future<void> _checkLockStatus() async {
    final isLockEnabled = ref.read(appLockProvider).valueOrNull ?? false;
    if (!isLockEnabled || isSessionUnlocked) {
      if (mounted) setState(() {});
      return;
    }

    if (!isSessionUnlocked && !_isAuthenticating) {
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

      if (success) {
        isSessionUnlocked = true;
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.heavyImpact();
      }

      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      debugPrint('[AppLockGate] Authentication error: $e');
      await HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLockAsync = ref.watch(appLockProvider);

    return appLockAsync.when(
      data: (isLockEnabled) {
        if (!isLockEnabled || isSessionUnlocked) {
          return widget.child;
        }
        return _buildLockScreen(context);
      },
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        body: const SizedBox.shrink(),
      ),
      error: (err, _) {
        debugPrint('[AppLockGate] App lock state error: $err');
        return widget.child;
      },
    );
  }

  Widget _buildLockScreen(BuildContext context) {
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
              // Security Shield Emblem with EP Logo
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: AppColors.primaryEmerald.withAlpha(120), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryEmerald.withAlpha(60),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.shield_rounded,
                      size: 48,
                      color: AppColors.primaryEmerald,
                    ),
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
