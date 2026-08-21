import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/category_constants.dart';
import '../../../../core/domain/entities/recurring_expense_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../state/recurring_provider.dart';

class AddRecurringSheet extends ConsumerStatefulWidget {
  final RecurringExpenseEntity? initialRecurring;

  const AddRecurringSheet({super.key, this.initialRecurring});

  static Future<void> show(
    BuildContext context, {
    RecurringExpenseEntity? recurring,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddRecurringSheet(initialRecurring: recurring),
    );
  }

  @override
  ConsumerState<AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends ConsumerState<AddRecurringSheet> {
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late String _selectedCategory;
  late RecurringFrequency _selectedFrequency;
  late String _selectedPaymentSource;
  late DateTime _nextDueDate;
  late bool _isActive;

  final _formKey = GlobalKey<FormState>();

  bool get _isEditMode => widget.initialRecurring != null;

  @override
  void initState() {
    super.initState();
    final item = widget.initialRecurring;

    _titleController = TextEditingController(text: item?.title ?? '');
    _amountController = TextEditingController(
      text: item != null
          ? (item.amount == item.amount.roundToDouble()
              ? item.amount.toInt().toString()
              : item.amount.toString())
          : '',
    );
    _selectedCategory = item?.category ?? CategoryConstants.expenseCategories.first.name;
    _selectedFrequency = item?.frequency ?? RecurringFrequency.monthly;
    _selectedPaymentSource = item?.paymentSource ?? CategoryConstants.paymentSources.first;
    _nextDueDate = item?.nextDueDate ?? DateTime.now().add(const Duration(days: 7));
    _isActive = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime(2040),
    );

    if (picked != null && mounted) {
      setState(() {
        _nextDueDate = picked;
      });
    }
  }

  Future<void> _saveRecurring() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive recurring amount.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final title = _titleController.text.trim();
    final now = DateTime.now();

    final item = RecurringExpenseEntity(
      id: widget.initialRecurring?.id ?? const Uuid().v4(),
      title: title,
      amount: amount,
      category: _selectedCategory,
      frequency: _selectedFrequency,
      paymentSource: _selectedPaymentSource,
      startDate: widget.initialRecurring?.startDate ?? now,
      nextDueDate: _nextDueDate,
      isActive: _isActive,
      createdAt: widget.initialRecurring?.createdAt ?? now,
      updatedAt: now,
    );

    await ref.read(recurringListNotifierProvider.notifier).saveRecurring(item);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved recurring expense "${item.title}" (${CurrencyFormatter.format(item.amount)}/${item.frequency.displayName.toLowerCase()}).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteRecurring() async {
    if (!_isEditMode) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recurring Expense?'),
        content: Text('Permanently remove "${widget.initialRecurring!.title}"?'),
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
          .read(recurringListNotifierProvider.notifier)
          .deleteRecurring(widget.initialRecurring!.id);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recurring expense removed.'),
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
    final categories = CategoryConstants.expenseCategories;

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

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditMode ? 'Edit Recurring Expense' : 'New Recurring Expense',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_isEditMode)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                        onPressed: _deleteRecurring,
                        tooltip: 'Delete',
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Title Field
                Text(
                  'SUBSCRIPTION / BILL TITLE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Netflix, Apartment Rent, Gym, Spotify',
                    prefixIcon: Icon(Icons.repeat_rounded),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Please enter title' : null,
                ),
                const SizedBox(height: 18),

                // Amount Field
                Text(
                  'PAYMENT AMOUNT',
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
                    color: financialColors.savings,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      child: Text(
                        '₹',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: financialColors.savings,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    hintText: '649.00',
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Please enter amount' : null,
                ),
                const SizedBox(height: 18),

                // Frequency Selector
                Text(
                  'FREQUENCY',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<RecurringFrequency>(
                  segments: const [
                    ButtonSegment(value: RecurringFrequency.weekly, label: Text('Weekly')),
                    ButtonSegment(value: RecurringFrequency.monthly, label: Text('Monthly')),
                    ButtonSegment(value: RecurringFrequency.yearly, label: Text('Yearly')),
                  ],
                  selected: {_selectedFrequency},
                  onSelectionChanged: (set) {
                    setState(() => _selectedFrequency = set.first);
                  },
                ),
                const SizedBox(height: 18),

                // Category Selector
                Text(
                  'CATEGORY',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final item = categories[index];
                      final isSelected = _selectedCategory == item.name;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = item.name),
                        child: Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
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
                              Icon(item.icon, color: isSelected ? item.color : financialColors.textMuted, size: 22),
                              const SizedBox(height: 4),
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
                const SizedBox(height: 18),

                // Next Due Date & Payment Source
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEXT DUE DATE',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: financialColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickDueDate,
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
                                  const Icon(Icons.event_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      DateFormat('dd MMM yyyy').format(_nextDueDate),
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
                    const SizedBox(width: 12),
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
                            items: CategoryConstants.paymentSources.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text(s, style: const TextStyle(fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedPaymentSource = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Save Action
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: financialColors.savings,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _saveRecurring,
                    child: Text(
                      _isEditMode ? 'Update Recurring Plan' : 'Save Recurring Plan',
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
}
