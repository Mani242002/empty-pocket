import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/domain/entities/bank_account_entity.dart';
import '../../../../core/domain/entities/credit_card_entity.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/services/overlay_service.dart';
import '../../../../core/utilities/currency_formatter.dart';

class FloatingBubbleOverlayApp extends StatelessWidget {
  const FloatingBubbleOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const Scaffold(
        backgroundColor: Colors.transparent,
        body: FloatingBubbleOverlayScreen(),
      ),
    );
  }
}

class FloatingBubbleOverlayScreen extends StatefulWidget {
  const FloatingBubbleOverlayScreen({super.key});

  @override
  State<FloatingBubbleOverlayScreen> createState() => _FloatingBubbleOverlayScreenState();
}

class _FloatingBubbleOverlayScreenState extends State<FloatingBubbleOverlayScreen> {
  bool _isExpanded = false;
  TransactionType _type = TransactionType.expense;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  String _selectedCategory = 'Food & Dining';
  PaymentMode _selectedPaymentMode = PaymentMode.bankAccount;
  String? _selectedAccountId;
  String? _selectedCreditCardId;
  String _selectedPaymentSource = 'Bank Account';

  List<BankAccountEntity> _bankAccounts = [];
  List<CreditCardEntity> _creditCards = [];

  String? _validationError;
  bool _isSaving = false;
  bool _justSaved = false;

