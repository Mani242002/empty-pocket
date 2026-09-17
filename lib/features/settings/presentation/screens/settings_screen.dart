import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../ai_assistant/presentation/screens/ai_settings_screen.dart';
import '../../../ai_assistant/presentation/state/ai_assistant_provider.dart';
import '../../../../core/presentation/widgets/app_lock_gate.dart';
import '../../../../core/services/file_export_import_service.dart';
import '../../../../core/services/log_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utilities/app_haptics.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';
import '../state/backup_provider.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return 'v${info.version}+${info.buildNumber}';
  } catch (e) {
    LogService.debug('SettingsScreen', 'PackageInfo read error (fallback to default): $e');
    return 'v1.0.0+1';
  }
});

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
              Expanded(
                child: Text(
                  'Full Database Backup',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                constraints: const BoxConstraints(maxHeight: 140),
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
              const SizedBox(height: 12),
              Text(
                'Tip: Saving as a .json file prevents clipboard truncation on large datasets.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actionsOverflowButtonSpacing: 8,
          actions: [
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                OutlinedButton.icon(
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
                OutlinedButton.icon(
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Share File'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await FileExportImportService.shareJsonFile(jsonContent: jsonStr);
                    } catch (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Share failed: $err'), backgroundColor: AppColors.expense),
                        );
                      }
                    }
                  },
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Save / Download .json'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      final path = await FileExportImportService.saveJsonFile(jsonContent: jsonStr);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Backup saved successfully: $path'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.income,
                          ),
                        );
                      }
                    } catch (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('File save error: $err'), backgroundColor: AppColors.expense),
                        );
                      }
                    }
                  },
                ),
              ],
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
              Expanded(
                child: Text(
                  'Transactions CSV Export',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text('Share'),
              onPressed: () async {
                try {
                  await FileExportImportService.shareCsvFile(csvContent: csvStr);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Share failed: $e'), backgroundColor: AppColors.expense),
                    );
                  }
                }
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Save File'),
              onPressed: () async {
                try {
                  final savedPath = await FileExportImportService.saveCsvFile(csvContent: csvStr);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('CSV saved to: $savedPath'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.income,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.expense),
                    );
                  }
                }
              },
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

  void _showImportCsvSheet(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    final financialColors = context.financialColors;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.file_upload_rounded, color: AppColors.primaryEmerald),
                  const SizedBox(width: 8),
                  const Text('Import Transactions (CSV)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Import transactions from EmptyPocket or other finance apps. Select a .csv file or paste raw CSV text.',
                style: TextStyle(color: financialColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.file_open_rounded),
                label: const Text('Pick CSV File from Device'),
                onPressed: () async {
                  try {
                    final result = await FileExportImportService.pickCsvFile();
                    if (result != null && result.content.isNotEmpty) {
                      textController.text = result.content;
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Loaded ${result.fileName} (${result.sizeInBytes} bytes)'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('File pick failed: $e'), backgroundColor: AppColors.expense),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 5,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'Or paste CSV content here...\nID,Date,Type,Category,Title,Amount...',
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
                    icon: const Icon(Icons.download_done_rounded, size: 16),
                    label: const Text('Import Transactions'),
                    onPressed: () async {
                      final text = textController.text.trim();
                      if (text.isEmpty) return;

                      try {
                        final count = await ref.read(backupOperationsProvider.notifier).importTransactionsFromCsv(text);
                        ref.invalidate(transactionListNotifierProvider);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Successfully imported $count transactions!'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.income,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Import error: $e'),
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
      ),
    );
  }

  void _showCurrencySelectorDialog(BuildContext context, WidgetRef ref) {
    final currentCurrency = ref.read(currencyProvider).valueOrNull ?? CurrencyFormatter.activeCurrency;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.currency_exchange_rounded, color: AppColors.primaryEmerald),
            SizedBox(width: 8),
            Text('Select Currency'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: CurrencyFormatter.supportedCurrencies.length,
            itemBuilder: (context, index) {
              final option = CurrencyFormatter.supportedCurrencies[index];
              final isSelected = option.code == currentCurrency.code;
              return ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryEmerald
                        : AppColors.primaryEmerald.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    option.symbol.trim(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? Colors.white : AppColors.primaryEmerald,
                    ),
                  ),
                ),
                title: Text('${option.code} — ${option.name}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  option.isIndianNumbering ? 'Indian Numbering (Lakhs, Crores)' : 'Standard Numbering (Thousands, Millions)',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryEmerald) : null,
                onTap: () async {
                  AppHaptics.selectionClick();
                  await ref.read(currencyProvider.notifier).setCurrency(option);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Currency updated to ${option.code} (${option.symbol})'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showReconcileBalancesDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sync_rounded, color: AppColors.primaryEmerald),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Reconcile Account Balances',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This tool audits all your transactions from the ledger and recalculates every bank account balance and credit card used balance according to the exact transaction history.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              '✓ Fixes historical balance drift.\n✓ Corrects transfer balance mismatches.\n✓ Does not alter or delete any transactions.',
              style: TextStyle(fontSize: 12, height: 1.5, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Reconcile Now'),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(accountOperationsProvider).reconcileAllBalancesWithLedger();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All bank and card balances successfully reconciled with ledger!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.income,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reconciliation error: $e'),
                      backgroundColor: AppColors.expense,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showRestoreSheet(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String? loadedFileName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
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
                  'Upload a .json backup file or paste JSON data. Restoring will replace existing local data.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.file_open_rounded, size: 18),
                  label: Text(loadedFileName != null
                      ? 'Selected: $loadedFileName'
                      : 'Upload / Pick .json File'),
                  onPressed: () async {
                    try {
                      final picked = await FileExportImportService.pickJsonFile();
                      if (picked != null) {
                        setSheetState(() {
                          loadedFileName = '${picked.fileName} (${(picked.sizeInBytes / 1024).toStringAsFixed(1)} KB)';
                          textController.text = picked.content;
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Loaded "${picked.fileName}" ready for restore!'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.primaryEmerald,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('File pick failed: $e'), backgroundColor: AppColors.expense),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  maxLines: 5,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  decoration: InputDecoration(
                    hintText: 'Or paste backup JSON string here...',
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
                    Flexible(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Restore Database'),
                        ),
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
                    ),
                  ],
                ),
              ],
            ),
          ),
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
            Expanded(
              child: Text(
                'Factory Reset All Data',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
        actionsOverflowButtonSpacing: 8,
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
    final isDark = theme.brightness == Brightness.dark;
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentCurrency = ref.watch(currencyProvider).valueOrNull ?? CurrencyFormatter.activeCurrency;
    final isAppLockEnabled = ref.watch(appLockProvider).valueOrNull ?? false;
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
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      ),
                    ),
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'System',
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                        icon: Icon(Icons.brightness_auto_rounded, size: 18),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Light',
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                        icon: Icon(Icons.light_mode_rounded, size: 18),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Dark',
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
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

          // Section: Preferences & Currency
          _buildSectionHeader(context, 'Preferences & Region'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildListTile(
                  context,
                  icon: Icons.currency_exchange_rounded,
                  iconColor: AppColors.primaryEmerald,
                  title: 'Currency',
                  subtitle: '${currentCurrency.code} (${currentCurrency.symbol}) — ${currentCurrency.name}',
                  onTap: () => _showCurrencySelectorDialog(context, ref),
                ),
              ],
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
                  title: const Text('Floating Quick Add', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    isBubbleEnabled ? 'Active 24/7 on top of other apps' : 'Tap to enable 24/7 quick add bubble',
                    style: TextStyle(color: financialColors.textMuted, fontSize: 12),
                  ),
                  value: isBubbleEnabled,
                  onChanged: (val) async {
                    AppHaptics.selectionClick();
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

          // Section: Notifications & Reminders
          _buildSectionHeader(context, 'Notifications & Reminders'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  activeTrackColor: AppColors.primaryEmerald,
                  secondary: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha(isDark ? 45 : 25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_fire_department_rounded, color: AppColors.warning, size: 20),
                  ),
                  title: const Text('Daily Streak Reminder', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    'Prompt at 8:00 PM to log daily expenses & maintain tracking streak',
                    style: TextStyle(color: financialColors.textMuted, fontSize: 12),
                  ),
                  value: ref.watch(dailyStreakReminderNotifierProvider),
                  onChanged: (val) async {
                    AppHaptics.selectionClick();
                    if (val) {
                      await ref.read(notificationServiceProvider).requestPermission();
                    }
                    await ref.read(dailyStreakReminderNotifierProvider.notifier).setEnabled(val);
                  },
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  activeTrackColor: AppColors.primaryEmerald,
                  secondary: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withAlpha(isDark ? 45 : 25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_repeat_rounded, color: AppColors.primaryTeal, size: 20),
                  ),
                  title: const Text('Recurring Bill Due Alerts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    'Morning alert when recurring bills, subscriptions, and EMIs are due',
                    style: TextStyle(color: financialColors.textMuted, fontSize: 12),
                  ),
                  value: ref.watch(billDueAlertNotifierProvider),
                  onChanged: (val) async {
                    AppHaptics.selectionClick();
                    if (val) {
                      await ref.read(notificationServiceProvider).requestPermission();
                    }
                    await ref.read(billDueAlertNotifierProvider.notifier).setEnabled(val);
                  },
                ),
                const Divider(),
                _buildListTile(
                  context,
                  icon: Icons.notifications_active_outlined,
                  iconColor: financialColors.income,
                  title: 'Send Test Notification',
                  subtitle: 'Verify notification display on this device',
                  onTap: () async {
                    AppHaptics.buttonPress();
                    await ref.read(notificationServiceProvider).requestPermission();
                    await ref.read(notificationServiceProvider).sendTestNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test notification sent to system tray.'),
                          behavior: SnackBarBehavior.floating,
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
                  icon: Icons.file_download_rounded,
                  iconColor: financialColors.info,
                  title: 'Export Full Backup (JSON)',
                  subtitle: 'Export complete offline database for safe keeping',
                  onTap: () => _showExportJsonDialog(context, ref),
                ),
                const Divider(),
                _buildListTile(
                  context,
                  icon: Icons.file_upload_rounded,
                  iconColor: financialColors.investment,
                  title: 'Restore Database (JSON)',
                  subtitle: 'Restore financial records from a backup JSON string',
                  onTap: () => _showRestoreSheet(context, ref),
                ),
                const Divider(),
                _buildListTile(
                  context,
                  icon: Icons.table_chart_rounded,
                  iconColor: AppColors.primaryEmerald,
                  title: 'Export Transactions (CSV)',
                  subtitle: 'Export spreadsheet-ready log for Excel / Sheets',
                  onTap: () => _showExportCsvDialog(context, ref),
                ),
                const Divider(),
                _buildListTile(
                  context,
                  icon: Icons.file_open_rounded,
                  iconColor: financialColors.warning,
                  title: 'Import Transactions (CSV)',
                  subtitle: 'Ingest transactions from CSV file or spreadsheet export',
                  onTap: () => _showImportCsvSheet(context, ref),
                ),
                const Divider(),
                _buildListTile(
                  context,
                  icon: Icons.sync_rounded,
                  iconColor: financialColors.income,
                  title: 'Reconcile Account Balances',
                  subtitle: 'Audit & align bank & card balances with transaction ledger',
                  onTap: () => _showReconcileBalancesDialog(context, ref),
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
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 28,
                              color: AppColors.primaryEmerald,
                            ),
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
                  subtitle: ref.watch(appVersionProvider).valueOrNull ?? 'v1.0.0+1',
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
