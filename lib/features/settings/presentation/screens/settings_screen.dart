import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final currentThemeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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

          // Section: Privacy & Security
          _buildSectionHeader(context, 'Privacy & Security'),
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
                  subtitle: 'Zero background traffic / No tracking',
                  trailing: const Icon(Icons.check_circle_rounded, color: AppColors.income, size: 20),
                ),
                const Divider(),
                _buildListTile(
                  context,
                  icon: Icons.lock_outline_rounded,
                  iconColor: financialColors.investment,
                  title: 'App Lock (Biometric / PIN)',
                  subtitle: 'Disabled',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('App lock will be configured in upcoming security update.'),
                      ),
                    );
                  },
                ),
                const Divider(),
                _buildListTile(
                  context,
                  icon: Icons.psychology_outlined,
                  iconColor: financialColors.savings,
                  title: 'BYOK AI Insights',
                  subtitle: 'Optional Bring-Your-Own-Key model',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('BYOK AI is planned for Milestone 8.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section: Data Management
          _buildSectionHeader(context, 'Data Management'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildListTile(
                  context,
                  icon: Icons.file_upload_outlined,
                  iconColor: financialColors.info,
                  title: 'Export Encrypted Backup',
                  subtitle: 'Save a password-protected backup file',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Encrypted export will be added in Milestone 7.'),
                      ),
                    );
                  },
                ),
                const Divider(),
                _buildListTile(
                  context,
                  icon: Icons.file_download_outlined,
                  iconColor: financialColors.warning,
                  title: 'Import Backup',
                  subtitle: 'Restore financial records from backup',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Backup restore will be added in Milestone 7.'),
                      ),
                    );
                  },
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
                _buildListTile(
                  context,
                  icon: Icons.info_outline_rounded,
                  iconColor: AppColors.primaryEmerald,
                  title: 'Version',
                  subtitle: 'v0.1.0-alpha',
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
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right_rounded, size: 20)
              : null),
      onTap: onTap,
    );
  }
}
