import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/domain/entities/category_constants.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/services/overlay_service.dart';

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
  String _selectedPaymentSource = 'UPI / Wallet';
  bool _isSaving = false;
  bool _justSaved = false;

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _expand() async {
    await OverlayService.expandOverlay();
    if (mounted) {
      setState(() {
        _isExpanded = true;
        _justSaved = false;
      });
    }
  }

  void _collapse() async {
    await OverlayService.collapseOverlay();
    if (mounted) {
      setState(() {
        _isExpanded = false;
      });
    }
  }

  Future<void> _saveQuickTransaction() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final title = _titleController.text.trim().isEmpty
          ? (_type == TransactionType.expense ? 'Quick Expense' : 'Quick Income')
          : _titleController.text.trim();

      final tx = TransactionEntity(
        id: const Uuid().v4(),
        title: title,
        amount: amount,
        type: _type,
        category: _selectedCategory,
        date: now,
        notes: 'Logged from Quick Floating Bubble',
        paymentSource: _selectedPaymentSource,
        createdAt: now,
        updatedAt: now,
      );

      final db = AppDatabase.instance;
      await db.insertTransaction(tx);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _justSaved = true;
          _amountController.clear();
          _titleController.clear();
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
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF10B981), Color(0xFF047857)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(90),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.white.withAlpha(200), width: 2),
          ),
          child: const Center(
            child: Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedCard() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF131B26),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primaryEmerald.withAlpha(120), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(160),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
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
                      'Quick Log',
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
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.primaryEmerald, size: 36),
                    SizedBox(height: 6),
                    Text(
                      'Saved to EmptyPocket!',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              )
            else ...[
              // Type Segmented Switcher
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _type = TransactionType.expense;
                        _selectedCategory = 'Food & Dining';
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
              const SizedBox(height: 12),

              // Amount Input
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(70)),
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(color: AppColors.primaryEmerald, fontSize: 20, fontWeight: FontWeight.w800),
                  filled: true,
                  fillColor: Colors.white.withAlpha(15),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),

              // Optional Title
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Note / Title (optional)',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(70)),
                  filled: true,
                  fillColor: Colors.white.withAlpha(15),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),

              // Quick Categories
              SizedBox(
                height: 32,
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
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryEmerald : Colors.white10,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryEmerald : Colors.white24,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 11,
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

              // Payment Method Chips
              SizedBox(
                height: 30,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: CategoryConstants.paymentSources.take(4).map((src) {
                    final isSelected = _selectedPaymentSource == src;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedPaymentSource = src),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryEmerald.withAlpha(60) : Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryEmerald : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            src,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppColors.primaryEmerald : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isSaving ? null : _saveQuickTransaction,
                  child: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text(
                          'Save Transaction',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
