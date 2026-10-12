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
import '../../../../core/services/battery_optimization_service.dart';
import '../../../../core/services/file_export_import_service.dart';
import '../../../../core/services/log_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utilities/app_haptics.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
import '../../../budgets/presentation/state/budgets_provider.dart';
import '../../../budgets/presentation/state/recurring_provider.dart';
import '../../../savings/presentation/state/savings_goals_provider.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';
import '../../../../core/services/backup_service.dart';
import '../state/backup_provider.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return 'v${info.version}+${info.buildNumber}';
  } catch (e) {
    LogService.debug(
      'SettingsScreen',
      'PackageInfo read error (fallback to default): $e',
    );
    return 'v1.0.0+1';
  }
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<bool> _requestNotificationPermission(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final service = ref.read(notificationServiceProvider);
    if (await service.hasNotificationPermission()) return true;
    if (!context.mounted) return false;
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stay on top of your money'),
        content: const Text(
          'EmptyPocket can send gentle expense check-ins, upcoming bill reminders, and optional budget alerts. You can change or pause each type at any time in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (shouldRequest != true || !context.mounted) return false;
    final granted = await service.requestPermission();
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Notifications are still off. You can enable them in device settings.',
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Settings',
            onPressed: service.openNotificationSettings,
          ),
        ),
      );
    }
    return granted;
  }

  Future<void> _pickQuietHour(
    BuildContext context,
    WidgetRef ref,
    RoutineReminderSettings settings, {
    required bool pickStart,
  }) async {
    final currentMinute = pickStart
        ? settings.quietHoursStartMinute
        : settings.quietHoursEndMinute;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinute ~/ 60,
        minute: currentMinute % 60,
      ),
    );
    if (picked == null || !context.mounted) return;
    final newMinute = picked.hour * 60 + picked.minute;
    final otherMinute = pickStart
        ? settings.quietHoursEndMinute
        : settings.quietHoursStartMinute;
    if (newMinute == otherMinute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose different start and end times.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await ref
        .read(routineReminderSettingsProvider.notifier)
        .setQuietHours(
          startMinute: pickStart ? newMinute : settings.quietHoursStartMinute,
          endMinute: pickStart ? settings.quietHoursEndMinute : newMinute,
        );
  }

  Future<void> _enableNotifications(BuildContext context, WidgetRef ref) async {
    if (!await _requestNotificationPermission(context, ref) ||
        !context.mounted) {
      return;
    }
    final service = ref.read(notificationServiceProvider);
    final transactions = ref
        .read(transactionListNotifierProvider)
        .asData
        ?.value;
    if (ref.read(dailyStreakReminderNotifierProvider)) {
      await service.scheduleDailyLogReminders();
      if (transactions != null) {
        await service.scheduleDailySummaries(transactions);
      }
    }
    if (ref.read(billDueAlertNotifierProvider)) {
      final recurring = ref.read(recurringListNotifierProvider).asData?.value;
      if (recurring != null) {
        await service.scheduleRecurringPaymentReminders(recurring);
      }
    }
    if (ref.read(monthlyMoneyCheckInNotifierProvider)) {
      final budgets = ref.read(budgetListNotifierProvider).asData?.value;
      final goals = ref.read(savingsGoalsListNotifierProvider).asData?.value;
      if (budgets != null && goals != null) {
        await service.scheduleMonthlyMoneyCheckIns(
          budgets: budgets,
          goals: goals,
        );
      }
    }
    if (ref.read(budgetAlertSettingsProvider).enabled) {
      final budgets = ref.read(budgetListNotifierProvider).asData?.value;
      if (budgets != null && transactions != null) {
        await service.updateBudgetThresholdAlerts(
          budgets: budgets,
          transactions: transactions,
        );
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('EmptyPocket notifications are enabled.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showExportJsonDialog(BuildContext context, WidgetRef ref) async {
    try {
      final jsonStr = await ref
          .read(backupOperationsProvider.notifier)
          .exportFullJsonBackup();
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.file_download_outlined,
                color: AppColors.primaryEmerald,
              ),
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
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tip: Saving as a .json file prevents clipboard truncation on large datasets.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
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
                      await FileExportImportService.shareJsonFile(
                        jsonContent: jsonStr,
                      );
                    } catch (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Share failed: $err'),
                            backgroundColor: AppColors.expense,
                          ),
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
                      final path = await FileExportImportService.saveJsonFile(
                        jsonContent: jsonStr,
                      );
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
                          SnackBar(
                            content: Text('File save error: $err'),
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
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  void _showExportCsvDialog(BuildContext context, WidgetRef ref) async {
    try {
      final csvStr = await ref
          .read(backupOperationsProvider.notifier)
          .exportTransactionsCsv();
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
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
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
                  await FileExportImportService.shareCsvFile(
                    csvContent: csvStr,
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Share failed: $e'),
                        backgroundColor: AppColors.expense,
                      ),
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
                  final savedPath = await FileExportImportService.saveCsvFile(
                    csvContent: csvStr,
                  );
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
                      SnackBar(
                        content: Text('Save failed: $e'),
                        backgroundColor: AppColors.expense,
                      ),
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
          SnackBar(
            content: Text('CSV export failed: $e'),
            backgroundColor: AppColors.expense,
          ),
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
                  const Icon(
                    Icons.file_upload_rounded,
                    color: AppColors.primaryEmerald,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Import Transactions (CSV)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
                style: TextStyle(
                  color: financialColors.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                            content: Text(
                              'Loaded ${result.fileName} (${result.sizeInBytes} bytes)',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('File pick failed: $e'),
                          backgroundColor: AppColors.expense,
                        ),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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

                      Future<void> executeImport([
                        NumberFormatMode mode = NumberFormatMode.auto,
                      ]) async {
                        try {
                          final summary = await ref
                              .read(backupOperationsProvider.notifier)
                              .importTransactionsFromCsv(
                                text,
                                formatMode: mode,
                              );
                          ref.invalidate(transactionListNotifierProvider);
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            final details = <String>[];
                            if (summary.defaultedDates > 0) {
                              details.add(
                                '${summary.defaultedDates} dates defaulted to today',
                              );
                            }
                            if (summary.invalidRows > 0) {
                              details.add(
                                '${summary.invalidRows} invalid rows skipped',
                              );
                            }
                            final msg = details.isNotEmpty
                                ? 'Imported ${summary.totalImported} transactions (${details.join(', ')}).'
                                : 'Successfully imported ${summary.totalImported} transactions!';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.income,
                              ),
                            );
                          }
                        } on CsvAmbiguousNumberException catch (ambEx) {
                          if (!context.mounted) return;
                          final selectedMode = await showDialog<NumberFormatMode>(
                            context: context,
                            barrierDismissible: false,
                            builder: (dialogCtx) => AlertDialog(
                              title: const Text('Confirm Number Format'),
                              content: Text(
                                'Found ${ambEx.ambiguousCount} amount(s) with ambiguous separators (e.g. "1.234" or "1,234").\n\n'
                                'Please choose the format used in this CSV file to ensure correct numbers:',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: const Text('Cancel Import'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(
                                    dialogCtx,
                                    NumberFormatMode.western,
                                  ),
                                  child: const Text(
                                    'Western (1,234 is Thousands)',
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(
                                    dialogCtx,
                                    NumberFormatMode.european,
                                  ),
                                  child: const Text(
                                    'European (1.234 is Thousands)',
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(
                                    dialogCtx,
                                    NumberFormatMode.indian,
                                  ),
                                  child: const Text('Indian (Lakhs/Crores)'),
                                ),
                              ],
                            ),
                          );
                          if (selectedMode != null) {
                            await executeImport(selectedMode);
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
                      }

                      await executeImport();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => textController.dispose());
  }

  void _showCurrencySelectorDialog(BuildContext context, WidgetRef ref) {
    final currentCurrency =
        ref.read(currencyProvider).valueOrNull ??
        CurrencyFormatter.activeCurrency;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.currency_exchange_rounded,
                  color: AppColors.primaryEmerald,
                ),
                SizedBox(width: 8),
                Text('Select Currency'),
              ],
            ),
            SizedBox(height: 6),
            Text(
              'Changes display symbol & number grouping. Does not convert existing numeric amounts.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
                color: Colors.grey,
              ),
            ),
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
                      color: isSelected
                          ? Colors.white
                          : AppColors.primaryEmerald,
                    ),
                  ),
                ),
                title: Text(
                  '${option.code} — ${option.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  option.isIndianNumbering
                      ? 'Indian Numbering (Lakhs, Crores)'
                      : 'Standard Numbering (Thousands, Millions)',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primaryEmerald,
                      )
                    : null,
                onTap: () async {
                  AppHaptics.selectionClick();
                  try {
                    await ref
                        .read(currencyProvider.notifier)
                        .setCurrency(option);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Currency updated to ${option.code} (${option.symbol})',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update currency: $e'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.expense,
                        ),
                      );
                    }
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
                await ref
                    .read(accountOperationsProvider)
                    .reconcileAllBalancesWithLedger();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'All bank and card balances successfully reconciled with ledger!',
                      ),
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
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.file_open_rounded, size: 18),
                  label: Text(
                    loadedFileName != null
                        ? 'Selected: $loadedFileName'
                        : 'Upload / Pick .json File',
                  ),
                  onPressed: () async {
                    try {
                      final picked =
                          await FileExportImportService.pickJsonFile();
                      if (picked != null) {
                        setSheetState(() {
                          loadedFileName =
                              '${picked.fileName} (${(picked.sizeInBytes / 1024).toStringAsFixed(1)} KB)';
                          textController.text = picked.content;
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Loaded "${picked.fileName}" ready for restore!',
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.primaryEmerald,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('File pick failed: $e'),
                            backgroundColor: AppColors.expense,
                          ),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                            await ref
                                .read(backupOperationsProvider.notifier)
                                .restoreFromJson(text);
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Database restored successfully!',
                                  ),
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
    ).whenComplete(() => textController.dispose());
  }

  void _showFactoryResetDialog(BuildContext context, WidgetRef ref) {
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
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
              'This will PERMANENTLY ERASE all local financial records, accounts, cards, AI chat and reports, app settings, and stored AI credentials from this device.',
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
                try {
                  await ref
                      .read(backupOperationsProvider.notifier)
                      .wipeAllData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'All local data, settings, and stored credentials were cleared.',
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.primaryEmerald,
                      ),
                    );
                  }
                } catch (error, stackTrace) {
                  LogService.error(
                    'SettingsScreen',
                    'Factory reset failed',
                    error,
                    stackTrace,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Factory reset did not finish. Some local data may already be cleared; retry the reset.',
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.expense,
                      ),
                    );
                  }
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
    ).whenComplete(() => confirmController.dispose());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentCurrency =
        ref.watch(currencyProvider).valueOrNull ??
        CurrencyFormatter.activeCurrency;
    final isAppLockEnabled = ref.watch(appLockProvider).valueOrNull ?? false;
    final isBubbleEnabled = ref.watch(floatingBubbleProvider);
    final aiConfig = ref.watch(aiProviderConfigProvider);
    final routineSettings = ref.watch(routineReminderSettingsProvider);
    final hideNotificationAmounts = ref.watch(hideNotificationAmountsProvider);
    final budgetAlertSettings = ref.watch(budgetAlertSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Privacy')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
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
                              icon: Icon(
                                Icons.brightness_auto_rounded,
                                size: 18,
                              ),
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
                            ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(newSelection.first);
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
                        isThreeLine: true,
                        subtitle:
                            '${currentCurrency.code} (${currentCurrency.symbol}) — ${currentCurrency.name}',
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
                        isThreeLine: true,
                        subtitle: aiConfig.isConfigured
                            ? 'Active: ${aiConfig.providerType.displayName} (${aiConfig.activeModelDisplayName})'
                            : 'Configure Gemini & Groq keys on device',
                        trailing: Icon(
                          aiConfig.isConfigured
                              ? Icons.check_circle_rounded
                              : Icons.info_outline_rounded,
                          color: aiConfig.isConfigured
                              ? AppColors.income
                              : AppColors.warning,
                          size: 20,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AiSettingsScreen(),
                            ),
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
                        isThreeLine: true,
                        subtitle: 'On-Device SQLite Storage',
                        trailing: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.income,
                          size: 20,
                        ),
                      ),
                      const Divider(),
                      _buildListTile(
                        context,
                        icon: Icons.wifi_off_rounded,
                        iconColor: financialColors.info,
                        title: 'Network Activity',
                        isThreeLine: true,
                        subtitle: 'Zero analytics / Zero background telemetry',
                        trailing: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.income,
                          size: 20,
                        ),
                      ),
                      const Divider(),
                      SwitchListTile.adaptive(
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: financialColors.investment.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            color: financialColors.investment,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'App Lock (Biometric / PIN)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          isAppLockEnabled
                              ? 'Enabled (Requires authentication on open)'
                              : 'Disabled',
                          style: TextStyle(
                            color: financialColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        value: isAppLockEnabled,
                        onChanged: (val) async {
                          if (val) {
                            final security = ref.read(securityServiceProvider);
                            final isAvailable = await security
                                .isBiometricsAvailable();
                            if (!isAvailable && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No screen lock or biometric credentials configured on this device.',
                                  ),
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
                                    content: Text(
                                      'Authentication cancelled or failed.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: AppColors.warning,
                                  ),
                                );
                              }
                              return;
                            }
                          }

                          try {
                            await ref
                                .read(appLockProvider.notifier)
                                .toggleAppLock(val);
                          } catch (error, stackTrace) {
                            LogService.error(
                              'SettingsScreen',
                              'Could not persist app lock setting',
                              error,
                              stackTrace,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not save the app lock setting. Retry before continuing.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.expense,
                                ),
                              );
                            }
                            return;
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'App lock ${val ? 'enabled' : 'disabled'}.',
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: val
                                    ? AppColors.primaryEmerald
                                    : null,
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
                          child: const Icon(
                            Icons.bubble_chart_rounded,
                            color: AppColors.primaryEmerald,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'Floating Quick Add',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          isBubbleEnabled
                              ? 'Active 24/7 on top of other apps'
                              : 'Tap to enable 24/7 quick add bubble',
                          style: TextStyle(
                            color: financialColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        value: isBubbleEnabled,
                        onChanged: (val) async {
                          AppHaptics.selectionClick();
                          final success = await ref
                              .read(floatingBubbleProvider.notifier)
                              .toggleBubble(val);
                          if (!success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please grant "Display over other apps" permission in Android settings.',
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.warning,
                              ),
                            );
                          }
                        },
                      ),
                      if (isBubbleEnabled) ...[
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primaryEmerald.withAlpha(
                                isDark ? 45 : 25,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.battery_charging_full_rounded,
                              color: AppColors.primaryEmerald,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Background Battery Exemption',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Prevent Android from killing the 24/7 bubble',
                            style: TextStyle(
                              color: financialColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            AppHaptics.selectionClick();
                            await BatteryOptimizationService.openBatterySettings();
                          },
                        ),
                      ],
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
                      ListTile(
                        isThreeLine: true,
                        leading: const Icon(
                          Icons.notifications_active_outlined,
                        ),
                        title: const Text(
                          'Enable notifications on this device',
                        ),
                        subtitle: const Text(
                          'Choose which reminders you want below, then allow EmptyPocket to show them here.',
                        ),
                        trailing: OutlinedButton(
                          onPressed: () => _enableNotifications(context, ref),
                          child: const Text('Enable'),
                        ),
                      ),
                      const Divider(),
                      SwitchListTile.adaptive(
                        isThreeLine: true,
                        activeTrackColor: AppColors.primaryEmerald,
                        secondary: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.warning.withAlpha(
                              isDark ? 45 : 25,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            color: AppColors.warning,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'Daily Expense Check-ins',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Morning, afternoon & evening prompts, plus a 10:00 PM income and expense summary',
                          style: TextStyle(
                            color: financialColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        value: ref.watch(dailyStreakReminderNotifierProvider),
                        onChanged: (val) async {
                          AppHaptics.selectionClick();
                          if (val) {
                            if (!await _requestNotificationPermission(
                              context,
                              ref,
                            )) {
                              return;
                            }
                          }
                          await ref
                              .read(
                                dailyStreakReminderNotifierProvider.notifier,
                              )
                              .setEnabled(val);
                        },
                      ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.notifications_none_rounded,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Routine reminder frequency',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 32),
                              child: Text(
                                'Choose three check-ins a day or just the morning reminder',
                                style: TextStyle(
                                  color: financialColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.only(left: 32),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ChoiceChip(
                                    selected:
                                        routineSettings.remindersPerDay == 3,
                                    onSelected: (selected) {
                                      if (selected) {
                                        AppHaptics.selectionClick();
                                        ref
                                            .read(
                                              routineReminderSettingsProvider
                                                  .notifier,
                                            )
                                            .setRemindersPerDay(3);
                                      }
                                    },
                                    avatar: const Icon(
                                      Icons.repeat_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('3 / day (All prompts)'),
                                  ),
                                  ChoiceChip(
                                    selected:
                                        routineSettings.remindersPerDay == 1,
                                    onSelected: (selected) {
                                      if (selected) {
                                        AppHaptics.selectionClick();
                                        ref
                                            .read(
                                              routineReminderSettingsProvider
                                                  .notifier,
                                            )
                                            .setRemindersPerDay(1);
                                      }
                                    },
                                    avatar: const Icon(
                                      Icons.wb_sunny_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('1 / day (Morning only)'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SwitchListTile.adaptive(
                        isThreeLine: true,
                        activeTrackColor: AppColors.primaryEmerald,
                        secondary: const Icon(Icons.bedtime_outlined),
                        title: const Text('Quiet hours'),
                        subtitle: const Text(
                          'Pause routine check-ins and the nightly summary during this window. Bill alerts stay controlled separately.',
                        ),
                        value: routineSettings.quietHoursEnabled,
                        onChanged: (enabled) {
                          AppHaptics.selectionClick();
                          ref
                              .read(routineReminderSettingsProvider.notifier)
                              .setQuietHoursEnabled(enabled);
                        },
                      ),
                      if (routineSettings.quietHoursEnabled) ...[
                        ListTile(
                          dense: true,
                          title: const Text('Quiet hours start'),
                          trailing: TextButton(
                            onPressed: () => _pickQuietHour(
                              context,
                              ref,
                              routineSettings,
                              pickStart: true,
                            ),
                            child: Text(
                              TimeOfDay(
                                hour:
                                    routineSettings.quietHoursStartMinute ~/ 60,
                                minute:
                                    routineSettings.quietHoursStartMinute % 60,
                              ).format(context),
                            ),
                          ),
                        ),
                        ListTile(
                          dense: true,
                          title: const Text('Quiet hours end'),
                          trailing: TextButton(
                            onPressed: () => _pickQuietHour(
                              context,
                              ref,
                              routineSettings,
                              pickStart: false,
                            ),
                            child: Text(
                              TimeOfDay(
                                hour: routineSettings.quietHoursEndMinute ~/ 60,
                                minute:
                                    routineSettings.quietHoursEndMinute % 60,
                              ).format(context),
                            ),
                          ),
                        ),
                      ],
                      const Divider(),
                      SwitchListTile.adaptive(
                        isThreeLine: true,
                        activeTrackColor: AppColors.primaryEmerald,
                        secondary: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal.withAlpha(
                              isDark ? 45 : 25,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.event_repeat_rounded,
                            color: AppColors.primaryTeal,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'Recurring Bill Due Alerts',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Reminders two days before, on the due date, and the next day if still unlogged',
                          style: TextStyle(
                            color: financialColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        value: ref.watch(billDueAlertNotifierProvider),
                        onChanged: (val) async {
                          AppHaptics.selectionClick();
                          if (val) {
                            if (!await _requestNotificationPermission(
                              context,
                              ref,
                            )) {
                              return;
                            }
                          }
                          await ref
                              .read(billDueAlertNotifierProvider.notifier)
                              .setEnabled(val);
                          if (val) {
                            final recurring = ref
                                .read(recurringListNotifierProvider)
                                .asData
                                ?.value;
                            if (recurring != null) {
                              await ref
                                  .read(notificationServiceProvider)
                                  .scheduleRecurringPaymentReminders(recurring);
                            }
                          }
                        },
                      ),
                      const Divider(),
                      SwitchListTile.adaptive(
                        isThreeLine: true,
                        activeTrackColor: AppColors.primaryEmerald,
                        secondary: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryEmerald.withAlpha(
                              isDark ? 45 : 25,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.savings_outlined,
                            color: AppColors.primaryEmerald,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'Monthly Budget & Savings Check-in',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'A gentle start-of-month plan and month-end review for your budgets and active goals',
                          style: TextStyle(
                            color: financialColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        value: ref.watch(monthlyMoneyCheckInNotifierProvider),
                        onChanged: (val) async {
                          AppHaptics.selectionClick();
                          if (val) {
                            if (!await _requestNotificationPermission(
                              context,
                              ref,
                            )) {
                              return;
                            }
                          }
                          await ref
                              .read(
                                monthlyMoneyCheckInNotifierProvider.notifier,
                              )
                              .setEnabled(val);
                          if (val) {
                            final budgets = ref
                                .read(budgetListNotifierProvider)
                                .asData
                                ?.value;
                            final goals = ref
                                .read(savingsGoalsListNotifierProvider)
                                .asData
                                ?.value;
                            if (budgets != null && goals != null) {
                              await ref
                                  .read(notificationServiceProvider)
                                  .scheduleMonthlyMoneyCheckIns(
                                    budgets: budgets,
                                    goals: goals,
                                  );
                            }
                          }
                        },
                      ),
                      const Divider(),
                      SwitchListTile.adaptive(
                        isThreeLine: true,
                        activeTrackColor: AppColors.primaryEmerald,
                        secondary: const Icon(Icons.pie_chart_outline_rounded),
                        title: const Text('Budget threshold alerts'),
                        subtitle: const Text(
                          'Optional alerts as a monthly category budget approaches its limit and when it is reached',
                        ),
                        value: budgetAlertSettings.enabled,
                        onChanged: (enabled) async {
                          AppHaptics.selectionClick();
                          if (enabled &&
                              !await _requestNotificationPermission(
                                context,
                                ref,
                              )) {
                            return;
                          }
                          await ref
                              .read(budgetAlertSettingsProvider.notifier)
                              .setEnabled(enabled);
                        },
                      ),
                      if (budgetAlertSettings.enabled)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.tune_rounded, size: 20),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Early warning threshold',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 32),
                                child: Text(
                                  'A second alert is sent when spending reaches 100% of budget',
                                  style: TextStyle(
                                    color: financialColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.only(left: 32),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final threshold in const [70, 80, 90])
                                      ChoiceChip(
                                        selected:
                                            budgetAlertSettings
                                                .approachThreshold ==
                                            threshold,
                                        onSelected: (selected) {
                                          if (selected) {
                                            AppHaptics.selectionClick();
                                            ref
                                                .read(
                                                  budgetAlertSettingsProvider
                                                      .notifier,
                                                )
                                                .setApproachThreshold(
                                                  threshold,
                                                );
                                          }
                                        },
                                        label: Text('$threshold% limit'),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Divider(),
                      SwitchListTile.adaptive(
                        isThreeLine: true,
                        activeTrackColor: AppColors.primaryEmerald,
                        secondary: const Icon(Icons.visibility_off_outlined),
                        title: const Text('Hide amounts in notifications'),
                        subtitle: const Text(
                          'Keep expense totals and payment amounts out of notification previews',
                        ),
                        value: hideNotificationAmounts,
                        onChanged: (enabled) => ref
                            .read(hideNotificationAmountsProvider.notifier)
                            .setEnabled(enabled),
                      ),
                      const Divider(),
                      _buildListTile(
                        context,
                        icon: Icons.notifications_active_outlined,
                        iconColor: financialColors.income,
                        title: 'Send Instant Test Notification',
                        isThreeLine: true,
                        subtitle: 'Verify notification display on this device immediately',
                        onTap: () async {
                          AppHaptics.buttonPress();
                          if (!await _requestNotificationPermission(
                            context,
                            ref,
                          )) {
                            return;
                          }
                          await ref
                              .read(notificationServiceProvider)
                              .sendTestNotification();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Test notification sent to system tray.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                      const Divider(),
                      _buildListTile(
                        context,
                        icon: Icons.alarm_on_rounded,
                        iconColor: AppColors.primaryTeal,
                        title: 'Test Offline Alarm (Fires in 10s)',
                        isThreeLine: true,
                        subtitle: 'Schedule background alarm; close or lock phone to test delivery',
                        onTap: () async {
                          AppHaptics.buttonPress();
                          if (!await _requestNotificationPermission(
                            context,
                            ref,
                          )) {
                            return;
                          }
                          final ok = await ref
                              .read(notificationServiceProvider)
                              .scheduleTestDelayedNotification(seconds: 10);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Alarm scheduled! Lock or background app to verify in 10 seconds.'
                                      : 'Failed to schedule alarm. Check device permissions.',
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 4),
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
                        isThreeLine: true,
                        subtitle:
                            'Export complete offline database for safe keeping',
                        onTap: () => _showExportJsonDialog(context, ref),
                      ),
                      const Divider(),
                      _buildListTile(
                        context,
                        icon: Icons.file_upload_rounded,
                        iconColor: financialColors.investment,
                        title: 'Restore Database (JSON)',
                        isThreeLine: true,
                        subtitle: 'Restore financial records from a backup JSON string',
                        onTap: () => _showRestoreSheet(context, ref),
                      ),
                      const Divider(),
                      _buildListTile(
                        context,
                        icon: Icons.table_chart_rounded,
                        iconColor: AppColors.primaryEmerald,
                        title: 'Export Transactions (CSV)',
                        isThreeLine: true,
                        subtitle:
                            'Export spreadsheet-ready log for Excel / Sheets',
                        onTap: () => _showExportCsvDialog(context, ref),
                      ),
                      const Divider(),
                      _buildListTile(
                        context,
                        icon: Icons.file_open_rounded,
                        iconColor: financialColors.warning,
                        title: 'Import Transactions (CSV)',
                        isThreeLine: true,
                        subtitle: 'Ingest transactions from CSV file or spreadsheet export',
                        onTap: () => _showImportCsvSheet(context, ref),
                      ),
                      const Divider(),
                      _buildListTile(
                        context,
                        icon: Icons.sync_rounded,
                        iconColor: financialColors.income,
                        title: 'Reconcile Account Balances',
                        isThreeLine: true,
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
                        isThreeLine: true,
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
                                  color: AppColors.primaryEmerald.withAlpha(
                                    100,
                                  ),
                                  width: 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  'assets/icon/app_icon.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
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
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
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
                        subtitle:
                            ref.watch(appVersionProvider).valueOrNull ??
                            'v1.0.0+1',
                      ),
                      const Divider(),
                      _buildListTile(
                        context,
                        icon: Icons.code_rounded,
                        iconColor: financialColors.investment,
                        title: 'License',
                        isThreeLine: true,
                        subtitle: 'GNU General Public License v3.0 (GPLv3)',
                      ),
                      const Divider(),
                      _buildListTile(
                        context,
                        icon: Icons.favorite_border_rounded,
                        iconColor: financialColors.expense,
                        title: 'Tagline',
                        isThreeLine: true,
                        subtitle: 'Because they don\'t have to stay empty.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
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
    bool? isThreeLine,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveThreeLine = isThreeLine ?? (subtitle.length > 32);

    return Semantics(
      label: '$title: $subtitle',
      child: ListTile(
        isThreeLine: effectiveThreeLine,
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: effectiveThreeLine ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.financialColors.textMuted,
          ),
        ),
        trailing:
            trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right_rounded, size: 20)
                : null),
        onTap: onTap,
      ),
    );
  }
}
