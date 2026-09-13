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
import '../../../../core/domain/entities/split_person_share.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/services/saved_friends_service.dart';
import '../../../../core/utilities/app_haptics.dart';
import '../../../../core/utilities/category_matcher.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../../core/utilities/loan_share_helper.dart';
import '../../../../core/utilities/math_expression_parser.dart';
import '../../../../core/utilities/split_helper.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
import '../state/transactions_provider.dart';
import '../widgets/amount_calculator_field.dart';
import '../widgets/transaction_type_toggle.dart';

class _PersonSplitEntry {
  final TextEditingController nameController;
  final TextEditingController amountController;

  _PersonSplitEntry({String name = '', String amount = ''})
      : nameController = TextEditingController(text: name),
        amountController = TextEditingController(text: amount);

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

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

  // Shared / Split expense tracking
  bool _isShared = false;
  late TextEditingController _myShareController;
  late TextEditingController _sharedWithController;
  List<_PersonSplitEntry> _personSplits = [];

  // Income Expense Share / Reimbursement tracking
  bool _isIncomeReimbursement = false;
  TransactionEntity? _selectedSharedExpenseToSettle;

  // Money Lent to Friends / Relatives
  late TextEditingController _borrowerNameController;
  late TextEditingController _loanInterestController;
  DateTime? _expectedReturnDate;
  bool _isInterestPercentage = false;

  late String _selectedCategory;
  late PaymentMode _selectedPaymentMode;
  String? _selectedAccountId;
  String? _selectedToAccountId;
  String? _selectedCreditCardId;
  late String _selectedPaymentSource;
  String? _autoSelectedReason;
  late DateTime _selectedDate;
  bool _userManuallySelectedAccount = false;

  final _formKey = GlobalKey<FormState>();

  bool get _isEditMode => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.initialTransaction;
    _userManuallySelectedAccount = tx != null;

    _selectedType = tx?.type ?? widget.initialType;

    final categories = _selectedType == TransactionType.income
        ? CategoryConstants.incomeCategories
        : CategoryConstants.expenseCategories;

    _selectedCategory = tx?.category ?? categories.first.name;
    _isIncomeReimbursement = _selectedCategory == 'Shared Expense Reimbursement';
    _titleController = TextEditingController(text: tx?.title ?? _selectedCategory);
    _titleController.addListener(_onTitleChanged);
    _amountController = TextEditingController(
      text: tx != null ? (tx.amount == tx.amount.roundToDouble() ? tx.amount.toInt().toString() : tx.amount.toString()) : '',
    );
    _notesController = TextEditingController(text: tx?.notes ?? '');
    _selectedPaymentSource = tx?.paymentSource ?? 'Bank Account';
    _selectedAccountId = tx?.accountId;
    _selectedToAccountId = tx?.toAccountId;
    _selectedCreditCardId = tx?.creditCardId;
    _selectedDate = tx?.date ?? DateTime.now();

    _isShared = tx?.isShared ?? false;
    _myShareController = TextEditingController(
      text: tx?.myShareAmount != null
          ? (tx!.myShareAmount == tx.myShareAmount!.roundToDouble()
              ? tx.myShareAmount!.toInt().toString()
              : tx.myShareAmount!.toString())
          : '',
    );
    _sharedWithController = TextEditingController(text: tx?.sharedWith ?? '');

    // Parse structured per-person shares if present
    final parsedShares = SplitHelper.parseShares(tx?.sharedWith);
    if (parsedShares.isNotEmpty) {
      _personSplits = parsedShares.map((s) {
        final amtStr = s.amount == s.amount.roundToDouble()
            ? s.amount.toInt().toString()
            : s.amount.toStringAsFixed(2);
        return _PersonSplitEntry(name: s.personName, amount: amtStr);
      }).toList();
    }

    // Parse structured personal loan / money lent if present
    final parsedLoan = LoanShareHelper.parseLoan(tx?.sharedWith);
    _borrowerNameController = TextEditingController(text: parsedLoan?.borrowerName ?? '');
    _loanInterestController = TextEditingController(
      text: parsedLoan != null && parsedLoan.expectedInterest > 0
          ? (parsedLoan.interestRate != null
              ? (parsedLoan.interestRate == parsedLoan.interestRate!.roundToDouble()
                  ? parsedLoan.interestRate!.toInt().toString()
                  : parsedLoan.interestRate.toString())
              : (parsedLoan.expectedInterest == parsedLoan.expectedInterest.roundToDouble()
                  ? parsedLoan.expectedInterest.toInt().toString()
                  : parsedLoan.expectedInterest.toString()))
          : '',
    );
    _isInterestPercentage = parsedLoan?.interestRate != null;
    _expectedReturnDate = parsedLoan?.expectedReturnDate;

    if (tx != null) {
      _selectedPaymentMode = PaymentMode.fromString(tx.paymentSource);
      if (tx.accountId != null) {
        if (_selectedPaymentMode != PaymentMode.upiWallet &&
            _selectedPaymentMode != PaymentMode.cash) {
          _selectedPaymentMode = PaymentMode.bankAccount;
        }
      } else if (tx.creditCardId != null && _selectedPaymentMode != PaymentMode.upiWallet) {
        _selectedPaymentMode = PaymentMode.creditCard;
      }
    } else {
      _selectedPaymentMode = PaymentMode.bankAccount;
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _myShareController.dispose();
    _sharedWithController.dispose();
    _borrowerNameController.dispose();
    _loanInterestController.dispose();
    for (final p in _personSplits) {
      p.dispose();
    }
    super.dispose();
  }

