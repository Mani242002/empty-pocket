import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/category_constants.dart';
import '../../../../core/domain/entities/investment_entity.dart';
import '../state/investments_provider.dart';

class AddEditInvestmentSheet extends ConsumerStatefulWidget {
  final InvestmentEntity? initialInvestment;

  const AddEditInvestmentSheet({super.key, this.initialInvestment});

  static Future<void> show(BuildContext context, {InvestmentEntity? investment}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditInvestmentSheet(initialInvestment: investment),
    );
  }

  @override
  ConsumerState<AddEditInvestmentSheet> createState() => _AddEditInvestmentSheetState();
}

class _AddEditInvestmentSheetState extends ConsumerState<AddEditInvestmentSheet> {
  late TextEditingController _nameController;
  late TextEditingController _investedController;
  late TextEditingController _currentValueController;
  late TextEditingController _unitsController;
  late TextEditingController _priceController;
  late TextEditingController _institutionController;
  late TextEditingController _notesController;
  late AssetClass _selectedAssetClass;
  late String _selectedPaymentSource;
  bool _logAsTransaction = false;

  final _formKey = GlobalKey<FormState>();

  bool get _isEditMode => widget.initialInvestment != null;

  @override
  void initState() {
    super.initState();
    final inv = widget.initialInvestment;

    _nameController = TextEditingController(text: inv?.name ?? '');
    _investedController = TextEditingController(
      text: inv != null
          ? (inv.investedAmount == inv.investedAmount.roundToDouble()
              ? inv.investedAmount.toInt().toString()
              : inv.investedAmount.toString())
          : '',
    );
    _currentValueController = TextEditingController(
      text: inv != null
          ? (inv.currentValue == inv.currentValue.roundToDouble()
              ? inv.currentValue.toInt().toString()
              : inv.currentValue.toString())
          : '',
    );
    _unitsController = TextEditingController(
      text: inv?.units != null ? inv!.units.toString() : '',
    );
    _priceController = TextEditingController(
      text: inv?.currentPrice != null ? inv!.currentPrice.toString() : '',
    );
    _institutionController = TextEditingController(text: inv?.institution ?? '');
    _notesController = TextEditingController(text: inv?.notes ?? '');
    _selectedAssetClass = inv?.assetClass ?? AssetClass.equity;
    _selectedPaymentSource = CategoryConstants.paymentSources.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _investedController.dispose();
    _currentValueController.dispose();
    _unitsController.dispose();
    _priceController.dispose();
    _institutionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onUnitsOrPriceChanged() {
    final units = double.tryParse(_unitsController.text.trim());
    final price = double.tryParse(_priceController.text.trim());

    if (units != null && price != null && units > 0 && price > 0) {
      final total = units * price;
      setState(() {
        _currentValueController.text = total.toStringAsFixed(2);
        if (_investedController.text.trim().isEmpty) {
          _investedController.text = total.toStringAsFixed(2);
        }
      });
    }
  }

  Future<void> _saveInvestment() async {
    if (!_formKey.currentState!.validate()) return;

    final invested = double.tryParse(_investedController.text.trim());
    if (invested == null || invested <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid invested amount.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final currentVal = double.tryParse(_currentValueController.text.trim()) ?? invested;
    final units = double.tryParse(_unitsController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    final name = _nameController.text.trim();
    final institution = _institutionController.text.trim().isEmpty ? null : _institutionController.text.trim();
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    final now = DateTime.now();

    final investment = InvestmentEntity(
      id: widget.initialInvestment?.id ?? const Uuid().v4(),
      name: name,
      assetClass: _selectedAssetClass,
      investedAmount: invested,
      currentValue: currentVal,
      units: units,
      buyPrice: price,
      currentPrice: price,
      institution: institution,
      notes: notes,
      createdAt: widget.initialInvestment?.createdAt ?? now,
      updatedAt: now,
    );

    await ref.read(investmentListNotifierProvider.notifier).saveInvestment(
          investment,
          logAsTransaction: !_isEditMode && _logAsTransaction,
          paymentSource: _selectedPaymentSource,
        );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "${investment.name}" in ${investment.assetClass.displayName}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteInvestment() async {
    if (!_isEditMode) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Investment Holding?'),
        content: Text('Permanently remove "${widget.initialInvestment!.name}" from your portfolio?'),
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
      await ref.read(investmentListNotifierProvider.notifier).deleteInvestment(widget.initialInvestment!.id);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Investment holding removed.'),
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
                        _isEditMode ? 'Edit Holding' : 'Add Investment Asset',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_isEditMode)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                          onPressed: _deleteInvestment,
                          tooltip: 'Delete',
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Asset Name
                  Text(
                    'HOLDING / ASSET NAME',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Parag Parikh Flexi Cap, Reliance, SBI FD, PPF',
                      prefixIcon: Icon(Icons.show_chart_rounded),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Please enter holding name' : null,
                  ),
                  const SizedBox(height: 18),

                  // Asset Class Dropdown
                  Text(
                    'ASSET CLASS',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AssetClass>(
                    initialValue: _selectedAssetClass,
                    decoration: InputDecoration(
                      prefixIcon: Icon(_selectedAssetClass.icon, color: _selectedAssetClass.color),
                    ),
                    items: AssetClass.values.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(c.displayName),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedAssetClass = val);
                    },
                  ),
                  const SizedBox(height: 18),

                  // Invested Amount & Current Market Value
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL INVESTED',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: financialColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _investedController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: const InputDecoration(
                                prefixText: '₹ ',
                                hintText: '50,000',
                              ),
                              onChanged: (val) {
                                if (_currentValueController.text.trim().isEmpty) {
                                  _currentValueController.text = val;
                                }
                              },
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Enter invested amount' : null,
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
                              'CURRENT VALUE',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: financialColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _currentValueController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: financialColors.income,
                              ),
                              decoration: const InputDecoration(
                                prefixText: '₹ ',
                                hintText: '62,500',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Optional Units & Price per unit
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'UNITS / QTY (OPTIONAL)',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: financialColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _unitsController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                hintText: '100.5',
                              ),
                              onChanged: (_) => _onUnitsOrPriceChanged(),
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
                              'PRICE / NAV (OPTIONAL)',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: financialColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                prefixText: '₹ ',
                                hintText: '245.80',
                              ),
                              onChanged: (_) => _onUnitsOrPriceChanged(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Institution / Broker
                  Text(
                    'BROKER / PLATFORM / BANK',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _institutionController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Zerodha, Groww, SBI, HDFC, Kuvera',
                      prefixIcon: Icon(Icons.account_balance_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Optional Ledger Expense Sync (for new investments)
                  if (!_isEditMode) ...[
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Log as Expense in Daily Ledger', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Deducts invested amount from active month net balance'),
                      value: _logAsTransaction,
                      activeColor: AppColors.primaryEmerald,
                      onChanged: (val) => setState(() => _logAsTransaction = val ?? false),
                    ),
                    if (_logAsTransaction) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPaymentSource,
                        decoration: const InputDecoration(
                          labelText: 'Payment Account',
                          prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                        ),
                        items: CategoryConstants.paymentSources.map((s) {
                          return DropdownMenuItem(value: s, child: Text(s));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedPaymentSource = val);
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],

                  // Optional Notes
                  Text(
                    'NOTES (OPTIONAL)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Monthly SIP, Long-term compounder, Maturing in 2028',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: financialColors.income,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _saveInvestment,
                      child: Text(
                        _isEditMode ? 'Update Holding' : 'Save Investment Holding',
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
