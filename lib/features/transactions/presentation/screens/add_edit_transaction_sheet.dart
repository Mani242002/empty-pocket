import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/category_constants.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../state/transactions_provider.dart';

class AddEditTransactionSheet extends ConsumerStatefulWidget {
  final TransactionEntity? initialTransaction;
  final TransactionType initialType;

  const AddEditTransactionSheet({
    super.key,
    this.initialTransaction,
    this.initialType = TransactionType.expense,
  });

  static Future<void> show(
    BuildContext context, {
    TransactionEntity? transaction,
    TransactionType initialType = TransactionType.expense,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditTransactionSheet(
        initialTransaction: transaction,
        initialType: transaction?.type ?? initialType,
      ),
    );
  }

  @override
  ConsumerState<AddEditTransactionSheet> createState() =>
      _AddEditTransactionSheetState();
}

class _AddEditTransactionSheetState
    extends ConsumerState<AddEditTransactionSheet> {
  late TransactionType _selectedType;
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  late String _selectedCategory;
  late String _selectedPaymentSource;
  late DateTime _selectedDate;

  final _formKey = GlobalKey<FormState>();

  bool get _isEditMode => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.initialTransaction;

    _selectedType = tx?.type ?? widget.initialType;
    _titleController = TextEditingController(text: tx?.title ?? '');
    _amountController = TextEditingController(
      text: tx != null ? (tx.amount == tx.amount.roundToDouble() ? tx.amount.toInt().toString() : tx.amount.toString()) : '',
    );
    _notesController = TextEditingController(text: tx?.notes ?? '');

    final categories = _selectedType == TransactionType.income
        ? CategoryConstants.incomeCategories
        : CategoryConstants.expenseCategories;

    _selectedCategory = tx?.category ?? categories.first.name;
    _selectedPaymentSource = tx?.paymentSource ?? CategoryConstants.paymentSources.first;
    _selectedDate = tx?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTypeChanged(TransactionType newType) {
    if (_selectedType == newType) return;
    setState(() {
      _selectedType = newType;
      final categories = newType == TransactionType.income
          ? CategoryConstants.incomeCategories
          : CategoryConstants.expenseCategories;
      _selectedCategory = categories.first.name;
    });
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );

      setState(() {
        _selectedDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime?.hour ?? _selectedDate.hour,
          pickedTime?.minute ?? _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive amount.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final title = _titleController.text.trim().isEmpty
        ? _selectedCategory
        : _titleController.text.trim();

    final now = DateTime.now();

    if (_isEditMode) {
      final updated = widget.initialTransaction!.copyWith(
        title: title,
        amount: amount,
        type: _selectedType,
        category: _selectedCategory,
        date: _selectedDate,
        paymentSource: _selectedPaymentSource,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        updatedAt: now,
      );

      await ref
          .read(transactionListNotifierProvider.notifier)
          .updateTransaction(updated);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated "${updated.title}" successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      final newTx = TransactionEntity(
        id: const Uuid().v4(),
        title: title,
        amount: amount,
        type: _selectedType,
        category: _selectedCategory,
        date: _selectedDate,
        paymentSource: _selectedPaymentSource,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await ref
          .read(transactionListNotifierProvider.notifier)
          .addTransaction(newTx);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${newTx.title}" (${CurrencyFormatter.format(newTx.amount)}).'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteTransaction() async {
    if (!_isEditMode) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to permanently delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(transactionListNotifierProvider.notifier)
          .deleteTransaction(widget.initialTransaction!.id);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final isIncome = _selectedType == TransactionType.income;
    final activeAccentColor = isIncome ? financialColors.income : financialColors.expense;
    final categories = isIncome
        ? CategoryConstants.incomeCategories
        : CategoryConstants.expenseCategories;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: financialColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header & Mode Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditMode ? 'Edit Transaction' : 'New Transaction',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_isEditMode)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                        onPressed: _deleteTransaction,
                        tooltip: 'Delete',
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Type Toggle (Expense / Income)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTypeSegment(
                          title: 'Expense',
                          icon: Icons.arrow_upward_rounded,
                          isSelected: _selectedType == TransactionType.expense,
                          color: financialColors.expense,
                          onTap: () => _onTypeChanged(TransactionType.expense),
                        ),
                      ),
                      Expanded(
                        child: _buildTypeSegment(
                          title: 'Income',
                          icon: Icons.arrow_downward_rounded,
                          isSelected: _selectedType == TransactionType.income,
                          color: financialColors.income,
                          onTap: () => _onTypeChanged(TransactionType.income),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Amount Field
                Text(
                  'AMOUNT',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: activeAccentColor,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      child: Text(
                        '₹',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: activeAccentColor,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    hintText: '0.00',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Invalid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Quick Amount Adders
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [100, 200, 500, 1000, 2000, 5000].map((quickAdd) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text('+₹$quickAdd'),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          onPressed: () {
                            final current = double.tryParse(_amountController.text) ?? 0;
                            final next = current + quickAdd;
                            _amountController.text = next.toStringAsFixed(0);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Description / Title Field
                Text(
                  'TITLE / REASON',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Lunch at Cafe, Grocery Mart, Salary',
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                  ),
                ),
                const SizedBox(height: 20),

                // Category Selector
                Text(
                  'CATEGORY',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final item = categories[index];
                      final isSelected = _selectedCategory == item.name;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = item.name;
                            if (_titleController.text.trim().isEmpty) {
                              _titleController.text = item.name;
                            }
                          });
                        },
                        child: Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? item.color.withAlpha(isDark ? 60 : 35)
                                : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? item.color : financialColors.cardBorder,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(item.icon, color: isSelected ? item.color : financialColors.textMuted, size: 24),
                              const SizedBox(height: 6),
                              Text(
                                item.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                      : financialColors.textMuted,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Payment Source and Date Pickers Row
                Row(
                  children: [
                    // Payment Source Dropdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PAYMENT SOURCE',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: financialColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedPaymentSource,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.account_balance_wallet_rounded, size: 18),
                            ),
                            items: CategoryConstants.paymentSources.map((source) {
                              return DropdownMenuItem(
                                value: source,
                                child: Text(source, style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedPaymentSource = val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Date & Time Picker
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DATE & TIME',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: financialColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: financialColors.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      DateFormat('dd MMM, h:mm a').format(_selectedDate),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Optional Notes
                Text(
                  'NOTES (OPTIONAL)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Add additional details or remarks...',
                  ),
                ),
                const SizedBox(height: 28),

                // Save Action Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: activeAccentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _saveTransaction,
                    child: Text(
                      _isEditMode ? 'Save Changes' : 'Record Transaction',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSegment({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withAlpha(isDark ? 80 : 50),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