  @override
  void initState() {
    super.initState();
    _loadAccountsAndCards();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadAccountsAndCards() async {
    try {
      final db = AppDatabase.instance;
      final accs = await db.getAllBankAccounts();
      final cards = await db.getAllCreditCards();
      if (mounted) {
        setState(() {
          _bankAccounts = accs;
          _creditCards = cards;
          _autoSelectLinkedSource(_selectedPaymentMode);
        });
      }
    } catch (_) {}
  }

  void _expand() async {
    await _loadAccountsAndCards();
    await OverlayService.expandOverlay();
    if (mounted) {
      setState(() {
        _isExpanded = true;
        _justSaved = false;
        _validationError = null;
      });
    }
  }

  void _collapse() async {
    await OverlayService.collapseOverlay();
    if (mounted) {
      setState(() {
        _isExpanded = false;
        _validationError = null;
      });
    }
  }

  void _autoSelectLinkedSource(PaymentMode mode) {
    switch (mode) {
      case PaymentMode.bankAccount:
        if (_bankAccounts.isNotEmpty) {
          final def = _bankAccounts.where((a) => a.isDefault);
          final acc = def.isNotEmpty ? def.first : _bankAccounts.first;
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
        if (_creditCards.isNotEmpty) {
          final card = _creditCards.first;
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
        if (_bankAccounts.isNotEmpty) {
          final def = _bankAccounts.where((a) => a.isDefault);
          final acc = def.isNotEmpty ? def.first : _bankAccounts.first;
          _selectedAccountId = acc.id;
          _selectedCreditCardId = null;
          _selectedPaymentSource = 'UPI (${acc.accountName})';
        } else {
          final rupayCards = _creditCards.where((c) => c.cardNetwork == CardNetwork.rupay).toList();
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
        final cashAccounts = _bankAccounts.where((a) => a.accountType == AccountType.cash).toList();
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

  Future<void> _saveQuickTransaction() async {
    // 1. Mandatory Amount Validation
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      setState(() => _validationError = 'Please enter an amount.');
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _validationError = 'Please enter a valid amount greater than 0.');
      return;
    }

    // 2. Mandatory Title / Reason Validation
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _validationError = 'Please enter title or reason.');
      return;
    }

    // 3. Mandatory Linked Source Validation
    if (_selectedPaymentMode == PaymentMode.bankAccount && _bankAccounts.isNotEmpty && _selectedAccountId == null) {
      setState(() => _validationError = 'Please select a linked bank account.');
      return;
    }
    if (_selectedPaymentMode == PaymentMode.creditCard && _creditCards.isNotEmpty && _selectedCreditCardId == null) {
      setState(() => _validationError = 'Please select a linked credit card.');
      return;
    }

    setState(() {
      _validationError = null;
      _isSaving = true;
    });

    try {
      final now = DateTime.now();
      final db = AppDatabase.instance;

      // Balance & Limit adjustments
      if (_type == TransactionType.income) {
        if (_selectedAccountId != null) {
          final matching = _bankAccounts.where((a) => a.id == _selectedAccountId);
          if (matching.isNotEmpty) {
            final acc = matching.first;
            await db.updateBankAccount(
              acc.copyWith(
                currentBalance: acc.currentBalance + amount,
                updatedAt: now,
              ),
            );
          }
        } else if (_selectedCreditCardId != null) {
          final matching = _creditCards.where((c) => c.id == _selectedCreditCardId);
          if (matching.isNotEmpty) {
            final card = matching.first;
            await db.updateCreditCard(
              card.copyWith(
                usedAmount: (card.usedAmount - amount).clamp(0.0, double.infinity),
                updatedAt: now,
              ),
            );
          }
        }
      } else if (_type == TransactionType.expense) {
        if (_selectedCreditCardId != null) {
          final matching = _creditCards.where((c) => c.id == _selectedCreditCardId);
          if (matching.isNotEmpty) {
            final card = matching.first;
            await db.updateCreditCard(
              card.copyWith(
                usedAmount: card.usedAmount + amount,
                updatedAt: now,
              ),
            );
          }
        } else if (_selectedAccountId != null) {
          final matching = _bankAccounts.where((a) => a.id == _selectedAccountId);
          if (matching.isNotEmpty) {
            final acc = matching.first;
            await db.updateBankAccount(
              acc.copyWith(
                currentBalance: acc.currentBalance - amount,
                updatedAt: now,
              ),
            );
          }
        }
      }

      final tx = TransactionEntity(
        id: const Uuid().v4(),
        title: title,
        amount: amount,
        type: _type,
        category: _selectedCategory,
        date: now,
        notes: 'Logged from Quick Floating Bubble',
        paymentSource: _selectedPaymentSource,
        accountId: _selectedAccountId,
        creditCardId: _selectedCreditCardId,
        createdAt: now,
        updatedAt: now,
      );

      await db.insertTransaction(tx);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _justSaved = true;
          _amountController.clear();
          _titleController.clear();
          _validationError = null;
        });

        await Future.delayed(const Duration(milliseconds: 700));
        _collapse();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpanded) {
      return _buildCollapsedBubble();
    }
    return _buildExpandedCard();
  }

  Widget _buildCollapsedBubble() {
    return Center(
      child: GestureDetector(
        onTap: _expand,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryEmerald.withAlpha(220),
                width: 1.5,
              ),
              color: const Color(0xFF131B26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(140),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14.5),
              child: Image.asset(
                'assets/icon/app_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedCard() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF131B26),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primaryEmerald.withAlpha(120), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(180),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryEmerald.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flash_on_rounded, color: AppColors.primaryEmerald, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Quick Transaction',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    onPressed: _collapse,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_justSaved)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: const Column(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.primaryEmerald, size: 42),
                      SizedBox(height: 8),
                      Text(
                        'Saved to EmptyPocket!',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                )
              else ...[
                // Type Switcher
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _type = TransactionType.expense;
                          _selectedCategory = 'Food & Dining';
                          _validationError = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _type == TransactionType.expense ? AppColors.expense : Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Expense',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _type = TransactionType.income;
                          _selectedCategory = 'Salary';
                          _validationError = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _type == TransactionType.income ? AppColors.income : Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Income',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Amount Input
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  onChanged: (_) {
                    if (_validationError != null) setState(() => _validationError = null);
                  },
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(70)),
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                      color: _type == TransactionType.income ? AppColors.income : AppColors.expense,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    filled: true,
                    fillColor: Colors.white.withAlpha(15),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),

                // Title / Reason (Mandatory)
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (_) {
                    if (_validationError != null) setState(() => _validationError = null);
                  },
                  decoration: InputDecoration(
                    hintText: 'Title / Reason (Mandatory)',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(70)),
                    filled: true,
                    fillColor: Colors.white.withAlpha(15),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),