  void _onTitleChanged() {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) {
      final detected = CategoryMatcher.detectCategory(title);
      if (detected != null && detected != _selectedCategory) {
        final categories = _selectedType == TransactionType.income
            ? CategoryConstants.incomeCategories
            : CategoryConstants.expenseCategories;
        if (categories.any((c) => c.name.toLowerCase() == detected.toLowerCase())) {
          final matched = categories.firstWhere((c) => c.name.toLowerCase() == detected.toLowerCase());
          setState(() {
            _selectedCategory = matched.name;
            final bankAccounts = ref.read(activeBankAccountsProvider);
            final defaultAcc = ref.read(defaultBankAccountProvider);
            if (!_userManuallySelectedAccount &&
                (_selectedPaymentMode == PaymentMode.bankAccount ||
                (_selectedPaymentMode == PaymentMode.upiWallet && _selectedCreditCardId == null))) {
              final acc = AccountPurposeTags.matchAccountForCategory(
                matched.name,
                bankAccounts,
                defaultAccount: defaultAcc,
              );
              if (acc != null) {
                _selectedAccountId = acc.id;
                if (_selectedPaymentMode == PaymentMode.upiWallet) {
                  _selectedPaymentSource = 'UPI (${acc.accountName})';
                } else {
                  _selectedPaymentSource = acc.accountName;
                }
                _autoSelectedReason = '${acc.accountName} (${acc.usedFor})';
              }
            }
          });
        }
      }
    }
  }

  void _onTypeChanged(TransactionType newType) {
    if (_selectedType == newType) return;
    HapticFeedback.selectionClick();
    setState(() {
      final oldCategories = _selectedType == TransactionType.income
          ? CategoryConstants.incomeCategories
          : (_selectedType == TransactionType.expense
              ? CategoryConstants.expenseCategories
              : const <CategoryItem>[]);

      _selectedType = newType;

      if (newType == TransactionType.transfer) {
        _selectedCategory = 'Account Transfer';
        _selectedPaymentMode = PaymentMode.bankAccount;
        final bankAccounts = ref.read(activeBankAccountsProvider);
        if (_selectedAccountId == null && bankAccounts.isNotEmpty) {
          _selectedAccountId = bankAccounts.first.id;
          _selectedPaymentSource = bankAccounts.first.accountName;
        }
        if (_selectedToAccountId == null && bankAccounts.length > 1) {
          _selectedToAccountId = bankAccounts.firstWhere(
            (a) => a.id != _selectedAccountId,
            orElse: () => bankAccounts.last,
          ).id;
        }
        final currentTitle = _titleController.text.trim();
        final oldCategoryNames = oldCategories.map((c) => c.name.toLowerCase()).toSet();
        if (currentTitle.isEmpty || oldCategoryNames.contains(currentTitle.toLowerCase()) || currentTitle == 'Expense' || currentTitle == 'Income') {
          _titleController.text = 'Account Transfer';
        }
      } else {
        final newCategories = newType == TransactionType.income
            ? CategoryConstants.incomeCategories
            : CategoryConstants.expenseCategories;
        _selectedCategory = newCategories.first.name;

        final currentTitle = _titleController.text.trim();
        final oldCategoryNames = oldCategories.map((c) => c.name.toLowerCase()).toSet();

        // If title is empty, or equals any of the previous type's category names,
        // update to the new category name so old category titles are never carried over across tabs.
        if (currentTitle.isEmpty || oldCategoryNames.contains(currentTitle.toLowerCase()) || currentTitle == 'Account Transfer') {
          _titleController.text = _selectedCategory;
        }
      }
    });
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
          _autoSelectedReason = '${acc.accountName} (${acc.usedFor})';
        } else {
          _selectedAccountId = null;
          _selectedCreditCardId = null;
          _selectedPaymentSource = 'Bank Account';
          _autoSelectedReason = null;
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
          _autoSelectedReason = '${acc.accountName} (${acc.usedFor})';
        } else {
          final rupayCards = creditCards.where((c) => c.cardNetwork == CardNetwork.rupay).toList();
          if (rupayCards.isNotEmpty) {
            _selectedCreditCardId = rupayCards.first.id;
            _selectedAccountId = null;
            _selectedPaymentSource = 'UPI (${rupayCards.first.cardName})';
            _autoSelectedReason = null;
          } else {
            _selectedAccountId = null;
            _selectedCreditCardId = null;
            _selectedPaymentSource = 'UPI / Wallet';
            _autoSelectedReason = null;
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

  double _calculateExpectedInterest(double principal) {
    final raw = double.tryParse(_loanInterestController.text.trim()) ?? 0.0;
    if (raw <= 0 || principal <= 0) return 0.0;
    if (_isInterestPercentage) {
      return (principal * raw) / 100.0;
    }
    return raw;
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
    if (!_formKey.currentState!.validate()) {
      AppHaptics.warning();
      return;
    }

    final amount = MathExpressionParser.tryEvaluate(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      AppHaptics.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive amount or expression.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      AppHaptics.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter title or reason.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedType == TransactionType.expense &&
        _selectedCategory == 'Money Lent / Helping Friend') {
      final borrower = _borrowerNameController.text.trim();
      if (borrower.isEmpty) {
        AppHaptics.warning();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter friend or relative\'s name for money lent.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (_selectedType == TransactionType.transfer) {
      final bankAccounts = ref.read(activeBankAccountsProvider);
      if (_selectedAccountId == null && bankAccounts.isNotEmpty) {
        _selectedAccountId = bankAccounts.first.id;
        _selectedPaymentSource = bankAccounts.first.accountName;
      }
      if (_selectedToAccountId == null && bankAccounts.length > 1) {
        _selectedToAccountId = bankAccounts.firstWhere(
          (a) => a.id != _selectedAccountId,
          orElse: () => bankAccounts.last,
        ).id;
      }
      if (_selectedAccountId == null || _selectedToAccountId == null) {
        AppHaptics.warning();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select both source and destination accounts.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (_selectedAccountId == _selectedToAccountId) {
        AppHaptics.warning();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Source and destination accounts must be different.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final now = DateTime.now();

    if (_isEditMode) {
      final prevTx = widget.initialTransaction!;

      // 1. Revert previous transaction impact
      if (prevTx.type == TransactionType.income) {
        if (prevTx.accountId != null) {
          await ref
              .read(bankAccountListProvider.notifier)
              .adjustAccountBalance(prevTx.accountId!, -prevTx.amount);
        } else if (prevTx.creditCardId != null) {
          await ref
              .read(creditCardListProvider.notifier)
              .adjustUsedAmount(prevTx.creditCardId!, prevTx.amount);
        }
      } else if (prevTx.type == TransactionType.expense) {
        if (prevTx.creditCardId != null) {
          await ref
              .read(creditCardListProvider.notifier)
              .adjustUsedAmount(prevTx.creditCardId!, -prevTx.amount);
        } else if (prevTx.accountId != null) {
          await ref
              .read(bankAccountListProvider.notifier)
              .adjustAccountBalance(prevTx.accountId!, prevTx.amount);
        }
      } else if (prevTx.type == TransactionType.transfer) {
        if (prevTx.accountId != null) {
          await ref
              .read(bankAccountListProvider.notifier)
              .adjustAccountBalance(prevTx.accountId!, prevTx.amount);
        }
        if (prevTx.toAccountId != null) {
          await ref
              .read(bankAccountListProvider.notifier)
              .adjustAccountBalance(prevTx.toAccountId!, -prevTx.amount);
        } else if (prevTx.creditCardId != null) {
          await ref
              .read(creditCardListProvider.notifier)
              .adjustUsedAmount(prevTx.creditCardId!, prevTx.amount);
        }
      }

      // 2. Apply new transaction impact
      if (_selectedType == TransactionType.income) {
        if (_selectedAccountId != null) {
          await ref
              .read(bankAccountListProvider.notifier)
              .adjustAccountBalance(_selectedAccountId!, amount);
        } else if (_selectedCreditCardId != null) {
          await ref
              .read(creditCardListProvider.notifier)
              .adjustUsedAmount(_selectedCreditCardId!, -amount);
        }
      } else if (_selectedType == TransactionType.expense) {
        if (_selectedCreditCardId != null) {
          await ref
              .read(creditCardListProvider.notifier)
              .adjustUsedAmount(_selectedCreditCardId!, amount);
        } else if (_selectedAccountId != null) {
          await ref
              .read(bankAccountListProvider.notifier)
              .adjustAccountBalance(_selectedAccountId!, -amount);
        }
      } else if (_selectedType == TransactionType.transfer) {
        if (_selectedAccountId != null) {
          await ref
              .read(bankAccountListProvider.notifier)
              .adjustAccountBalance(_selectedAccountId!, -amount);
        }
        if (_selectedToAccountId != null) {
          await ref
              .read(bankAccountListProvider.notifier)
              .adjustAccountBalance(_selectedToAccountId!, amount);
        } else if (_selectedCreditCardId != null) {
          await ref
              .read(creditCardListProvider.notifier)
              .adjustUsedAmount(_selectedCreditCardId!, -amount);
        }
      }

      final isExpense = _selectedType == TransactionType.expense;
      final isMoneyLent = isExpense && _selectedCategory == 'Money Lent / Helping Friend';
      final isSharedExpense = isExpense && (_isShared || isMoneyLent);
      double? myShare;
      String? sharedWith;
      bool isSettled = false;

      if (isMoneyLent) {
        final borrower = _borrowerNameController.text.trim();
        final expectedInterest = _calculateExpectedInterest(amount);
        final rate = _isInterestPercentage ? double.tryParse(_loanInterestController.text.trim()) : null;
        final prevLoan = LoanShareHelper.parseLoan(prevTx.sharedWith);

        final loanData = LoanShareData(
          borrowerName: borrower.isNotEmpty ? borrower : 'Friend',
          principalAmount: amount,
          expectedInterest: expectedInterest,
          interestRate: rate,
          expectedReturnDate: _expectedReturnDate,
          repaidAmount: prevLoan?.repaidAmount ?? prevTx.reimbursedAmount,
          isRepaid: prevLoan?.isRepaid ?? prevTx.isSettled,
          paymentSource: _selectedPaymentSource,
        );

        sharedWith = LoanShareHelper.encodeLoan(loanData);
        myShare = 0.0;
        isSettled = loanData.isRepaid;
        if (borrower.isNotEmpty) {
          ref.read(savedFriendsProvider.notifier).addFriend(borrower);
        }
      } else if (isSharedExpense) {
        final parsedShare = MathExpressionParser.tryEvaluate(_myShareController.text.trim());
        myShare = (parsedShare != null && parsedShare >= 0 && parsedShare <= amount)
            ? parsedShare
            : (amount / 2);

        final existingParsed = SplitHelper.parseShares(prevTx.sharedWith);
        final validShares = _personSplits
            .where((p) => p.nameController.text.trim().isNotEmpty)
            .map((p) {
              final name = p.nameController.text.trim();
              final amt = double.tryParse(p.amountController.text.trim()) ?? 0.0;
              final existing = existingParsed
                  .where((e) => e.personName.trim().toLowerCase() == name.toLowerCase())
                  .firstOrNull;
              final reimbursed = existing != null ? existing.reimbursedAmount : 0.0;
              final isSettled = existing != null ? (existing.isSettled || (reimbursed >= amt && amt > 0)) : false;
              return SplitPersonShare(
                personName: name,
                amount: amt,
                reimbursedAmount: reimbursed,
                isSettled: isSettled,
              );
            })
            .where((s) => s.amount > 0)
            .toList();

        if (validShares.isNotEmpty) {
          sharedWith = SplitHelper.encodeShares(validShares);
          for (final s in validShares) {
            ref.read(savedFriendsProvider.notifier).addFriend(s.personName);
          }
        } else {
          final rawNames = _sharedWithController.text.trim();
          sharedWith = rawNames.isNotEmpty ? rawNames : null;
        }
        isSettled = prevTx.reimbursedAmount >= (amount - myShare);
      }

      final friendShare = isSharedExpense ? (amount - (myShare ?? 0.0)).clamp(0.0, amount) : 0.0;
      final updated = prevTx.copyWith(
        title: title,
        amount: amount,
        type: _selectedType,
        category: _selectedCategory,
        date: _selectedDate,
        paymentSource: _selectedPaymentSource,
        accountId: _selectedAccountId,
        toAccountId: _selectedType == TransactionType.transfer ? _selectedToAccountId : null,
        creditCardId: _selectedCreditCardId,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        isShared: isSharedExpense,
        myShareAmount: isSharedExpense ? myShare : null,
        sharedWith: isSharedExpense ? sharedWith : null,
        reimbursedAmount: isSharedExpense
            ? prevTx.reimbursedAmount.clamp(0.0, friendShare)
            : 0.0,
        isSettled: isSettled,
        updatedAt: now,
      );

      await ref
          .read(transactionListNotifierProvider.notifier)
          .updateTransaction(updated);

      AppHaptics.success();

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
      // If logging income as reimbursement payback for a shared expense
      if (_selectedType == TransactionType.income &&
          _isIncomeReimbursement &&
          _selectedSharedExpenseToSettle != null) {
        final bankAccounts = ref.read(activeBankAccountsProvider);
        final destAccountId = _selectedAccountId ?? (bankAccounts.isNotEmpty ? bankAccounts.first.id : null);
        if (destAccountId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a receiving bank account.')),
          );
          return;
        }

        await ref.read(transactionListNotifierProvider.notifier).settleSharedExpense(
              transactionId: _selectedSharedExpenseToSettle!.id,
              amountReceived: amount,
              destinationAccountId: destAccountId,
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            );

        AppHaptics.success();
        if (mounted) {
          Navigator.of(context).pop();
          final origCardId = _selectedSharedExpenseToSettle!.creditCardId;
          final isCreditCard = origCardId != null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Recorded ${CurrencyFormatter.format(amount)} reimbursement for "${_selectedSharedExpenseToSettle!.title}".'
                '${isCreditCard ? " Deposited to bank and earmarked for credit card bill." : ""}',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Apply new transaction balance impact
      if (_selectedType == TransactionType.income) {
        if (_selectedAccountId != null) {
          await ref
              .read(bankAccountListProvider.notifier)
              .adjustAccountBalance(_selectedAccountId!, amount);
        } else if (_selectedCreditCardId != null) {
          await ref
              .read(creditCardListProvider.notifier)
              .adjustUsedAmount(_selectedCreditCardId!, -amount);
        }
      } else if (_selectedType == TransactionType.expense) {
        if (_selectedCreditCardId != null) {
          await ref
              .read(creditCardListProvider.notifier)
              .adjustUsedAmount(_selectedCreditCardId!, amount);
        } else if (_selectedAccountId != null) {
          await ref
              .read(bankAccountListProvider.notifier)
              .adjustAccountBalance(_selectedAccountId!, -amount);
        }
      } else if (_selectedType == TransactionType.transfer) {
        if (_selectedAccountId != null) {
          await ref
              .read(bankAccountListProvider.notifier)
              .adjustAccountBalance(_selectedAccountId!, -amount);
        }
        if (_selectedToAccountId != null) {
          await ref
              .read(bankAccountListProvider.notifier)
              .adjustAccountBalance(_selectedToAccountId!, amount);
        }
        if (_selectedCreditCardId != null) {
          await ref
              .read(creditCardListProvider.notifier)
              .adjustUsedAmount(_selectedCreditCardId!, -amount);
        }
      }

      final isExpense = _selectedType == TransactionType.expense;
      final isMoneyLent = isExpense && _selectedCategory == 'Money Lent / Helping Friend';
      final isSharedExpense = isExpense && (_isShared || isMoneyLent);
      double? myShare;
      String? sharedWith;
      if (isMoneyLent) {
        final borrower = _borrowerNameController.text.trim();
        final expectedInterest = _calculateExpectedInterest(amount);
        final rate = _isInterestPercentage ? double.tryParse(_loanInterestController.text.trim()) : null;

        final loanData = LoanShareData(
          borrowerName: borrower.isNotEmpty ? borrower : 'Friend',
          principalAmount: amount,
          expectedInterest: expectedInterest,
          interestRate: rate,
          expectedReturnDate: _expectedReturnDate,
          paymentSource: _selectedPaymentSource,
        );

        sharedWith = LoanShareHelper.encodeLoan(loanData);
        myShare = 0.0;
        if (borrower.isNotEmpty) {
          ref.read(savedFriendsProvider.notifier).addFriend(borrower);
        }
      } else if (isSharedExpense) {
        final parsedShare = MathExpressionParser.tryEvaluate(_myShareController.text.trim());
        myShare = (parsedShare != null && parsedShare >= 0 && parsedShare <= amount)
            ? parsedShare
            : (amount / 2);

        final validShares = _personSplits
            .where((p) => p.nameController.text.trim().isNotEmpty)
            .map((p) {
              final name = p.nameController.text.trim();
              final amt = double.tryParse(p.amountController.text.trim()) ?? 0.0;
              return SplitPersonShare(personName: name, amount: amt);
            })
            .where((s) => s.amount > 0)
            .toList();

        if (validShares.isNotEmpty) {
          sharedWith = SplitHelper.encodeShares(validShares);
          for (final s in validShares) {
            ref.read(savedFriendsProvider.notifier).addFriend(s.personName);
          }
        } else {
          final rawNames = _sharedWithController.text.trim();
          sharedWith = rawNames.isNotEmpty ? rawNames : null;
        }
      }

      final newTx = TransactionEntity(
        id: const Uuid().v4(),
        title: title,
        amount: amount,
        type: _selectedType,
        category: _selectedCategory,
        date: _selectedDate,
        paymentSource: _selectedPaymentSource,
        accountId: _selectedAccountId,
        toAccountId: _selectedType == TransactionType.transfer ? _selectedToAccountId : null,
        creditCardId: _selectedCreditCardId,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        isShared: isSharedExpense,
        myShareAmount: isSharedExpense ? myShare : null,
        sharedWith: isSharedExpense ? sharedWith : null,
        reimbursedAmount: 0.0,
        isSettled: false,
        createdAt: now,
        updatedAt: now,
      );

      await ref
          .read(transactionListNotifierProvider.notifier)
          .addTransaction(newTx);

      AppHaptics.success();

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
            style: FilledButton.styleFrom(
              backgroundColor: context.financialColors.expense,
            ),
            onPressed: () {
              AppHaptics.deleteAction();
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final tx = widget.initialTransaction!;
      await ref
          .read(transactionListNotifierProvider.notifier)
          .deleteTransaction(tx.id);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${tx.title}" successfully.'),
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

    final bankAccounts = ref.watch(activeBankAccountsProvider);
    final creditCards = ref.watch(activeCreditCardsProvider);
    final defaultAcc = ref.watch(defaultBankAccountProvider);

    if (_selectedPaymentMode == PaymentMode.bankAccount ||
        (_selectedPaymentMode == PaymentMode.upiWallet && _selectedCreditCardId == null)) {
      if (_selectedAccountId == null && _selectedCreditCardId == null) {
        if (bankAccounts.isNotEmpty) {
          final matched = AccountPurposeTags.matchAccountForCategory(
            _selectedCategory,
            bankAccounts,
            defaultAccount: defaultAcc,
          );
          final def = matched ?? (defaultAcc ?? bankAccounts.first);
          _selectedAccountId = def.id;
          _selectedPaymentSource = def.accountName;
          _autoSelectedReason = '${def.accountName} (${def.usedFor})';
        }
      }
    }

    final isIncome = _selectedType == TransactionType.income;
    final isTransfer = _selectedType == TransactionType.transfer;
    final activeAccentColor = isTransfer
        ? AppColors.primaryEmerald
        : (isIncome ? financialColors.income : financialColors.expense);
    final categories = isIncome
        ? CategoryConstants.incomeCategories
        : (isTransfer ? const <CategoryItem>[] : CategoryConstants.expenseCategories);

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

                // Header & Mode Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        _isEditMode ? 'Edit Transaction' : 'New Transaction',
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
                        onPressed: _deleteTransaction,
                        tooltip: 'Delete',
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Type Toggle (Expense / Income / Transfer)
                TransactionTypeToggle(
                  selectedType: _selectedType,
                  onTypeChanged: _onTypeChanged,
                ),
                const SizedBox(height: 20),

                // Amount Field
                AmountCalculatorField(
                  controller: _amountController,
                  activeAccentColor: activeAccentColor,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter amount';
                    }
                    if (double.tryParse(value) == null && MathExpressionParser.tryEvaluate(value) == null) {
                      return 'Invalid number';
                    }
                    return null;
                  },
                  onChanged: (val) {
                    if (_isShared || _isIncomeReimbursement) {
                      setState(() {});
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Description / Title Field (Mandatory)
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
                  decoration: const InputDecoration(
                    hintText: 'e.g. Lunch at Cafe, Grocery Mart, Salary',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter title or reason';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                if (_selectedType == TransactionType.transfer) ...[
                  _buildTransferSection(theme, bankAccounts, isDark, financialColors),
                ] else ...[
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
                              final oldCategory = _selectedCategory;
                              _selectedCategory = item.name;
                              if (item.name == 'Shared Expense Reimbursement') {
                                _isIncomeReimbursement = true;
                              }

                              final currentTitle = _titleController.text.trim();
                              final allCategoryNames = {
                                ...CategoryConstants.expenseCategories.map((c) => c.name.toLowerCase()),
                                ...CategoryConstants.incomeCategories.map((c) => c.name.toLowerCase()),
                              };

                              if (item.name == 'Money Lent / Helping Friend') {
                                final borrower = _borrowerNameController.text.trim();
                                _titleController.text = borrower.isNotEmpty ? 'Money Lent to $borrower' : 'Money Lent to Friend';
                              } else if (currentTitle.isEmpty ||
                                  currentTitle.toLowerCase() == oldCategory.toLowerCase() ||
                                  allCategoryNames.contains(currentTitle.toLowerCase())) {
                                _titleController.text = item.name;
                              }

                              // Smart category-based account defaulting
                              if (!_userManuallySelectedAccount &&
                                  (_selectedPaymentMode == PaymentMode.bankAccount ||
                                  (_selectedPaymentMode == PaymentMode.upiWallet && _selectedCreditCardId == null))) {
                                final matched = AccountPurposeTags.matchAccountForCategory(
                                  item.name,
                                  bankAccounts,
                                  defaultAccount: defaultAcc,
                                );
                                if (matched != null) {
                                  _selectedAccountId = matched.id;
                                  if (_selectedPaymentMode == PaymentMode.upiWallet) {
                                    _selectedPaymentSource = 'UPI (${matched.accountName})';
                                  } else {
                                    _selectedPaymentSource = matched.accountName;
                                  }
                                  _autoSelectedReason = '${matched.accountName} (${matched.usedFor})';
                                }
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

                  // TWO-TIER PAYMENT SELECTION
                  // Tier 1: Method (PAY FROM / DEPOSIT TO)
                  Text(
                    isIncome ? 'DEPOSIT TO (METHOD)' : 'PAY FROM (METHOD)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<PaymentMode>(
                    initialValue: _selectedPaymentMode,
                    isExpanded: true,
                    decoration: InputDecoration(
                      prefixIcon: Icon(_selectedPaymentMode.icon, size: 20),
                    ),
                    items: PaymentMode.values.map((mode) {
                      return DropdownMenuItem<PaymentMode>(
                        value: mode,
                        child: Text(
                          mode.displayName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (mode) {
                      if (mode == null) return;
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedPaymentMode = mode;
                        _autoSelectLinkedSource(mode, bankAccounts, creditCards);
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Tier 2: Specific Linked Source (Bank Account / Card / Stash)
                  Text(
                    _getLinkedSourceLabel(_selectedPaymentMode),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildLinkedSourceDropdown(context, bankAccounts, creditCards, isDark, financialColors),
                  if (_autoSelectedReason != null &&
                      (_selectedPaymentMode == PaymentMode.bankAccount || _selectedPaymentMode == PaymentMode.upiWallet))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 14, color: AppColors.primaryEmerald),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Smart auto-selected: $_autoSelectedReason',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryEmerald,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!isIncome && _selectedCategory == 'Money Lent / Helping Friend')
                    _buildMoneyLentSection(theme, financialColors, isDark)
                  else if (!isIncome)
                    _buildSharedExpenseSection(theme, financialColors, isDark),
                  if (isIncome) _buildIncomeReimbursementSection(theme, financialColors, isDark, creditCards),
                ],
                const SizedBox(height: 20),

                // Date & Time Picker
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: financialColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            DateFormat('dd MMM yyyy, h:mm a').format(_selectedDate),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.access_time_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Quick Date Shortcuts
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_isEditMode && widget.initialTransaction != null) ...[
                        _buildDateShortcutChip(
                          'Original (${DateFormat('dd MMM').format(widget.initialTransaction!.date)})',
                          widget.initialTransaction!.date,
                          theme,
                          isDark,
                          financialColors,
                        ),
                        const SizedBox(width: 8),
                      ],
                      _buildDateShortcutChip('Today', DateTime.now(), theme, isDark, financialColors),
                      const SizedBox(width: 8),
                      _buildDateShortcutChip(
                        'Yesterday',
                        DateTime.now().subtract(const Duration(days: 1)),
                        theme,
                        isDark,
                        financialColors,
                      ),
                      const SizedBox(width: 8),
                      _buildDateShortcutChip(
                        'Day Before',
                        DateTime.now().subtract(const Duration(days: 2)),
                        theme,
                        isDark,
                        financialColors,
                      ),
                    ],
                  ),
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
    ),
  );
}

  String _getLinkedSourceLabel(PaymentMode mode) {
    switch (mode) {
      case PaymentMode.bankAccount:
        return 'SELECT BANK ACCOUNT';
      case PaymentMode.creditCard:
        return 'SELECT CREDIT CARD';
      case PaymentMode.upiWallet:
        return 'LINKED UPI ACCOUNT / RUPAY CARD';
      case PaymentMode.cash:
        return 'SELECT CASH WALLET / STASH';
    }
  }

  Widget _buildTransferSection(
    ThemeData theme,
    List<BankAccountEntity> bankAccounts,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    if (bankAccounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: financialColors.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No active bank accounts available. Please add bank accounts to record transfers.',
                style: TextStyle(fontSize: 13, color: financialColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    final fromValid = bankAccounts.any((a) => a.id == _selectedAccountId);
    final fromVal = fromValid ? _selectedAccountId : bankAccounts.first.id;

    final toValid = bankAccounts.any((a) => a.id == _selectedToAccountId);
    final toVal = toValid
        ? _selectedToAccountId
        : (bankAccounts.length > 1
            ? bankAccounts.firstWhere((a) => a.id != fromVal, orElse: () => bankAccounts.last).id
            : null);

    final isSameAccount = fromVal != null && toVal != null && fromVal == toVal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Source Account
        Text(
          'TRANSFER FROM (SOURCE)',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: financialColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('transfer_from_${fromVal}_$_selectedAccountId'),
          initialValue: fromVal,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.account_balance_rounded, size: 20),
          ),
          items: bankAccounts.map((acc) {
            return DropdownMenuItem<String>(
              value: acc.id,
              child: Text(
                '${acc.accountName} (${CurrencyFormatter.format(acc.currentBalance)})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val == null) return;
            HapticFeedback.selectionClick();
            setState(() {
              _selectedAccountId = val;
              final acc = bankAccounts.firstWhere((a) => a.id == val);
              _selectedPaymentSource = acc.accountName;
            });
          },
        ),
        const SizedBox(height: 12),

        // Transfer Direction Indicator
        Center(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryEmerald.withAlpha(isDark ? 50 : 30),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_downward_rounded,
              size: 20,
              color: AppColors.primaryEmerald,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Destination Account
        Text(
          'TRANSFER TO (DESTINATION)',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: financialColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('transfer_to_${toVal}_$_selectedToAccountId'),
          initialValue: toVal,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.arrow_circle_down_rounded, size: 20),
            errorText: isSameAccount ? 'Source and destination must be different' : null,
          ),
          items: bankAccounts.map((acc) {
            return DropdownMenuItem<String>(
              value: acc.id,
              child: Text(
                '${acc.accountName} (${CurrencyFormatter.format(acc.currentBalance)})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val == null) return;
            HapticFeedback.selectionClick();
            setState(() {
              _selectedToAccountId = val;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDateShortcutChip(
    String label,
    DateTime targetDate,
    ThemeData theme,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    final isSelected = _selectedDate.year == targetDate.year &&
        _selectedDate.month == targetDate.month &&
        _selectedDate.day == targetDate.day;

    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected
          ? AppColors.primaryEmerald.withAlpha(isDark ? 60 : 40)
          : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
      side: BorderSide(
        color: isSelected ? AppColors.primaryEmerald : financialColors.cardBorder,
        width: isSelected ? 1.5 : 1,
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        color: isSelected
            ? (isDark ? AppColors.primaryEmerald : const Color(0xFF047857))
            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedDate = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            _selectedDate.hour,
            _selectedDate.minute,
          );
        });
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
        final selectedVal = currentValid ? _selectedAccountId : (bankAccounts.isNotEmpty ? bankAccounts.first.id : null);

        return DropdownButtonFormField<String>(
          key: ValueKey('bank_acc_$selectedVal'),
          initialValue: selectedVal,
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
              _userManuallySelectedAccount = true;
              _selectedAccountId = accId;
              _selectedCreditCardId = null;
              final acc = bankAccounts.firstWhere((a) => a.id == accId);
              _selectedPaymentSource = acc.accountName;
              _autoSelectedReason = null;
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
        final selectedVal = currentValid ? _selectedCreditCardId : (creditCards.isNotEmpty ? creditCards.first.id : null);

        return DropdownButtonFormField<String>(
          key: ValueKey('card_$selectedVal'),
          initialValue: selectedVal,
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
              _userManuallySelectedAccount = true;
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

        final items = <DropdownMenuItem<String>>[
          ...bankAccounts.map((acc) => DropdownMenuItem<String>(
                value: 'acc_${acc.id}',
                child: Text(
                  '🏦 ${acc.accountName} (${CurrencyFormatter.format(acc.currentBalance)})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              )),
          ...rupayCards.map((card) => DropdownMenuItem<String>(
                value: 'card_${card.id}',
                child: Text(
                  '💳 ${card.cardName} (RuPay UPI) • Avail: ${CurrencyFormatter.format(card.availableLimit)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              )),
        ];

        final isKeyValid = items.any((i) => i.value == upiKey);
        final selectedUpiVal = isKeyValid ? upiKey : (items.isNotEmpty ? items.first.value : null);

        return DropdownButtonFormField<String>(
          key: ValueKey('upi_$selectedUpiVal'),
          initialValue: selectedUpiVal,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.qr_code_scanner_rounded, size: 18),
          ),
          items: items,
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              _userManuallySelectedAccount = true;
              if (val.startsWith('acc_')) {
                final accId = val.substring(4);
                _selectedAccountId = accId;
                _selectedCreditCardId = null;
                final acc = bankAccounts.firstWhere((a) => a.id == accId);
                _selectedPaymentSource = 'UPI (${acc.accountName})';
              } else if (val.startsWith('card_')) {
                final cardId = val.substring(5);
                _selectedCreditCardId = cardId;
                _selectedAccountId = null;
                final card = creditCards.firstWhere((c) => c.id == cardId);
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
                const Icon(Icons.payments_rounded, size: 18, color: AppColors.income),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Physical Cash / Cash in Hand',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
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

  Widget _buildSharedExpenseSection(ThemeData theme, AppFinancialColors financialColors, bool isDark) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final myShare = double.tryParse(_myShareController.text.trim()) ?? (amount / 2);
    final friendsShare = (amount - myShare).clamp(0.0, amount);

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isShared
            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
            : (isDark ? AppColors.darkSurfaceVariant.withAlpha(128) : AppColors.lightSurfaceVariant.withAlpha(128)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isShared
              ? AppColors.primaryEmerald
              : financialColors.cardBorder.withAlpha(128),
          width: _isShared ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isShared
                      ? AppColors.primaryEmerald.withAlpha(38)
                      : (isDark ? Colors.white10 : Colors.black.withAlpha(13)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.group_outlined,
                  size: 20,
                  color: _isShared ? AppColors.primaryEmerald : financialColors.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Split / Shared with Others',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _isShared ? theme.colorScheme.onSurface : financialColors.textMuted,
                      ),
                    ),
                    Text(
                      _isShared
                          ? 'Track roommate & friend paybacks to your bank'
                          : 'Paid for roommates or friends? Split it here',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: financialColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isShared,
                activeThumbColor: AppColors.primaryEmerald,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isShared = val;
                    if (val && _myShareController.text.isEmpty) {
                      final currentAmt = double.tryParse(_amountController.text.trim()) ?? 0;
                      if (currentAmt > 0) {
                        _myShareController.text = (currentAmt / 2).toStringAsFixed(0);
                      }
                    }
                  });
                },
              ),
            ],
          ),
          if (_isShared) ...[
            const Divider(height: 24),
            Text(
              'YOUR TRUE SHARE',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: financialColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _myShareController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Text(CurrencyFormatter.activeCurrency.symbol, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                hintText: 'Your personal cost portion',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            // Quick split shortcuts
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    label: const Text('Split 50/50'),
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    onPressed: () {
                      final amt = double.tryParse(_amountController.text.trim()) ?? 0;
                      setState(() {
                        _myShareController.text = (amt / 2).toStringAsFixed(0);
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    label: const Text('Split 1/3'),
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    onPressed: () {
                      final amt = double.tryParse(_amountController.text.trim()) ?? 0;
                      setState(() {
                        _myShareController.text = (amt / 3).toStringAsFixed(0);
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    label: const Text('Split 1/4'),
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    onPressed: () {
                      final amt = double.tryParse(_amountController.text.trim()) ?? 0;
                      setState(() {
                        _myShareController.text = (amt / 4).toStringAsFixed(0);
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    label: Text('I paid 100% for them (${CurrencyFormatter.activeCurrency.symbol}0 share)'),
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    onPressed: () {
                      setState(() {
                        _myShareController.text = '0';
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'WHO OWES YOU? (ROOMMATES / FRIENDS)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.manage_accounts_outlined, size: 16),
                  label: const Text('Saved Friends', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  onPressed: () => _showManageFriendsDialog(context),
                ),
              ],
            ),
            // Quick-add chips from saved friends
            Consumer(
              builder: (ctx, ref, _) {
                final savedFriends = ref.watch(savedFriendsProvider);
                if (savedFriends.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: savedFriends.map((friend) {
                        final isAlreadyAdded = _personSplits.any(
                          (p) => p.nameController.text.trim().toLowerCase() == friend.toLowerCase(),
                        );
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            avatar: Icon(
                              isAlreadyAdded ? Icons.check_rounded : Icons.add_rounded,
                              size: 14,
                              color: isAlreadyAdded ? AppColors.primaryEmerald : financialColors.textMuted,
                            ),
                            label: Text(friend),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isAlreadyAdded ? AppColors.primaryEmerald : null,
                            ),
                            backgroundColor: isAlreadyAdded
                                ? AppColors.primaryEmerald.withAlpha(25)
                                : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                            onPressed: isAlreadyAdded ? null : () => _addPersonSplit(friend),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
            // Individual person split rows
            if (_personSplits.isNotEmpty) ...[
              ...List.generate(_personSplits.length, (idx) {
                final entry = _personSplits[idx];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: entry.nameController,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            hintText: 'Friend name',
                            prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                            prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 0),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          controller: entry.amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            hintText: 'Share amount',
                            prefixText: '${CurrencyFormatter.activeCurrency.symbol} ',
                            prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline_rounded, size: 20, color: financialColors.expense),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() {
                            final removed = _personSplits.removeAt(idx);
                            removed.dispose();
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Add Person', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () => _addPersonSplit(),
                ),
                if (_personSplits.length > 1) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.balance_rounded, size: 16),
                    label: const Text('Split Evenly', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: _splitEvenlyAmongFriends,
                  ),
                ],
              ],
            ),
            // Unassigned split balance warning if amounts do not sum to friendsShare
            Builder(
              builder: (_) {
                double totalAssigned = 0;
                for (final p in _personSplits) {
                  totalAssigned += double.tryParse(p.amountController.text.trim()) ?? 0;
                }
                final diff = friendsShare - totalAssigned;
                if (_personSplits.isNotEmpty && diff.abs() > 0.01) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      diff > 0
                          ? 'Remaining to allocate to friends: ${CurrencyFormatter.format(diff)}'
                          : 'Over-allocated to friends by: ${CurrencyFormatter.format(-diff)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: financialColors.warning,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sharedWithController,
              decoration: const InputDecoration(
                hintText: 'Additional split notes (optional)',
                isDense: true,
                prefixIcon: Icon(Icons.note_alt_outlined, size: 18),
                prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 0),
              ),
            ),
            const SizedBox(height: 14),
            // Financial impact summary badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryEmerald.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryEmerald.withAlpha(51)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primaryEmerald),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Friends owe you: ${CurrencyFormatter.format(friendsShare)}. '
                      'Only ${CurrencyFormatter.format(myShare)} counts toward your personal expense budget.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoneyLentSection(ThemeData theme, AppFinancialColors financialColors, bool isDark) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final expectedInterest = _calculateExpectedInterest(amount);
    final totalExpected = amount + expectedInterest;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryEmerald,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withAlpha(38),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.handshake_rounded,
                  size: 20,
                  color: AppColors.primaryEmerald,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Money Lent / Personal Help',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Assisting a friend, colleague, or relative',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: financialColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Zero Net Expense',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryEmerald,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Mandatory Friend / Relative Name
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'FRIEND / RELATIVE NAME *',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.manage_accounts_outlined, size: 16),
                label: const Text('Saved Friends', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                onPressed: () => _showManageFriendsDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Quick-select chips from saved friends
          Consumer(
            builder: (ctx, ref, _) {
              final savedFriends = ref.watch(savedFriendsProvider);
              if (savedFriends.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: savedFriends.map((friend) {
                      final isSelected = _borrowerNameController.text.trim().toLowerCase() == friend.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: Icon(
                            isSelected ? Icons.check_rounded : Icons.person_outline_rounded,
                            size: 14,
                            color: isSelected ? AppColors.primaryEmerald : financialColors.textMuted,
                          ),
                          label: Text(friend),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppColors.primaryEmerald : null,
                          ),
                          backgroundColor: isSelected
                              ? AppColors.primaryEmerald.withAlpha(25)
                              : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _borrowerNameController.text = friend;
                              if (_titleController.text.isEmpty ||
                                  _titleController.text.startsWith('Money Lent')) {
                                _titleController.text = 'Money Lent to $friend';
                              }
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
          TextFormField(
            controller: _borrowerNameController,
            decoration: const InputDecoration(
              hintText: 'e.g. Rahul Sharma, Uncle Suresh',
              prefixIcon: Icon(Icons.person_rounded, size: 18),
              isDense: true,
            ),
            onChanged: (val) {
              setState(() {
                if (_titleController.text.isEmpty || _titleController.text.startsWith('Money Lent')) {
                  _titleController.text = val.trim().isEmpty ? 'Money Lent to Friend' : 'Money Lent to ${val.trim()}';
                }
              });
            },
          ),
          const SizedBox(height: 16),

          // Expected Return Date (Optional)
          Text(
            'EXPECTED RETURN DATE (OPTIONAL)',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: financialColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _expectedReturnDate ?? DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime(2020),
                lastDate: DateTime(2040),
              );
              if (picked != null) {
                setState(() => _expectedReturnDate = picked);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: financialColors.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    size: 18,
                    color: _expectedReturnDate != null ? AppColors.primaryEmerald : financialColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _expectedReturnDate != null
                          ? 'Return by: ${DateFormat('dd MMMM yyyy').format(_expectedReturnDate!)}'
                          : 'No fixed deadline (Flexible payback)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _expectedReturnDate != null ? FontWeight.w700 : FontWeight.w500,
                        color: _expectedReturnDate != null
                            ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                            : financialColors.textMuted,
                      ),
                    ),
                  ),
                  if (_expectedReturnDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _expectedReturnDate = null),
                      child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Expected Interest / Additional Return (Optional)
          Text(
            'EXPECTED INTEREST (OPTIONAL)',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: financialColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          // Full-width, responsive Segmented Tab Switch: % Rate vs ₹ Flat
          Container(
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: financialColors.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (!_isInterestPercentage) {
                        setState(() => _isInterestPercentage = true);
                      }
                    },
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isInterestPercentage ? AppColors.primaryEmerald : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.percent_rounded,
                            size: 15,
                            color: _isInterestPercentage ? Colors.white : financialColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '% Rate (Interest)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isInterestPercentage ? Colors.white : financialColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (_isInterestPercentage) {
                        setState(() => _isInterestPercentage = false);
                      }
                    },
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      decoration: BoxDecoration(
                        color: !_isInterestPercentage ? AppColors.primaryEmerald : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.currency_rupee_rounded,
                            size: 15,
                            color: !_isInterestPercentage ? Colors.white : financialColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${CurrencyFormatter.activeCurrency.symbol} Flat (Fixed Extra)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: !_isInterestPercentage ? Colors.white : financialColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _loanInterestController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              hintText: _isInterestPercentage ? 'e.g. 5 (means 5% interest rate)' : 'e.g. 500 (extra flat return)',
              prefixIcon: Icon(
                _isInterestPercentage ? Icons.percent_rounded : Icons.payments_rounded,
                size: 18,
              ),
              suffixIcon: _loanInterestController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _loanInterestController.clear());
                      },
                    )
                  : null,
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Dynamic Live Loan Summary Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryEmerald.withAlpha(isDark ? 28 : 20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primaryEmerald.withAlpha(80)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Principal Amount:',
                      style: TextStyle(fontSize: 12, color: financialColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      CurrencyFormatter.format(amount),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_circle_outline_rounded, size: 14, color: AppColors.primaryEmerald),
                        const SizedBox(width: 4),
                        Text(
                          'Expected Interest:',
                          style: TextStyle(fontSize: 12, color: financialColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      expectedInterest > 0
                          ? '+ ${CurrencyFormatter.format(expectedInterest)}'
                          : '${CurrencyFormatter.activeCurrency.symbol}0 (Interest-free)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryEmerald,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total to Receive Back:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(totalExpected),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryEmerald,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addPersonSplit([String name = '']) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final myShare = double.tryParse(_myShareController.text.trim()) ?? (amount / 2);
    final friendsShare = (amount - myShare).clamp(0.0, amount);

    double assigned = 0;
    for (final p in _personSplits) {
      assigned += double.tryParse(p.amountController.text.trim()) ?? 0;
    }
    final remaining = (friendsShare - assigned).clamp(0.0, friendsShare);
    final defaultAmt = remaining > 0 ? remaining : (friendsShare / (_personSplits.length + 1));
    final defaultAmtStr = defaultAmt > 0
        ? (defaultAmt == defaultAmt.roundToDouble()
            ? defaultAmt.toInt().toString()
            : defaultAmt.toStringAsFixed(0))
        : '';

    setState(() {
      _personSplits.add(
        _PersonSplitEntry(name: name, amount: defaultAmtStr),
      );
    });
  }

  void _splitEvenlyAmongFriends() {
    if (_personSplits.isEmpty) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final myShare = double.tryParse(_myShareController.text.trim()) ?? (amount / 2);
    final friendsShare = (amount - myShare).clamp(0.0, amount);

    final perPerson = friendsShare / _personSplits.length;
    final perPersonStr = perPerson == perPerson.roundToDouble()
        ? perPerson.toInt().toString()
        : perPerson.toStringAsFixed(0);

    setState(() {
      for (final p in _personSplits) {
        p.amountController.text = perPersonStr;
      }
    });
  }

  void _showManageFriendsDialog(BuildContext context) {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final friends = ref.watch(savedFriendsProvider);
          final financialColors = ctx.financialColors;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.people_alt_rounded, color: AppColors.primaryEmerald),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saved Roommates & Friends',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Enter friend / roommate name',
                            isDense: true,
                            prefixIcon: Icon(Icons.person_add_alt_1_rounded, size: 18),
                          ),
                          onSubmitted: (val) {
                            final name = val.trim();
                            if (name.isNotEmpty) {
                              ref.read(savedFriendsProvider.notifier).addFriend(name);
                              textCtrl.clear();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.check_rounded, size: 18),
                        onPressed: () {
                          final name = textCtrl.text.trim();
                          if (name.isNotEmpty) {
                            ref.read(savedFriendsProvider.notifier).addFriend(name);
                            textCtrl.clear();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (friends.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No saved friends yet. Enter names above or save a split expense to remember friends.',
                        style: TextStyle(fontSize: 12, color: financialColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: friends.length,
                        separatorBuilder: (_, _) => const Divider(height: 8),
                        itemBuilder: (ctx, idx) {
                          final f = friends[idx];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.primaryEmerald.withAlpha(40),
                              child: Text(
                                f.isNotEmpty ? f[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryEmerald,
                                ),
                              ),
                            ),
                            title: Text(f, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                              onPressed: () {
                                ref.read(savedFriendsProvider.notifier).removeFriend(f);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIncomeReimbursementSection(
    ThemeData theme,
    AppFinancialColors financialColors,
    bool isDark,
    List<CreditCardEntity> creditCards,
  ) {
    final pendingSplits = ref.watch(pendingSharedExpensesProvider);

    if (_selectedSharedExpenseToSettle == null && pendingSplits.isNotEmpty && _isIncomeReimbursement) {
      _selectedSharedExpenseToSettle = pendingSplits.first;
      if (_amountController.text.isEmpty || _amountController.text == '0') {
        final amt = _selectedSharedExpenseToSettle!.pendingReimbursement;
        _amountController.text = amt == amt.roundToDouble()
            ? amt.toInt().toString()
            : amt.toStringAsFixed(2);
      }
      if (_titleController.text.isEmpty || _titleController.text == _selectedCategory) {
        _titleController.text = 'Reimbursement: ${_selectedSharedExpenseToSettle!.title}';
      }
    }

    CreditCardEntity? linkedCard;
    if (_selectedSharedExpenseToSettle?.creditCardId != null) {
      final matches = creditCards.where((c) => c.id == _selectedSharedExpenseToSettle!.creditCardId);
      if (matches.isNotEmpty) linkedCard = matches.first;
    }

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isIncomeReimbursement
            ? (isDark ? const Color(0xFF13221B) : const Color(0xFFECFDF5))
            : (isDark ? AppColors.darkSurfaceVariant.withAlpha(128) : AppColors.lightSurfaceVariant.withAlpha(128)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isIncomeReimbursement
              ? AppColors.primaryEmerald
              : financialColors.cardBorder.withAlpha(128),
          width: _isIncomeReimbursement ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isIncomeReimbursement
                      ? AppColors.primaryEmerald.withAlpha(38)
                      : (isDark ? Colors.white10 : Colors.black.withAlpha(13)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.handshake_rounded,
                  size: 20,
                  color: _isIncomeReimbursement ? AppColors.primaryEmerald : financialColors.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expense Share (Roommate Payback)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _isIncomeReimbursement ? theme.colorScheme.onSurface : financialColors.textMuted,
                      ),
                    ),
                    Text(
                      _isIncomeReimbursement
                          ? 'Settling a shared expense back into your bank'
                          : 'Did a roommate or friend pay back their share?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: financialColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isIncomeReimbursement,
                activeThumbColor: AppColors.primaryEmerald,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isIncomeReimbursement = val;
                    if (val) {
                      _selectedCategory = 'Shared Expense Reimbursement';
                      if (pendingSplits.isNotEmpty) {
                        _selectedSharedExpenseToSettle = pendingSplits.first;
                        final amt = _selectedSharedExpenseToSettle!.pendingReimbursement;
                        _amountController.text = amt == amt.roundToDouble()
                            ? amt.toInt().toString()
                            : amt.toStringAsFixed(2);
                        _titleController.text = 'Reimbursement: ${_selectedSharedExpenseToSettle!.title}';
                      }
                    }
                  });
                },
              ),
            ],
          ),
          if (_isIncomeReimbursement) ...[
            const Divider(height: 24),
            if (pendingSplits.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No pending shared expenses waiting for reimbursement. You can still log general income under this category.',
                        style: TextStyle(
                          fontSize: 12,
                          color: financialColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'WHICH SHARED EXPENSE IS BEING REIMBURSED?',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: financialColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedSharedExpenseToSettle?.id ?? pendingSplits.first.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.receipt_long_rounded, size: 18),
                ),
                items: pendingSplits.map((tx) {
                  return DropdownMenuItem<String>(
                    value: tx.id,
                    child: Text(
                      '${tx.title} (${CurrencyFormatter.format(tx.pendingReimbursement)} pending)',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final match = pendingSplits.firstWhere((t) => t.id == id);
                  setState(() {
                    _selectedSharedExpenseToSettle = match;
                    final amt = match.pendingReimbursement;
                    _amountController.text = amt == amt.roundToDouble()
                        ? amt.toInt().toString()
                        : amt.toStringAsFixed(2);
                    _titleController.text = 'Reimbursement: ${match.title}';
                  });
                },
              ),
              if (_selectedSharedExpenseToSettle != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: financialColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      _buildMiniReimbursementStat('Total Bill', CurrencyFormatter.format(_selectedSharedExpenseToSettle!.amount), financialColors, isDark),
                      const SizedBox(width: 6),
                      _buildMiniReimbursementStat('My Share', CurrencyFormatter.format(_selectedSharedExpenseToSettle!.myShareAmount ?? _selectedSharedExpenseToSettle!.amount), financialColors, isDark),
                      const SizedBox(width: 6),
                      _buildMiniReimbursementStat('Friends Owe', CurrencyFormatter.format(_selectedSharedExpenseToSettle!.friendsShare), financialColors, isDark),
                      const SizedBox(width: 6),
                      _buildMiniReimbursementStat('Pending', CurrencyFormatter.format(_selectedSharedExpenseToSettle!.pendingReimbursement), financialColors, isDark, isHighlight: true),
                    ],
                  ),
                ),
                if (linkedCard != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withAlpha(isDark ? 30 : 20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.info.withAlpha(80)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.credit_card_rounded, size: 18, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Originally paid with ${linkedCard.cardName}. Depositing this reimbursement to your bank keeps this amount earmarked for your credit card bill!',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMiniReimbursementStat(
    String label,
    String value,
    AppFinancialColors fc,
    bool isDark, {
    bool isHighlight = false,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: fc.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isHighlight
                    ? AppColors.primaryEmerald
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
