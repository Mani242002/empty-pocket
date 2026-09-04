import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/utilities/app_haptics.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
import '../screens/add_edit_transaction_sheet.dart';
import '../screens/transaction_detail_sheet.dart';
import '../state/transactions_provider.dart';
import '../widgets/transaction_list_item.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Expenses, 2: Income
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = ['All', 'Expenses', 'Income'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) {
      return 'Today';
    } else if (checkDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEE, d MMMM yyyy').format(date);
    }
  }

  void _duplicateTransaction(TransactionEntity tx) async {
    final now = DateTime.now();
    final cloned = tx.copyWith(
      id: const Uuid().v4(),
      date: now,
      createdAt: now,
      updatedAt: now,
    );

    // Apply balance impact for cloned transaction
    if (cloned.type == TransactionType.income) {
      if (cloned.accountId != null) {
        await ref
            .read(bankAccountListProvider.notifier)
            .adjustAccountBalance(cloned.accountId!, cloned.amount);
      } else if (cloned.creditCardId != null) {
        await ref
            .read(creditCardListProvider.notifier)
            .adjustUsedAmount(cloned.creditCardId!, -cloned.amount);
      }
    } else if (cloned.type == TransactionType.expense) {
      if (cloned.creditCardId != null) {
        await ref
            .read(creditCardListProvider.notifier)
            .adjustUsedAmount(cloned.creditCardId!, cloned.amount);
      } else if (cloned.accountId != null) {
        await ref
            .read(bankAccountListProvider.notifier)
            .adjustAccountBalance(cloned.accountId!, -cloned.amount);
      }
    }

    await ref
        .read(transactionListNotifierProvider.notifier)
        .addTransaction(cloned);

    AppHaptics.success();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicated "${cloned.title}" (${CurrencyFormatter.format(cloned.amount)}).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthlyTransactions = ref.watch(monthlyTransactionsProvider);
    final monthTitle = DateFormat('MMMM yyyy').format(selectedMonth);

    // Apply Filter
    TransactionType? filterType;
    if (_selectedFilterIndex == 1) filterType = TransactionType.expense;
    if (_selectedFilterIndex == 2) filterType = TransactionType.income;

    var filteredTransactions = FinancialCalculator.filterByType(
      monthlyTransactions,
      filterType,
    );

    // Apply Search
    if (_searchController.text.trim().isNotEmpty) {
      filteredTransactions = FinancialCalculator.searchTransactions(
        filteredTransactions,
        _searchController.text.trim(),
      );
    }

    final grouped = FinancialCalculator.groupTransactionsByDate(filteredTransactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: 'Jump to Current Month',
            onPressed: () {
              ref.read(selectedMonthProvider.notifier).resetToCurrentMonth();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Month Navigation Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: financialColors.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () {
                      ref.read(selectedMonthProvider.notifier).previousMonth();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedMonth,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2040),
                      );
                      if (picked != null) {
                        ref.read(selectedMonthProvider.notifier).setMonth(picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            monthTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () {
                      ref.read(selectedMonthProvider.notifier).nextMonth();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search title, category, notes, amount...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            // Filter Chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelected = _selectedFilterIndex == index;
                  return ChoiceChip(
                    label: Text(_filters[index]),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFilterIndex = index;
                        });
                      }
                    },
                    selectedColor: AppColors.primaryEmerald.withAlpha(isDark ? 60 : 40),
                    labelStyle: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? AppColors.primaryMint : AppColors.primaryTeal)
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primaryEmerald
                            : financialColors.cardBorder,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Transactions Grouped List or Empty State
            Expanded(
              child: grouped.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? AppColors.darkSurfaceVariant
                                    : AppColors.lightSurfaceVariant,
                                border: Border.all(
                                  color: financialColors.cardBorder,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.receipt_rounded,
                                size: 36,
                                color: financialColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No Matching Transactions'
                                  : 'No Transactions in $monthTitle',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Try modifying your search or filter keywords.'
                                  : 'Tap below to add an income or expense for this month.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: financialColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: () => AddEditTransactionSheet.show(context),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add Transaction'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: grouped.keys.length,
                      itemBuilder: (context, groupIndex) {
                        final date = grouped.keys.elementAt(groupIndex);
                        final items = grouped[date]!;

                        final dayIncome = FinancialCalculator.calculateTotalIncome(items);
                        final dayExpense = FinancialCalculator.calculateTotalExpense(items);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date header with daily sum
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDateHeader(date),
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: financialColors.textMuted,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (dayIncome > 0)
                                        Text(
                                          '+${CurrencyFormatter.format(dayIncome)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: financialColors.income,
                                          ),
                                        ),
                                      if (dayIncome > 0 && dayExpense > 0)
                                        const SizedBox(width: 8),
                                      if (dayExpense > 0)
                                        Text(
                                          '-${CurrencyFormatter.format(dayExpense)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: financialColors.expense,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            ...items.map((tx) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TransactionListItem(
                                  transaction: tx,
                                  onTap: () => TransactionDetailSheet.show(
                                    context,
                                    transaction: tx,
                                  ),
                                  onDuplicate: () => _duplicateTransaction(tx),
                                  onDelete: () => ref
                                      .read(transactionListNotifierProvider.notifier)
                                      .deleteTransaction(tx.id),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
