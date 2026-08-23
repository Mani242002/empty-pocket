import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../ai_assistant/presentation/screens/ai_settings_screen.dart';
import '../../../ai_assistant/presentation/state/ai_assistant_provider.dart';
import '../../../../core/presentation/widgets/app_lock_gate.dart';
import '../state/backup_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showExportJsonDialog(BuildContext context, WidgetRef ref) async {
    try {
      final jsonStr = await ref.read(backupOperationsProvider.notifier).exportFullJsonBackup();
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.file_download_outlined, color: AppColors.primaryEmerald),
              SizedBox(width: 8),
              Text('Full Database Backup'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complete offline backup of your transactions, budgets, savings goals, loans, investments, and recurring bills.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    jsonStr,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy JSON'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Database backup copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.expense),
        );
      }
    }
  }

  void _showExportCsvDialog(BuildContext context, WidgetRef ref) async {
    try {
      final csvStr = await ref.read(backupOperationsProvider.notifier).exportTransactionsCsv();
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.table_chart_outlined, color: AppColors.primaryEmerald),
              SizedBox(width: 8),
              Text('Transactions CSV Export'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Spreadsheet-compatible CSV format with dates, amounts, categories, and payment methods.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    csvStr.isEmpty ? 'No transactions logged yet' : csvStr,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy CSV'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: csvStr));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('CSV transactions copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV export failed: $e'), backgroundColor: AppColors.expense),
        );
      }
    }
  }

  void _showRestoreSheet(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Restore Database from JSON',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Paste a previously exported EmptyPocket backup JSON. Restoring will replace existing local data.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              maxLines: 6,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Paste backup JSON string here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: const Text('Restore Database'),
                  onPressed: () async {
                    final text = textController.text.trim();
                    if (text.isEmpty) return;

                    try {
                      await ref.read(backupOperationsProvider.notifier).restoreFromJson(text);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Database restored successfully!'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.income,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Restore error: $e'),
                            backgroundColor: AppColors.expense,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFactoryResetDialog(BuildContext context, WidgetRef ref) {
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.expense),
            SizedBox(width: 8),
            Text('Factory Reset All Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will PERMANENTLY ERASE all transactions, budgets, savings goals, loans, investments, and recurring expenses from your device.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            const Text(
              'To confirm, please type DELETE below:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                hintText: 'DELETE',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () async {
              final input = confirmController.text.trim().toUpperCase();
              if (input == 'DELETE') {
                Navigator.pop(ctx);
                await ref.read(backupOperationsProvider.notifier).wipeAllData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All local data wiped. App reset to factory state.'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.primaryEmerald,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please type DELETE to confirm data wipe.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.warning,
                  ),
                );
              }
            },
            child: const Text('Wipe Everything'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final currentThemeMode = ref.watch(themeModeProvider);
    final isAppLockEnabled = ref.watch(appLockProvider);
    final isBubbleEnabled = ref.watch(floatingBubbleProvider);
    final aiConfig = ref.watch(aiProviderConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Privacy'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Section: Appearance
          _buildSectionHeader(context, 'Appearance'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme Mode',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto_rounded, size: 18),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_rounded, size: 18),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_rounded, size: 18),
                      ),
                    ],
                    selected: {currentThemeMode},
                    onSelectionChanged: (newSelection) {
                      ref.read(themeModeProvider.notifier).setThemeMode(newSelection.first);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section: PocketAI Advisor Configuration
          _buildSectionHeader(context, 'PocketAI Financial Advisor'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildListTile(
                  context,
                  icon: Icons.key_rounded,
                  iconColor: financialColors.investment,
                  title: 'AI Providers & BYOK Keys',
                  subtitle: aiConfig.isConfigured
                      ? 'Active: ${aiConfig.providerType.displayName} (${aiConfig.activeModelDisplayName})'
                      : 'Configure Gemini & Groq keys on device',
                  trailing: Icon(
                    aiConfig.isConfigured ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    color: aiConfig.isConfigured ? AppColors.income : AppColors.warning,
                    size: 20,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section: Privacy & App Security
          _buildSectionHeader(context, 'Privacy & App Security'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildListTile(
                  context,
                  icon: Icons.shield_outlined,
                  iconColor: financialColors.income,
                  title: 'Data Storage',
                  subtitle: '100% On-Device (Encrypted SQLite)',
                  trailing: const Icon(Icons.check_circle_rounded, color: AppColors.income, size: 20),
                ),
                const Divider(),
                _buildListTile(
                  context,
                  icon: Icons.wifi_off_rounded,
                  iconColor: financialColors.info,
                  title: 'Network Activity',
                  subtitle: 'Zero analytics / Zero background telemetry',
                  trailing: const Icon(Icons.check_circle_rounded, color: AppColors.income, size: 20),
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: financialColors.investment.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.lock_outline_rounded, color: financialColors.investment, size: 20),
                  ),
                  title: const Text('App Lock (Biometric / PIN)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    isAppLockEnabled ? 'Enabled (Requires authentication on open)' : 'Disabled',
                    style: TextStyle(color: financialColors.textMuted, fontSize: 12),
                  ),
                  value: isAppLockEnabled,
                  onChanged: (val) async {
                    if (val) {
                      final security = ref.read(securityServiceProvider);
                      final isAvailable = await security.isBiometricsAvailable();
                      if (!isAvailable && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No screen lock or biometric credentials configured on this device.'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.warning,
                          ),
                        );
                        return;
                      }

                      final success = await security.authenticate(
                        reason: 'Authenticate to enable App Lock for EmptyPocket',
                      );
                      if (!success) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Authentication cancelled or failed.'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        }
                        return;
                      }
                    }

                    await ref.read(appLockProvider.notifier).toggleAppLock(val);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('App lock ${val ? 'enabled' : 'disabled'}.'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: val ? AppColors.primaryEmerald : null,
                        ),
                      );
                    }
                  },
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bubble_chart_rounded, color: AppColors.primaryEmerald, size: 20),
                  ),
                  title: const Text('24/7 Floating Quick-Add Bubble', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    isBubbleEnabled ? 'Active (Overlay on top of any app)' : 'Disabled (Tap to enable chat head)',
                    style: TextStyle(color: financialColors.textMuted, fontSize: 12),
                  ),
                  value: isBubbleEnabled,
                  onChanged: (val) async {
                    final success = await ref.read(floatingBubbleProvider.notifier).toggleBubble(val);
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please grant "Display over other apps" permission in Android settings.'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section: Data & Backup
          _buildSectionHeader(context, 'Data Backup & Portability'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildListTile(
                  context,
                  icon: Icons.file_download_outlined,
                  iconColor: financialColors.info,
                  title: 'Export Full Backup (JSON)',
                  subtitle: 'Export complete offline database for safe keeping',
                  onTap: () => _showExportJsonDialog(context, ref),
                ),
                const Divider(),
                _buildListTile(
                  context,
                  icon: Icons.file_upload_outlined,
                  iconColor: financialColors.investment,
                  title: 'Restore Database (JSON)',
                  subtitle: 'Restore financial records from a backup JSON string',
                  onTap: () => _showRestoreSheet(context, ref),
                ),
                const Divider(),
                _buildListTile(
                  context,
                  icon: Icons.table_chart_outlined,
                  iconColor: AppColors.primaryEmerald,
                  title: 'Export Transactions (CSV)',
                  subtitle: 'Export spreadsheet-ready log for Excel / Sheets',
                  onTap: () => _showExportCsvDialog(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section: Danger Zone
          _buildSectionHeader(context, 'Danger Zone'),
          const SizedBox(height: 8),
          Card(
            color: AppColors.expense.withAlpha(15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.expense.withAlpha(60)),
            ),
            child: Column(
              children: [
                _buildListTile(
                  context,
                  icon: Icons.delete_forever_rounded,
                  iconColor: AppColors.expense,
                  title: 'Factory Reset / Wipe All Data',
                  subtitle: 'Permanently erase all local financial data',
                  onTap: () => _showFactoryResetDialog(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section: About
          _buildSectionHeader(context, 'About EmptyPocket'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryEmerald.withAlpha(100),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EmptyPocket',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '100% Offline Personal Wealth OS',
                              style: TextStyle(
                                color: financialColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                _buildListTile(
                  context,
                  icon: Icons.info_outline_rounded,
                  iconColor: AppColors.primaryEmerald,
                  title: 'Version',
                  subtitle: 'v1.0.0-release',
                ),
                const Divider(),
                _buildListTile(
                  context,
                  icon: Icons.code_rounded,
                  iconColor: financialColors.investment,
                  title: 'License',
                  subtitle: 'GNU General Public License v3.0 (GPLv3)',
                ),
                const Divider(),
                _buildListTile(
                  context,
                  icon: Icons.favorite_border_rounded,
                  iconColor: financialColors.expense,
                  title: 'Tagline',
                  subtitle: 'Because they don\'t have to stay empty.',
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: context.financialColors.textMuted,
            ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withAlpha(isDark ? 40 : 25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: context.financialColors.textMuted,
        ),
      ),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded, size: 20) : null),
      onTap: onTap,
    );
  }
}
