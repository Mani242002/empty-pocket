import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:empty_pocket/core/domain/entities/ai_assistant_entity.dart';
import 'package:empty_pocket/core/domain/entities/bank_account_entity.dart';
import 'package:empty_pocket/core/domain/entities/savings_goal_entity.dart';
import 'package:empty_pocket/core/domain/entities/split_person_share.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/repositories/bank_account_repository.dart';
import 'package:empty_pocket/core/repositories/savings_goal_repository.dart';
import 'package:empty_pocket/core/utilities/loan_share_helper.dart';
import 'package:empty_pocket/core/utilities/split_helper.dart';
import 'package:empty_pocket/features/accounts/presentation/state/accounts_cards_provider.dart';
import 'package:empty_pocket/features/savings/presentation/state/savings_goals_provider.dart';

void main() {
  group('Duplication Split & Settlement Reset Tests', () {
    test('resetSharesForDuplication resets individual SplitPersonShares to 0.0 and unsettled', () {
      final initialShares = [
        const SplitPersonShare(
          personName: 'Rahul',
          amount: 500.0,
          reimbursedAmount: 500.0,
          isSettled: true,
        ),
        const SplitPersonShare(
          personName: 'Amit',
          amount: 300.0,
          reimbursedAmount: 150.0,
          isSettled: false,
        ),
      ];

      final encoded = SplitHelper.encodeShares(initialShares);
      final resetEncoded = SplitHelper.resetSharesForDuplication(encoded);

      expect(resetEncoded, isNotNull);
      final resetShares = SplitHelper.parseShares(resetEncoded);

      expect(resetShares.length, 2);
      expect(resetShares[0].personName, 'Rahul');
      expect(resetShares[0].amount, 500.0);
      expect(resetShares[0].reimbursedAmount, 0.0);
      expect(resetShares[0].isSettled, isFalse);
      expect(resetShares[0].pendingAmount, 500.0);

      expect(resetShares[1].personName, 'Amit');
      expect(resetShares[1].amount, 300.0);
      expect(resetShares[1].reimbursedAmount, 0.0);
      expect(resetShares[1].isSettled, isFalse);
      expect(resetShares[1].pendingAmount, 300.0);
    });

    test('resetSharesForDuplication resets LoanShareData to 0.0 repaid and unsettled', () {
      final loan = LoanShareData(
        borrowerName: 'Suresh',
        principalAmount: 10000.0,
        expectedInterest: 500.0,
        repaidAmount: 10500.0,
        isRepaid: true,
      );

      final encoded = LoanShareHelper.encodeLoan(loan);
      final resetEncoded = SplitHelper.resetSharesForDuplication(encoded);

      expect(resetEncoded, isNotNull);
      final resetLoan = LoanShareHelper.parseLoan(resetEncoded);

      expect(resetLoan, isNotNull);
      expect(resetLoan!.borrowerName, 'Suresh');
      expect(resetLoan.principalAmount, 10000.0);
      expect(resetLoan.expectedInterest, 500.0);
      expect(resetLoan.repaidAmount, 0.0);
      expect(resetLoan.isRepaid, isFalse);
      expect(resetLoan.pendingAmount, 10500.0);
    });

    test('resetSharesForDuplication preserves plain string names without modification', () {
      const plain = 'Rahul, Amit, Priya';
      final result = SplitHelper.resetSharesForDuplication(plain);
      expect(result, plain);
    });

    test('Duplicating a settled shared transaction yields zero reimbursed amount and unsettled state', () {
      final now = DateTime.now();
      final settledShares = [
        const SplitPersonShare(
          personName: 'Rohan',
          amount: 600.0,
          reimbursedAmount: 600.0,
          isSettled: true,
        ),
      ];

      final originalTx = TransactionEntity(
        id: 'orig-123',
        title: 'Dinner at Bawarchi',
        amount: 1200.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: now.subtract(const Duration(days: 3)),
        paymentSource: 'SBI Account',
        isShared: true,
        myShareAmount: 600.0,
        reimbursedAmount: 600.0,
        isSettled: true,
        sharedWith: SplitHelper.encodeShares(settledShares),
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
      );

      // Clone transaction using identical logic to transactions_screen and transaction_detail_sheet
      final cloned = originalTx.copyWith(
        id: 'clone-456',
        date: now,
        createdAt: now,
        updatedAt: now,
        reimbursedAmount: originalTx.isShared ? 0.0 : originalTx.reimbursedAmount,
        isSettled: originalTx.isShared ? false : originalTx.isSettled,
        sharedWith: originalTx.isShared
            ? SplitHelper.resetSharesForDuplication(originalTx.sharedWith)
            : originalTx.sharedWith,
      );

      expect(cloned.id, 'clone-456');
      expect(cloned.reimbursedAmount, 0.0);
      expect(cloned.isSettled, isFalse);
      expect(cloned.pendingReimbursement, 600.0);

      final clonedShares = SplitHelper.parseShares(cloned.sharedWith);
      expect(clonedShares.length, 1);
      expect(clonedShares[0].reimbursedAmount, 0.0);
      expect(clonedShares[0].isSettled, isFalse);
      expect(clonedShares[0].pendingAmount, 600.0);
    });
  });

  group('Smart Inflow Distribution Logic Tests', () {
    test('applyInflowDistribution correctly updates linked goals allocation percentages and amounts', () async {
      final now = DateTime.now();
      final testAccount = BankAccountEntity(
        id: 'acc-sbi-1',
        accountName: 'SBI Salary Account',
        bankName: 'SBI',
        accountType: AccountType.savings,
        initialBalance: 100000.0,
        currentBalance: 100000.0,
        usedFor: 'Investments & Bills',
        createdAt: now,
        updatedAt: now,
      );

      final goal1 = SavingsGoalEntity(
        id: 'goal-mf-1',
        title: 'Mutual Funds SIP',
        targetAmount: 200000.0,
        currentAmount: 0.0,
        category: 'Investments',
        targetDate: now.add(const Duration(days: 365)),
        linkedAccountId: testAccount.id,
        allocationPercentage: 50.0,
        autoSyncAccount: true,
        createdAt: now,
        updatedAt: now,
      );

      final goal2 = SavingsGoalEntity(
        id: 'goal-ins-2',
        title: 'Term Insurance Buffer',
        targetAmount: 50000.0,
        currentAmount: 0.0,
        category: 'Insurance',
        targetDate: now.add(const Duration(days: 365)),
        linkedAccountId: testAccount.id,
        allocationPercentage: 20.0,
        autoSyncAccount: true,
        createdAt: now,
        updatedAt: now,
      );

      final goalRepo = InMemorySavingsGoalRepository([goal1, goal2]);
      final accountRepo = InMemoryBankAccountRepository([testAccount]);

      final container = ProviderContainer(
        overrides: [
          savingsGoalRepositoryProvider.overrideWithValue(goalRepo),
          bankAccountRepositoryProvider.overrideWithValue(accountRepo),
        ],
      );

      // Pre-warm providers
      await container.read(bankAccountListProvider.future);
      await container.read(savingsGoalsListNotifierProvider.future);

      // Apply distribution plan: 60% to primary, 30% to secondary
      await container.read(savingsGoalsListNotifierProvider.notifier).applyInflowDistribution(
            accountId: testAccount.id,
            primaryPercent: 60.0,
            secondaryPercent: 30.0,
            customBalance: 100000.0,
          );

      final updatedGoals = container.read(savingsGoalsListNotifierProvider).value!;
      final updatedG1 = updatedGoals.firstWhere((g) => g.id == goal1.id);
      final updatedG2 = updatedGoals.firstWhere((g) => g.id == goal2.id);

      expect(updatedG1.allocationPercentage, 60.0);
      expect(updatedG1.currentAmount, 60000.0); // 60% of 100,000

      expect(updatedG2.allocationPercentage, 30.0);
      expect(updatedG2.currentAmount, 30000.0); // 30% of 100,000
    });
  });

  group('AI History Error Sanitization Tests', () {
    test('Error messages are strictly filtered out when constructing history', () {
      final messages = [
        AiChatMessage(
          id: '1',
          sessionId: 's1',
          text: 'What was my spend last week?',
          isUser: true,
          timestamp: DateTime.now(),
        ),
        AiChatMessage(
          id: '2',
          sessionId: 's1',
          text: '❌ **Error connecting to Google Gemini**: SocketException: Connection refused',
          isUser: false,
          timestamp: DateTime.now(),
        ),
        AiChatMessage(
          id: '3',
          sessionId: 's1',
          text: '⚠️ Warning: Timeout waiting for model response',
          isUser: false,
          timestamp: DateTime.now(),
        ),
        AiChatMessage(
          id: '4',
          sessionId: 's1',
          text: 'Can you try again?',
          isUser: true,
          timestamp: DateTime.now(),
        ),
      ];

      // Replicate the filtering logic implemented in ai_assistant_provider and ai_service
      final cleanHistory = messages
          .where((m) => !m.text.startsWith('❌') && !m.text.startsWith('⚠️'))
          .toList();

      expect(cleanHistory.length, 2);
      expect(cleanHistory[0].id, '1');
      expect(cleanHistory[1].id, '4');
      expect(cleanHistory.any((m) => m.text.contains('Error connecting')), isFalse);
      expect(cleanHistory.any((m) => m.text.contains('Warning:')), isFalse);
    });
  });
}
