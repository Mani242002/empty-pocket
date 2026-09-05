import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/bank_account_entity.dart';
import '../../../../core/domain/entities/credit_card_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../state/accounts_cards_provider.dart';

class PayCreditCardSheet extends ConsumerStatefulWidget {
  final CreditCardEntity? initialCard;
  final BankAccountEntity? initialFromAccount;

  const PayCreditCardSheet({
    super.key,
    this.initialCard,
    this.initialFromAccount,
  });

  static Future<void> show(
    BuildContext context, {
    CreditCardEntity? card,
    BankAccountEntity? fromAccount,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PayCreditCardSheet(
        initialCard: card,
        initialFromAccount: fromAccount,
      ),
    );
  }

  @override
  ConsumerState<PayCreditCardSheet> createState() => _PayCreditCardSheetState();
}

class _PayCreditCardSheetState extends ConsumerState<PayCreditCardSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;

  String? _cardId;
  String? _fromAccountId;

  @override
  void initState() {
    super.initState();
    _cardId = widget.initialCard?.id;
    _fromAccountId = widget.initialFromAccount?.id;
    _selectedDate = DateTime.now();

    final initialAmount = widget.initialCard?.usedAmount ?? 0.0;
    _amountController = TextEditingController(
      text: initialAmount > 0
          ? (initialAmount == initialAmount.roundToDouble()
              ? initialAmount.toInt().toString()
              : initialAmount.toString())
          : '',
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final cards = ref.read(activeCreditCardsProvider);
    final accounts = ref.read(activeBankAccountsProvider);

    if (_cardId == null || _fromAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both the credit card and payment bank account.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final card = cards.firstWhere((c) => c.id == _cardId);
    final account = accounts.firstWhere((a) => a.id == _fromAccountId);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid payment amount.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (account.currentBalance < amount) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Insufficient Bank Balance Warning'),
          content: Text(
            'Bill amount (${CurrencyFormatter.format(amount)}) exceeds current balance in "${account.accountName}" (${CurrencyFormatter.format(account.currentBalance)}). Proceed anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    await ref.read(accountOperationsProvider).payCreditCardBill(
          fromAccount: account,
          creditCard: card,
          amount: amount,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          date: _selectedDate,
        );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Paid ${CurrencyFormatter.format(amount)} towards "${card.cardName}". Available credit restored.',
          ),
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

    final cards = ref.watch(activeCreditCardsProvider);
    final accounts = ref.watch(activeBankAccountsProvider);

    if (_cardId == null && cards.isNotEmpty) {
      _cardId = cards.first.id;
      if (_amountController.text.isEmpty && cards.first.usedAmount > 0) {
        _amountController.text = cards.first.usedAmount.toStringAsFixed(0);
      }
    }
    if (_fromAccountId == null && accounts.isNotEmpty) {
      final defaultAcc = ref.watch(defaultBankAccountProvider);
      _fromAccountId = defaultAcc?.id ?? accounts.first.id;
    }

    final selectedCard = cards.where((c) => c.id == _cardId).firstOrNull;

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
                  // Handle
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.investment.withAlpha(isDark ? 40 : 25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.credit_score_rounded,
                          color: AppColors.investment,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pay Credit Card Bill',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Credit Card Selector
                  Text(
                    'SELECT CREDIT CARD TO PAY',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _cardId,
                    isExpanded: true,
                    isDense: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.credit_card_rounded, size: 20),
                    ),
                    items: cards.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          '${c.cardName} (${c.bankName}) • Due: ${CurrencyFormatter.format(c.usedAmount)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _cardId = val;
                          final card = cards.firstWhere((c) => c.id == val);
                          if (card.usedAmount > 0) {
                            _amountController.text = card.usedAmount.toStringAsFixed(0);
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 18),

                  // Source Bank Account Selector
                  Text(
                    'PAY FROM (BANK ACCOUNT)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _fromAccountId,
                    isExpanded: true,
                    isDense: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.account_balance_rounded, size: 20),
                    ),
                    items: accounts.map((a) {
                      return DropdownMenuItem(
                        value: a.id,
                        child: Text(
                          '${a.accountName} [${a.usedFor}] • Balance: ${CurrencyFormatter.format(a.currentBalance)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _fromAccountId = val),
                  ),
                  const SizedBox(height: 18),

                  // Amount
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
                      color: const Color(0xFF6366F1),
                    ),
                    decoration: const InputDecoration(
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 16, right: 8),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                      prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: '0.00',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Enter amount';
                      if ((double.tryParse(val) ?? 0) <= 0) return 'Invalid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Quick payoff chips
                  if (selectedCard != null && selectedCard.usedAmount > 0) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ActionChip(
                            label: Text('Full Outstanding (${CurrencyFormatter.format(selectedCard.usedAmount)})'),
                            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            onPressed: () {
                              _amountController.text = selectedCard.usedAmount.toStringAsFixed(0);
                            },
                          ),
                          const SizedBox(width: 8),
                          if (selectedCard.usedAmount > 1000)
                            ActionChip(
                              label: Text('Min Due (~5%: ${CurrencyFormatter.format(selectedCard.usedAmount * 0.05)})'),
                              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              onPressed: () {
                                final minDue = (selectedCard.usedAmount * 0.05).clamp(500, selectedCard.usedAmount);
                                _amountController.text = minDue.toStringAsFixed(0);
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Notes
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
                    decoration: const InputDecoration(
                      hintText: 'e.g. Monthly statement clearance',
                      prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pay Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                      label: const Text(
                        'Record Bill Payment',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      onPressed: _submitPayment,
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
