import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/debt_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../state/debts_provider.dart';

class AddEditDebtSheet extends ConsumerStatefulWidget {
  final DebtEntity? initialDebt;

  const AddEditDebtSheet({super.key, this.initialDebt});

  static Future<void> show(BuildContext context, {DebtEntity? debt}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditDebtSheet(initialDebt: debt),
    );
  }

  @override
  ConsumerState<AddEditDebtSheet> createState() => _AddEditDebtSheetState();
}

class _AddEditDebtSheetState extends ConsumerState<AddEditDebtSheet> {
  late TextEditingController _titleController;
  late TextEditingController _principalController;
  late TextEditingController _remainingController;
  late TextEditingController _interestRateController;
  late TextEditingController _tenureController;
  late TextEditingController _emiController;
  late TextEditingController _lenderController;
  late DebtType _selectedType;
  late DateTime _startDate;
  late int _dueDateDay;

  final _formKey = GlobalKey<FormState>();

  bool get _isEditMode => widget.initialDebt != null;

  @override
  void initState() {
    super.initState();
    final debt = widget.initialDebt;

    _titleController = TextEditingController(text: debt?.title ?? '');
    _principalController = TextEditingController(
      text: debt != null
          ? (debt.principalAmount == debt.principalAmount.roundToDouble()
              ? debt.principalAmount.toInt().toString()
              : debt.principalAmount.toString())
          : '',
    );
    _remainingController = TextEditingController(
      text: debt != null
          ? (debt.remainingAmount == debt.remainingAmount.roundToDouble()
              ? debt.remainingAmount.toInt().toString()
              : debt.remainingAmount.toString())
          : '',
    );
    _interestRateController = TextEditingController(
      text: debt != null && debt.interestRate > 0 ? debt.interestRate.toString() : '8.5',
    );
    _tenureController = TextEditingController(
      text: debt != null ? debt.tenureMonths.toString() : '36',
    );
    _emiController = TextEditingController(
      text: debt != null
          ? (debt.monthlyEmi == debt.monthlyEmi.roundToDouble()
              ? debt.monthlyEmi.toInt().toString()
              : debt.monthlyEmi.toString())
          : '',
    );
    _lenderController = TextEditingController(text: debt?.lenderName ?? '');
    _selectedType = debt?.type ?? DebtType.personalLoan;
    _startDate = debt?.startDate ?? DateTime.now();
    _dueDateDay = debt?.dueDateDay ?? 5;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _principalController.dispose();
    _remainingController.dispose();
    _interestRateController.dispose();
    _tenureController.dispose();
    _emiController.dispose();
    _lenderController.dispose();
    super.dispose();
  }

  void _calculateEmi() {
    final principal = double.tryParse(_principalController.text.trim()) ?? 0.0;
    final rate = double.tryParse(_interestRateController.text.trim()) ?? 0.0;
    final tenure = int.tryParse(_tenureController.text.trim()) ?? 12;

    if (principal > 0 && tenure > 0) {
      final emi = FinancialCalculator.calculateStandardEmi(principal, rate, tenure);
      setState(() {
        _emiController.text = emi.round().toString();
        if (_remainingController.text.trim().isEmpty) {
          _remainingController.text = principal.round().toString();
        }
      });
    }
  }

  Future<void> _saveDebt() async {
    if (!_formKey.currentState!.validate()) return;

    final principal = double.tryParse(_principalController.text.trim());
    if (principal == null || principal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid principal loan amount.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final remaining = double.tryParse(_remainingController.text.trim()) ?? principal;
    final rate = double.tryParse(_interestRateController.text.trim()) ?? 0.0;
    final tenure = int.tryParse(_tenureController.text.trim()) ?? 12;
    final emi = double.tryParse(_emiController.text.trim()) ??
        FinancialCalculator.calculateStandardEmi(principal, rate, tenure);

    final title = _titleController.text.trim();
    final lender = _lenderController.text.trim().isEmpty ? null : _lenderController.text.trim();
    final now = DateTime.now();

    final debt = DebtEntity(
      id: widget.initialDebt?.id ?? const Uuid().v4(),
      title: title,
      type: _selectedType,
      principalAmount: principal,
      remainingAmount: remaining,
      interestRate: rate,
      tenureMonths: tenure,
      monthlyEmi: emi,
      startDate: _startDate,
      dueDateDay: _dueDateDay,
      lenderName: lender,
      status: remaining <= 0 ? DebtStatus.paidOff : DebtStatus.active,
      createdAt: widget.initialDebt?.createdAt ?? now,
      updatedAt: now,
    );

    await ref.read(debtListNotifierProvider.notifier).saveDebt(debt);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "${debt.title}" (${CurrencyFormatter.format(debt.principalAmount)} loan).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteDebt() async {
    if (!_isEditMode) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Debt Record?'),
        content: Text('Permanently remove "${widget.initialDebt!.title}" and all repayment history?'),
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
      await ref.read(debtListNotifierProvider.notifier).deleteDebt(widget.initialDebt!.id);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loan record deleted.'),
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
                        _isEditMode ? 'Edit Loan / Liability' : 'Add Loan / Debt',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_isEditMode)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                          onPressed: _deleteDebt,
                          tooltip: 'Delete',
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Loan Title
                  Text(
                    'LOAN / DEBT TITLE',
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
                      hintText: 'e.g. HDFC Home Loan, Axis Car Loan, Borrowed from Rahul',
                      prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Please enter loan title' : null,
                  ),
                  const SizedBox(height: 18),

                  // Debt Type
                  Text(
                    'LIABILITY TYPE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<DebtType>(
                    initialValue: _selectedType,
                    decoration: InputDecoration(
                      prefixIcon: Icon(_selectedType.icon),
                    ),
                    items: DebtType.values.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t.displayName),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedType = val);
                    },
                  ),
                  const SizedBox(height: 18),

                  // Principal & Remaining Amounts
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PRINCIPAL',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: financialColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _principalController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: financialColors.expense,
                              ),
                              decoration: const InputDecoration(
                                prefixText: '₹ ',
                                hintText: '5,00,000',
                              ),
                              onChanged: (_) => _calculateEmi(),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Enter principal' : null,
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
                              'REMAINING',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: financialColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _remainingController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: const InputDecoration(
                                prefixText: '₹ ',
                                hintText: '5,00,000',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Interest Rate & Tenure
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INTEREST RATE',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: financialColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _interestRateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                suffixText: '%',
                                hintText: '8.5',
                              ),
                              onChanged: (_) => _calculateEmi(),
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
                              'TENURE (MO)',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: financialColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _tenureController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                suffixText: 'mo',
                                hintText: '36',
                              ),
                              onChanged: (_) => _calculateEmi(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Monthly EMI & Due Day
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MONTHLY EMI',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: financialColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emiController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: financialColors.warning,
                              ),
                              decoration: const InputDecoration(
                                prefixText: '₹ ',
                                hintText: '15,780',
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Enter EMI' : null,
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
                              'DUE DAY',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: financialColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              initialValue: _dueDateDay,
                              items: List.generate(31, (i) => i + 1).map((day) {
                                return DropdownMenuItem(
                                  value: day,
                                  child: Text('Day $day'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _dueDateDay = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Lender / Bank Name
                  Text(
                    'LENDER / BANK NAME (OPTIONAL)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _lenderController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. HDFC Bank, SBI, ICICI, Family Member',
                      prefixIcon: Icon(Icons.business_rounded),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Action Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: financialColors.expense,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _saveDebt,
                      child: Text(
                        _isEditMode ? 'Update Loan Record' : 'Save Loan Record',
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
