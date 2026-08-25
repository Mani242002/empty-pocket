import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/credit_card_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../state/accounts_cards_provider.dart';

class AddEditCreditCardSheet extends ConsumerStatefulWidget {
  final CreditCardEntity? initialCard;

  const AddEditCreditCardSheet({super.key, this.initialCard});

  static Future<void> show(BuildContext context, {CreditCardEntity? card}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditCreditCardSheet(initialCard: card),
    );
  }

  @override
  ConsumerState<AddEditCreditCardSheet> createState() =>
      _AddEditCreditCardSheetState();
}

class _AddEditCreditCardSheetState
    extends ConsumerState<AddEditCreditCardSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _bankController;
  late TextEditingController _limitController;
  late TextEditingController _usedController;

  late CardNetwork _selectedNetwork;
  late int _selectedStatementDay;
  late int _selectedGracePeriod;
  late String _selectedTheme;

  bool get _isEditMode => widget.initialCard != null;

  final List<Map<String, dynamic>> _cardThemes = [
    {
      'id': 'obsidian',
      'name': 'Obsidian',
      'gradient': [const Color(0xFF1E293B), const Color(0xFF0F172A), const Color(0xFF020617)],
    },
    {
      'id': 'emerald',
      'name': 'Emerald',
      'gradient': [const Color(0xFF065F46), const Color(0xFF047857), const Color(0xFF064E3B)],
    },
    {
      'id': 'midnightBlue',
      'name': 'Midnight',
      'gradient': [const Color(0xFF1E3A8A), const Color(0xFF1E40AF), const Color(0xFF0F172A)],
    },
    {
      'id': 'royalPurple',
      'name': 'Amethyst',
      'gradient': [const Color(0xFF581C87), const Color(0xFF6B21A8), const Color(0xFF3B0764)],
    },
    {
      'id': 'roseGold',
      'name': 'Rose Gold',
      'gradient': [const Color(0xFF9D174D), const Color(0xFFBE185D), const Color(0xFF831843)],
    },
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.initialCard;

    _nameController = TextEditingController(text: c?.cardName ?? '');
    _bankController = TextEditingController(text: c?.bankName ?? '');
    _limitController = TextEditingController(
      text: c != null
          ? (c.creditLimit == c.creditLimit.roundToDouble()
              ? c.creditLimit.toInt().toString()
              : c.creditLimit.toString())
          : '',
    );
    _usedController = TextEditingController(
      text: c != null
          ? (c.usedAmount == c.usedAmount.roundToDouble()
              ? c.usedAmount.toInt().toString()
              : c.usedAmount.toString())
          : '0',
    );

    _selectedNetwork = c?.cardNetwork ?? CardNetwork.visa;
    _selectedStatementDay = c?.statementDateDay ?? 15;
    _selectedGracePeriod = c?.gracePeriodDays ?? 20;
    _selectedTheme = c?.cardTheme ?? 'obsidian';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankController.dispose();
    _limitController.dispose();
    _usedController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final limit = double.tryParse(_limitController.text.trim()) ?? 0.0;
    final used = double.tryParse(_usedController.text.trim()) ?? 0.0;
    final cardName = _nameController.text.trim();
    final bankName = _bankController.text.trim().isEmpty
        ? 'Credit Card'
        : _bankController.text.trim();

    final now = DateTime.now();

    if (_isEditMode) {
      final updated = widget.initialCard!.copyWith(
        cardName: cardName,
        bankName: bankName,
        cardNetwork: _selectedNetwork,
        creditLimit: limit,
        usedAmount: used,
        statementDateDay: _selectedStatementDay,
        gracePeriodDays: _selectedGracePeriod,
        cardTheme: _selectedTheme,
        updatedAt: now,
      );

      await ref.read(creditCardListProvider.notifier).saveCard(updated);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated "${updated.cardName}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      final newCard = CreditCardEntity(
        id: const Uuid().v4(),
        cardName: cardName,
        bankName: bankName,
        cardNetwork: _selectedNetwork,
        creditLimit: limit,
        usedAmount: used,
        statementDateDay: _selectedStatementDay,
        gracePeriodDays: _selectedGracePeriod,
        cardTheme: _selectedTheme,
        createdAt: now,
        updatedAt: now,
      );

      await ref.read(creditCardListProvider.notifier).saveCard(newCard);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${newCard.cardName}" (${CurrencyFormatter.format(newCard.creditLimit)} limit)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (!_isEditMode) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Credit Card?'),
        content: Text(
          'Are you sure you want to remove "${widget.initialCard!.cardName}"? Historical transactions will remain in ledger.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(creditCardListProvider.notifier).deleteCard(widget.initialCard!.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credit card removed.'),
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

    final limitVal = double.tryParse(_limitController.text) ?? 0.0;
    final usedVal = double.tryParse(_usedController.text) ?? 0.0;
    final ratio = limitVal > 0 ? (usedVal / limitVal) * 100 : 0.0;

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
                  // Drag Handle
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
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withAlpha(isDark ? 40 : 25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.credit_card_rounded,
                                color: Color(0xFF6366F1),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isEditMode ? 'Edit Credit Card' : 'Add Credit Card',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isEditMode)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                          onPressed: _delete,
                          tooltip: 'Delete Card',
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Card Skin Theme Selector
                  Text(
                    'CARD DESIGN THEME',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _cardThemes.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final th = _cardThemes[index];
                        final isSelected = _selectedTheme == th['id'];
                        final gradient = th['gradient'] as List<Color>;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedTheme = th['id']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: gradient),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: isSelected ? 2 : 0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: gradient.first.withAlpha(120),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                th['name'],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Card Name
                  Text(
                    'CARD NAME',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Millennia, Amazon Pay, Ace, Regalia',
                      prefixIcon: Icon(Icons.style_rounded, size: 20),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter card name';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 18),

                  // Bank / Issuer Name & Card Network Row
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Bank Name
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ISSUER / BANK',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: financialColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _bankController,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. HDFC, ICICI, Axis',
                                  prefixIcon: Icon(Icons.corporate_fare_rounded, size: 18),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Network Dropdown
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NETWORK',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: financialColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<CardNetwork>(
                                initialValue: _selectedNetwork,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.payment_rounded, size: 18),
                                ),
                                items: CardNetwork.values.map((net) {
                                  return DropdownMenuItem(
                                    value: net,
                                    child: Text(net.displayName, style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedNetwork = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Credit Limit & Used Amount Row
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Credit Limit
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL LIMIT',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: financialColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _limitController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                ],
                                decoration: const InputDecoration(
                                  prefixText: '₹ ',
                                  hintText: '200000',
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Enter limit';
                                  if ((double.tryParse(val) ?? 0) <= 0) return 'Invalid limit';
                                  return null;
                                },
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Current Used Balance
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CURRENT USED',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: financialColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _usedController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                ],
                                decoration: const InputDecoration(
                                  prefixText: '₹ ',
                                  hintText: '0',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (limitVal > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available: ${CurrencyFormatter.format(limitVal - usedVal)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: financialColors.textMuted,
                          ),
                        ),
                        Text(
                          'Utilization: ${ratio.toStringAsFixed(1)}% (${ratio <= 30 ? 'Safe' : (ratio <= 50 ? 'Moderate' : 'High')})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ratio <= 30
                                ? financialColors.income
                                : (ratio <= 50 ? const Color(0xFFF59E0B) : financialColors.expense),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Billing Cycle (Statement Date & Grace Period)
                  Text(
                    'BILLING CYCLE & DUE DATES',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bill generates every month on statement day; due date is statement + grace days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Statement Date Day
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedStatementDay,
                            decoration: const InputDecoration(
                              labelText: 'Statement Day',
                              prefixIcon: Icon(Icons.receipt_long_rounded, size: 18),
                            ),
                            items: List.generate(31, (i) => i + 1).map((day) {
                              return DropdownMenuItem(
                                value: day,
                                child: Text('Day $day of month', style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedStatementDay = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Grace Period Days
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedGracePeriod,
                            decoration: const InputDecoration(
                              labelText: 'Grace Period',
                              prefixIcon: Icon(Icons.timelapse_rounded, size: 18),
                            ),
                            items: [15, 18, 20, 22, 25, 28, 30].map((days) {
                              return DropdownMenuItem(
                                value: days,
                                child: Text('$days Days to Pay', style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedGracePeriod = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _save,
                      child: Text(
                        _isEditMode ? 'Save Changes' : 'Add Credit Card',
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
