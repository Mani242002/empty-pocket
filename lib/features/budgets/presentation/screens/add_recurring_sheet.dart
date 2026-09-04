import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/bank_account_entity.dart';
import '../../../../core/domain/entities/category_constants.dart';
import '../../../../core/domain/entities/credit_card_entity.dart';
import '../../../../core/domain/entities/recurring_expense_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
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
  late PaymentMode _selectedPaymentMode;
  String? _selectedAccountId;
  String? _selectedCreditCardId;
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
    _selectedPaymentSource = item?.paymentSource ?? 'Bank Account';
    _selectedAccountId = item?.accountId;
    _selectedCreditCardId = item?.creditCardId;
    _nextDueDate = item?.nextDueDate ?? DateTime.now().add(const Duration(days: 7));
    _isActive = item?.isActive ?? true;

    if (item != null) {
      _selectedPaymentMode = PaymentMode.fromString(item.paymentSource);
      if (item.creditCardId != null && _selectedPaymentMode != PaymentMode.upiWallet) {
        _selectedPaymentMode = PaymentMode.creditCard;
      } else if (item.accountId != null &&
          _selectedPaymentMode != PaymentMode.upiWallet &&
          _selectedPaymentMode != PaymentMode.cash) {
        _selectedPaymentMode = PaymentMode.bankAccount;
      }
    } else {
      _selectedPaymentMode = PaymentMode.bankAccount;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _autoSelectLinkedSource(
    PaymentMode mode,
    List<BankAccountEntity> bankAccounts,
    List<CreditCardEntity> creditCards,
  ) {
    switch (mode) {
      case PaymentMode.bankAccount:
        if (bankAccounts.isNotEmpty) {
          final def = bankAccounts.where((a) => a.isDefault).firstOrNull;
          final matched = AccountPurposeTags.matchAccountForCategory(
            _selectedCategory,
            bankAccounts,
            defaultAccount: def,
          );
          final acc = matched ?? (def ?? bankAccounts.first);
          _selectedAccountId = acc.id;
          _selectedCreditCardId = null;
          _selectedPaymentSource = acc.accountName;
        } else {
          _selectedAccountId = null;
          _selectedCreditCardId = null;
          _selectedPaymentSource = 'Bank Account';
        }
        break;
      case PaymentMode.creditCard:
        if (creditCards.isNotEmpty) {
          final card = creditCards.first;
          _selectedCreditCardId = card.id;
          _selectedAccountId = null;
          _selectedPaymentSource = card.cardName;
        } else {
          _selectedAccountId = null;
          _selectedCreditCardId = null;
          _selectedPaymentSource = 'Credit Card';
        }
        break;
      case PaymentMode.upiWallet:
        if (bankAccounts.isNotEmpty) {
          final def = bankAccounts.where((a) => a.isDefault).firstOrNull;
          final matched = AccountPurposeTags.matchAccountForCategory(
            _selectedCategory,
            bankAccounts,
            defaultAccount: def,
          );
          final acc = matched ?? (def ?? bankAccounts.first);
          _selectedAccountId = acc.id;
          _selectedCreditCardId = null;
          _selectedPaymentSource = 'UPI (${acc.accountName})';
        } else {
          final rupayCards = creditCards.where((c) => c.cardNetwork == CardNetwork.rupay).toList();
          if (rupayCards.isNotEmpty) {
            _selectedCreditCardId = rupayCards.first.id;
            _selectedAccountId = null;
            _selectedPaymentSource = 'UPI (${rupayCards.first.cardName})';
          } else {
            _selectedAccountId = null;
            _selectedCreditCardId = null;
            _selectedPaymentSource = 'UPI / Wallet';
          }
        }
        break;
      case PaymentMode.cash:
        final cashAccounts = bankAccounts.where((a) => a.accountType == AccountType.cash).toList();
        if (cashAccounts.isNotEmpty) {
          _selectedAccountId = cashAccounts.first.id;
          _selectedCreditCardId = null;
          _selectedPaymentSource = cashAccounts.first.accountName;
        } else {
          _selectedAccountId = null;
          _selectedCreditCardId = null;
          _selectedPaymentSource = 'Cash';
        }
        break;
    }
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
      accountId: _selectedAccountId,
      creditCardId: _selectedCreditCardId,
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

  Widget _buildModeChip(PaymentMode mode, String label, IconData icon) {
    final isSelected = _selectedPaymentMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final financialColors = context.financialColors;

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : financialColors.textMuted,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        ),
      ),
      selected: isSelected,
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
      side: BorderSide(
        color: isSelected ? Theme.of(context).colorScheme.primary : financialColors.cardBorder,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPaymentMode = mode;
            final bankAccounts = ref.read(activeBankAccountsProvider);
            final creditCards = ref.read(activeCreditCardsProvider);
            _autoSelectLinkedSource(mode, bankAccounts, creditCards);
          });
        }
      },
    );
  }

  Widget _buildLinkedSourceDropdown(
    BuildContext context,
    List<BankAccountEntity> bankAccounts,
    List<CreditCardEntity> creditCards,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    switch (_selectedPaymentMode) {
      case PaymentMode.bankAccount:
        if (bankAccounts.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: financialColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No bank accounts configured. Will record as general Bank Account.',
                    style: TextStyle(fontSize: 12, color: financialColors.textMuted),
                  ),
                ),
              ],
            ),
          );
        }

        final currentValid = bankAccounts.any((a) => a.id == _selectedAccountId);
        final initialVal = currentValid ? _selectedAccountId : bankAccounts.first.id;

        return DropdownButtonFormField<String>(
          initialValue: initialVal,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.account_balance_rounded, size: 18),
          ),
          items: bankAccounts.map((acc) {
            return DropdownMenuItem<String>(
              value: acc.id,
              child: Text(
                '${acc.accountName} [${acc.usedFor}] (${CurrencyFormatter.format(acc.currentBalance)})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (accId) {
            if (accId == null) return;
            setState(() {
              _selectedAccountId = accId;
              _selectedCreditCardId = null;
              final acc = bankAccounts.firstWhere((a) => a.id == accId);
              _selectedPaymentSource = acc.accountName;
            });
          },
        );

      case PaymentMode.creditCard:
        if (creditCards.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: financialColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.credit_card_off_rounded, size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No credit cards added. Will record as general Credit Card.',
                    style: TextStyle(fontSize: 12, color: financialColors.textMuted),
                  ),
                ),
              ],
            ),
          );
        }

        final currentValid = creditCards.any((c) => c.id == _selectedCreditCardId);
        final initialVal = currentValid ? _selectedCreditCardId : creditCards.first.id;

        return DropdownButtonFormField<String>(
          initialValue: initialVal,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.credit_card_rounded, size: 18),
          ),
          items: creditCards.map((card) {
            return DropdownMenuItem<String>(
              value: card.id,
              child: Text(
                '💳 ${card.cardName} (${card.bankName}) • Avail: ${CurrencyFormatter.format(card.availableLimit)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (cardId) {
            if (cardId == null) return;
            setState(() {
              _selectedCreditCardId = cardId;
              _selectedAccountId = null;
              final card = creditCards.firstWhere((c) => c.id == cardId);
              _selectedPaymentSource = card.cardName;
            });
          },
        );

      case PaymentMode.upiWallet:
        final rupayCards = creditCards.where((c) => c.cardNetwork == CardNetwork.rupay).toList();
        if (bankAccounts.isEmpty && rupayCards.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: financialColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No bank accounts or RuPay cards added. Will record as UPI / Wallet.',
                    style: TextStyle(fontSize: 12, color: financialColors.textMuted),
                  ),
                ),
              ],
            ),
          );
        }

        final upiKey = _selectedCreditCardId != null
            ? 'card_$_selectedCreditCardId'
            : (_selectedAccountId != null ? 'acc_$_selectedAccountId' : null);

        return DropdownButtonFormField<String>(
          initialValue: upiKey,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.qr_code_scanner_rounded, size: 18),
          ),
          items: [
            ...bankAccounts.map((acc) => DropdownMenuItem(
                  value: 'acc_${acc.id}',
                  child: Text(
                    '🏦 ${acc.accountName} (Bank UPI)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
            ...rupayCards.map((card) => DropdownMenuItem(
                  value: 'card_${card.id}',
                  child: Text(
                    '💳 ${card.cardName} (RuPay Credit UPI)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              if (val.startsWith('acc_')) {
                _selectedAccountId = val.substring(4);
                _selectedCreditCardId = null;
                final acc = bankAccounts.firstWhere((a) => a.id == _selectedAccountId);
                _selectedPaymentSource = 'UPI (${acc.accountName})';
              } else if (val.startsWith('card_')) {
                _selectedCreditCardId = val.substring(5);
                _selectedAccountId = null;
                final card = creditCards.firstWhere((c) => c.id == _selectedCreditCardId);
                _selectedPaymentSource = 'UPI (${card.cardName})';
              }
            });
          },
        );

      case PaymentMode.cash:
        final cashAccounts = bankAccounts.where((a) => a.accountType == AccountType.cash).toList();
        if (cashAccounts.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: financialColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.payments_rounded, size: 18, color: AppColors.savings),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recording as Physical Cash wallet.',
                    style: TextStyle(fontSize: 12, color: financialColors.textMuted),
                  ),
                ),
              ],
            ),
          );
        }

        final currentValid = cashAccounts.any((a) => a.id == _selectedAccountId);
        final initialVal = currentValid ? _selectedAccountId : cashAccounts.first.id;

        return DropdownButtonFormField<String>(
          initialValue: initialVal,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.payments_rounded, size: 18),
          ),
          items: cashAccounts.map((acc) {
            return DropdownMenuItem<String>(
              value: acc.id,
              child: Text(
                '💵 ${acc.accountName} (${CurrencyFormatter.format(acc.currentBalance)})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (accId) {
            if (accId == null) return;
            setState(() {
              _selectedAccountId = accId;
              _selectedCreditCardId = null;
              final acc = cashAccounts.firstWhere((a) => a.id == accId);
              _selectedPaymentSource = acc.accountName;
            });
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;
    final categories = CategoryConstants.expenseCategories;

    final bankAccounts = ref.watch(activeBankAccountsProvider);
    final creditCards = ref.watch(activeCreditCardsProvider);

    if (_selectedAccountId == null &&
        _selectedCreditCardId == null &&
        (bankAccounts.isNotEmpty || creditCards.isNotEmpty)) {
      _autoSelectLinkedSource(_selectedPaymentMode, bankAccounts, creditCards);
    }

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
                    Flexible(
                      child: Text(
                        _isEditMode ? 'Edit Recurring Expense' : 'New Recurring Expense',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                  height: 94,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final item = categories[index];
                      final isSelected = _selectedCategory == item.name;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedCategory = item.name;
                            if (_selectedPaymentMode == PaymentMode.bankAccount ||
                                _selectedPaymentMode == PaymentMode.upiWallet) {
                              _autoSelectLinkedSource(_selectedPaymentMode, bankAccounts, creditCards);
                            }
                          });
                        },
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
                            mainAxisSize: MainAxisSize.min,
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
                // Next Due Date
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: financialColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_rounded, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            DateFormat('EEEE, dd MMMM yyyy').format(_nextDueDate),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.calendar_month_outlined, size: 18, color: financialColors.textMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Pay Via (Payment Mode)
                Text(
                  'PAY FROM (MODE)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildModeChip(PaymentMode.bankAccount, 'Bank Account', Icons.account_balance_rounded),
                      const SizedBox(width: 8),
                      _buildModeChip(PaymentMode.creditCard, 'Credit Card', Icons.credit_card_rounded),
                      const SizedBox(width: 8),
                      _buildModeChip(PaymentMode.upiWallet, 'UPI / Wallet', Icons.qr_code_scanner_rounded),
                      const SizedBox(width: 8),
                      _buildModeChip(PaymentMode.cash, 'Cash', Icons.payments_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Account / Card Selector
                Text(
                  _selectedPaymentMode == PaymentMode.creditCard
                      ? 'SELECT CREDIT CARD'
                      : _selectedPaymentMode == PaymentMode.bankAccount
                          ? 'SELECT BANK ACCOUNT'
                          : _selectedPaymentMode == PaymentMode.upiWallet
                              ? 'SELECT UPI LINK'
                              : 'SELECT CASH WALLET',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                _buildLinkedSourceDropdown(context, bankAccounts, creditCards, isDark, financialColors),
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
    ),
  );
}
}