                // Category Chips
                SizedBox(
                  height: 30,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: (_type == TransactionType.expense
                            ? ['Food & Dining', 'Groceries', 'Shopping', 'Transportation', 'Bills & Utilities', 'Entertainment']
                            : ['Salary', 'Freelance', 'Investments / Dividend', 'Gifts & Rewards'])
                        .map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedCategory = cat;
                            if (_titleController.text.trim().isEmpty) {
                              _titleController.text = cat;
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryEmerald : Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryEmerald : Colors.white24,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),

                // TWO-TIER PAYMENT METHOD SELECTION
                // Tier 1: Method Dropdown
                Text(
                  _type == TransactionType.income ? 'DEPOSIT TO (METHOD)' : 'PAY FROM (METHOD)',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white60, letterSpacing: 0.8),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<PaymentMode>(
                      value: _selectedPaymentMode,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1B2430),
                      items: PaymentMode.values.map((mode) {
                        return DropdownMenuItem<PaymentMode>(
                          value: mode,
                          child: Row(
                            children: [
                              Icon(mode.icon, size: 16, color: AppColors.primaryEmerald),
                              const SizedBox(width: 8),
                              Text(mode.displayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (mode) {
                        if (mode == null) return;
                        setState(() {
                          _selectedPaymentMode = mode;
                          _autoSelectLinkedSource(mode);
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Tier 2: Linked Source Dropdown
                Text(
                  _selectedPaymentMode == PaymentMode.bankAccount
                      ? 'SELECT BANK ACCOUNT'
                      : (_selectedPaymentMode == PaymentMode.creditCard
                          ? 'SELECT CREDIT CARD'
                          : (_selectedPaymentMode == PaymentMode.upiWallet
                              ? 'LINKED UPI / RUPAY CARD'
                              : 'CASH WALLET')),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white60, letterSpacing: 0.8),
                ),
                const SizedBox(height: 4),
                _buildBubbleLinkedSourceDropdown(),
                const SizedBox(height: 8),

                // Validation Error Banner
                if (_validationError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.expense.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.expense.withAlpha(100)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.expense),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _validationError!,
                            style: const TextStyle(color: AppColors.expense, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryEmerald,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSaving ? null : _saveQuickTransaction,
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text(
                            'Save Transaction',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubbleLinkedSourceDropdown() {
    switch (_selectedPaymentMode) {
      case PaymentMode.bankAccount:
        if (_bankAccounts.isEmpty) {
          return _buildFallbackBanner('No bank accounts configured (Default)');
        }
        final valid = _bankAccounts.any((a) => a.id == _selectedAccountId);
        final initial = valid ? _selectedAccountId : _bankAccounts.first.id;

        return _buildDropdownContainer(
          DropdownButton<String>(
            value: initial,
            isExpanded: true,
            dropdownColor: const Color(0xFF1B2430),
            items: _bankAccounts.map((acc) {
              return DropdownMenuItem(
                value: acc.id,
                child: Text(
                  '${acc.accountName} (${CurrencyFormatter.format(acc.currentBalance)})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _selectedAccountId = val;
                _selectedCreditCardId = null;
                final acc = _bankAccounts.firstWhere((a) => a.id == val);
                _selectedPaymentSource = acc.accountName;
              });
            },
          ),
        );

      case PaymentMode.creditCard:
        if (_creditCards.isEmpty) {
          return _buildFallbackBanner('No credit cards added (Default)');
        }
        final valid = _creditCards.any((c) => c.id == _selectedCreditCardId);
        final initial = valid ? _selectedCreditCardId : _creditCards.first.id;

        return _buildDropdownContainer(
          DropdownButton<String>(
            value: initial,
            isExpanded: true,
            dropdownColor: const Color(0xFF1B2430),
            items: _creditCards.map((card) {
              return DropdownMenuItem(
                value: card.id,
                child: Text(
                  '💳 ${card.cardName} (${card.bankName}) • Avail: ${CurrencyFormatter.format(card.availableLimit)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _selectedCreditCardId = val;
                _selectedAccountId = null;
                final card = _creditCards.firstWhere((c) => c.id == val);
                _selectedPaymentSource = card.cardName;
              });
            },
          ),
        );

      case PaymentMode.upiWallet:
        final rupayCards = _creditCards.where((c) => c.cardNetwork == CardNetwork.rupay).toList();
        if (_bankAccounts.isEmpty && rupayCards.isEmpty) {
          return _buildFallbackBanner('No bank accounts or RuPay cards');
        }

        final upiKey = _selectedCreditCardId != null
            ? 'card_$_selectedCreditCardId'
            : (_selectedAccountId != null ? 'acc_$_selectedAccountId' : null);

        final items = <DropdownMenuItem<String>>[
          ..._bankAccounts.map((acc) => DropdownMenuItem<String>(
                value: 'acc_${acc.id}',
                child: Text(
                  '🏦 ${acc.accountName} (${CurrencyFormatter.format(acc.currentBalance)})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              )),
          ...rupayCards.map((card) => DropdownMenuItem<String>(
                value: 'card_${card.id}',
                child: Text(
                  '💳 ${card.cardName} (RuPay UPI) • Avail: ${CurrencyFormatter.format(card.availableLimit)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              )),
        ];

        final isKeyValid = items.any((i) => i.value == upiKey);
        final initialVal = isKeyValid ? upiKey : items.first.value;

        return _buildDropdownContainer(
          DropdownButton<String>(
            value: initialVal,
            isExpanded: true,
            dropdownColor: const Color(0xFF1B2430),
            items: items,
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                if (val.startsWith('acc_')) {
                  final accId = val.substring(4);
                  _selectedAccountId = accId;
                  _selectedCreditCardId = null;
                  final acc = _bankAccounts.firstWhere((a) => a.id == accId);
                  _selectedPaymentSource = 'UPI (${acc.accountName})';
                } else if (val.startsWith('card_')) {
                  final cardId = val.substring(5);
                  _selectedCreditCardId = cardId;
                  _selectedAccountId = null;
                  final card = _creditCards.firstWhere((c) => c.id == cardId);
                  _selectedPaymentSource = 'UPI (${card.cardName})';
                }
              });
            },
          ),
        );

      case PaymentMode.cash:
        final cashAccounts = _bankAccounts.where((a) => a.accountType == AccountType.cash).toList();
        if (cashAccounts.isEmpty) {
          return _buildFallbackBanner('Physical Cash / Cash in Hand');
        }

        final valid = cashAccounts.any((a) => a.id == _selectedAccountId);
        final initial = valid ? _selectedAccountId : cashAccounts.first.id;

        return _buildDropdownContainer(
          DropdownButton<String>(
            value: initial,
            isExpanded: true,
            dropdownColor: const Color(0xFF1B2430),
            items: cashAccounts.map((acc) {
              return DropdownMenuItem(
                value: acc.id,
                child: Text(
                  '💵 ${acc.accountName} (${CurrencyFormatter.format(acc.currentBalance)})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _selectedAccountId = val;
                _selectedCreditCardId = null;
                final acc = cashAccounts.firstWhere((a) => a.id == val);
                _selectedPaymentSource = acc.accountName;
              });
            },
          ),
        );
    }
  }

  Widget _buildDropdownContainer(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }

  Widget _buildFallbackBanner(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
      ),
    );
  }
}
