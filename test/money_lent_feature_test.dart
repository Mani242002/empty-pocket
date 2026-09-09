import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/utilities/loan_share_helper.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';

void main() {
  group('Money Lent / Personal Assistance Tests', () {
    test('LoanShareData serialization, deserialization, and calculations', () {
      final returnDate = DateTime(2026, 10, 15);
      const loan = LoanShareData(
        borrowerName: 'Rahul',
        principalAmount: 10000.0,
        expectedInterest: 500.0,
        interestRate: 5.0,
        repaidAmount: 0.0,
        isRepaid: false,
        paymentSource: 'HDFC Bank',
      );

      expect(loan.totalExpected, 10500.0);
      expect(loan.pendingAmount, 10500.0);
      expect(loan.isRepaid, false);

      // JSON encoding
      final encoded = LoanShareHelper.encodeLoan(loan.copyWith(expectedReturnDate: returnDate));
      expect(LoanShareHelper.isLoan(encoded), true);
      expect(encoded.contains('"type":"loan"'), true);

      // JSON decoding
      final decoded = LoanShareHelper.parseLoan(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.borrowerName, 'Rahul');
      expect(decoded.principalAmount, 10000.0);
      expect(decoded.expectedInterest, 500.0);
      expect(decoded.interestRate, 5.0);
      expect(decoded.totalExpected, 10500.0);
      expect(decoded.repaidAmount, 0.0);
      expect(decoded.pendingAmount, 10500.0);
      expect(decoded.isRepaid, false);
      expect(decoded.expectedReturnDate?.year, 2026);
      expect(decoded.expectedReturnDate?.month, 10);
      expect(decoded.expectedReturnDate?.day, 15);
    });

    test('Partial and full repayment calculations', () {
      const loan = LoanShareData(
        borrowerName: 'Anita',
        principalAmount: 5000.0,
        expectedInterest: 200.0,
        repaidAmount: 2000.0,
        isRepaid: false,
      );

      expect(loan.totalExpected, 5200.0);
      expect(loan.pendingAmount, 3200.0);
      expect(loan.isRepaid, false);

      final fullyRepaid = loan.copyWith(repaidAmount: 5200.0, isRepaid: true);
      expect(fullyRepaid.pendingAmount, 0.0);
      expect(fullyRepaid.isRepaid, true);
    });

    test('FinancialCalculator excludes Money Lent from personal consumption expenses', () {
      final now = DateTime.now();
      final List<TransactionEntity> transactions = [
        // Normal expense
        TransactionEntity(
          id: 'tx-1',
          title: 'Groceries',
          amount: 2500.0,
          type: TransactionType.expense,
          category: 'Groceries',
          paymentSource: 'Bank Account',
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
        // Money lent to a friend
        TransactionEntity(
          id: 'tx-2',
          title: 'Money Lent to Rahul',
          amount: 10000.0,
          type: TransactionType.expense,
          category: 'Money Lent / Helping Friend',
          paymentSource: 'Bank Account',
          sharedWith: LoanShareHelper.encodeLoan(const LoanShareData(
            borrowerName: 'Rahul',
            principalAmount: 10000.0,
            expectedInterest: 500.0,
          )),
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // Net personal consumption expense must ONLY be 2500.0, NOT 12500.0
      final totalExpense = FinancialCalculator.calculateTotalExpense(transactions);
      expect(totalExpense, 2500.0, reason: 'Money Lent must not count as personal consumption expense');
    });

    test('FinancialCalculator excludes Loan Repayment Received from earned income', () {
      final now = DateTime.now();
      final List<TransactionEntity> transactions = [
        // Normal income
        TransactionEntity(
          id: 'tx-1',
          title: 'Salary',
          amount: 75000.0,
          type: TransactionType.income,
          category: 'Salary',
          paymentSource: 'Bank Account',
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
        // Loan repayment received
        TransactionEntity(
          id: 'tx-2',
          title: 'Repayment: Rahul',
          amount: 10500.0,
          type: TransactionType.income,
          category: 'Loan Repayment Received',
          paymentSource: 'Bank Account',
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // Net earned income must ONLY be 75000.0, NOT 85500.0
      final totalIncome = FinancialCalculator.calculateTotalIncome(transactions);
      expect(totalIncome, 75000.0, reason: 'Loan Repayment Received must not count as earned income');
    });
  });
}
