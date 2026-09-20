import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../features/settings/presentation/state/backup_provider.dart';
import '../../services/log_service.dart';
import '../../services/security_service.dart';

final securityServiceProvider = Provider<SecurityService>((ref) => SecurityService());

class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  static bool isSessionUnlocked = false;
  static DateTime? _pausedAt;
  static const Duration _graceDuration = Duration(seconds: 60);
  bool _isAuthenticating = false;
  bool _isHardwareUnavailable = false;

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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final isLockEnabled = ref.read(appLockProvider).valueOrNull ?? false;
      if (isLockEnabled && isSessionUnlocked && _pausedAt != null) {
        final timeInBackground = DateTime.now().difference(_pausedAt!);
        if (timeInBackground > _graceDuration) {
          setState(() {
            isSessionUnlocked = false;
          });
          _checkLockStatus();
        }
      }
      _pausedAt = null;
    }
  }

  Future<void> _checkLockStatus() async {
    final isLockEnabled = ref.read(appLockProvider).valueOrNull ?? false;
    if (!isLockEnabled || isSessionUnlocked) {
      if (mounted) setState(() {});
      return;
    }

    final security = ref.read(securityServiceProvider);
    final isAvailable = await security.isBiometricsAvailable();
    if (!isAvailable) {
      if (mounted) {
        setState(() {
          _isHardwareUnavailable = true;
        });
      }
      return;
    } else if (_isHardwareUnavailable && mounted) {
      setState(() {
        _isHardwareUnavailable = false;
      });
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
      final isAvailable = await security.isBiometricsAvailable();
      if (!isAvailable) {
        if (mounted) {
          setState(() {
            _isHardwareUnavailable = true;
            _isAuthenticating = false;
          });
        }
        return;
      }

      final success = await security.authenticate(
        reason: 'Authenticate to access your EmptyPocket financial vault',
      );

      if (success) {
        isSessionUnlocked = true;
        _isHardwareUnavailable = false;
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.heavyImpact();
      }

      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    } catch (e, st) {
      LogService.error('AppLockGate', 'Authentication error', e, st);
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
      error: (err, st) {
        LogService.error('AppLockGate', 'App lock state error', err, st);
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
              if (_isHardwareUnavailable) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(isDark ? 35 : 20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withAlpha(isDark ? 80 : 50),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No device lock, PIN, or biometric credentials detected on this device. You can disable the vault lock below to regain access.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // Unlock Action Button or Disable Lock Option
              if (_isHardwareUnavailable) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.lock_open_rounded, size: 22),
                    label: const Text(
                      'Disable Vault Lock',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Disable Vault Lock?'),
                          content: const Text(
                            'No biometric credentials or device PIN were detected on this device.\n\n'
                            'Disabling vault lock will remove authentication protection until you re-enable it in Settings.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.warning,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Confirm Disable'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await ref.read(appLockProvider.notifier).toggleAppLock(false);
                        if (mounted) {
                          setState(() {
                            isSessionUnlocked = true;
                            _isHardwareUnavailable = false;
                          });
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryEmerald,
                      side: const BorderSide(color: AppColors.primaryEmerald),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text(
                      'Retry Authentication',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    onPressed: _checkLockStatus,
                  ),
                ),
              ] else ...[
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
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
