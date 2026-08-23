import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/domain/entities/category_constants.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../state/budgets_provider.dart';

class SetBudgetSheet extends ConsumerStatefulWidget {
  final BudgetEntity? initialBudget;
  final DateTime? targetMonth;

  const SetBudgetSheet({
    super.key,
    this.initialBudget,
    this.targetMonth,
  });

  static Future<void> show(
    BuildContext context, {
    BudgetEntity? budget,
    DateTime? targetMonth,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SetBudgetSheet(
        initialBudget: budget,
        targetMonth: targetMonth,
      ),
    );
  }

  @override
  ConsumerState<SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends ConsumerState<SetBudgetSheet> {
  late TextEditingController _amountController;
  late String _selectedCategory;
  late DateTime _targetMonth;
  final _formKey = GlobalKey<FormState>();

  bool get _isEditMode => widget.initialBudget != null;

  @override
  void initState() {
    super.initState();
    final budget = widget.initialBudget;
    _amountController = TextEditingController(
      text: budget != null
          ? (budget.limitAmount == budget.limitAmount.roundToDouble()
              ? budget.limitAmount.toInt().toString()
              : budget.limitAmount.toString())
          : '',
    );

    _selectedCategory = budget?.category ?? CategoryConstants.expenseCategories.first.name;
    _targetMonth = widget.targetMonth ?? budget?.month ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    final limit = double.tryParse(_amountController.text.trim());
    if (limit == null || limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive budget limit.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final budgetMonth = DateTime(_targetMonth.year, _targetMonth.month, 1);

    final budget = BudgetEntity(
      id: widget.initialBudget?.id ?? const Uuid().v4(),
      category: _selectedCategory,
      limitAmount: limit,
      month: budgetMonth,
      createdAt: widget.initialBudget?.createdAt ?? now,
      updatedAt: now,
    );

    await ref.read(budgetListNotifierProvider.notifier).saveBudget(budget);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Budget limit of ${CurrencyFormatter.format(limit)} set for $_selectedCategory (${DateFormat('MMMM yyyy').format(budgetMonth)}).',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteBudget() async {
    if (!_isEditMode) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget Limit'),
        content: Text('Remove the monthly budget limit for $_selectedCategory?'),
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
          .read(budgetListNotifierProvider.notifier)
          .deleteBudget(widget.initialBudget!.id);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget limit deleted.'),
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
    final monthLabel = DateFormat('MMMM yyyy').format(_targetMonth);

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditMode ? 'Edit Category Budget' : 'Set Category Budget',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'For $monthLabel',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: financialColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (_isEditMode)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                        onPressed: _deleteBudget,
                        tooltip: 'Delete Budget',
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Budget Limit Field
                Text(
                  'MONTHLY SPENDING LIMIT',
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
                    color: financialColors.investment,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      child: Text(
                        '₹',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: financialColors.investment,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    hintText: '5,000',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter budget limit';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Invalid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Quick Limit Adders
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [2000, 5000, 10000, 15000, 25000, 50000].map((amount) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text('₹$amount'),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          onPressed: () {
                            _amountController.text = amount.toString();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Category Selector
                Text(
                  'SELECT CATEGORY',
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
                const SizedBox(height: 28),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: financialColors.investment,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _saveBudget,
                    child: Text(
                      _isEditMode ? 'Update Budget' : 'Save Budget Limit',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
