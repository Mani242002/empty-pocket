import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../domain/entities/credit_card_entity.dart';
import 'transaction_repository.dart';

abstract class CreditCardRepository {
  Future<List<CreditCardEntity>> getAllCards();
  Future<CreditCardEntity?> getCardById(String id);
  Future<void> saveCard(CreditCardEntity card, {DatabaseExecutor? executor});
  Future<void> updateCard(CreditCardEntity card, {DatabaseExecutor? executor});
  Future<void> adjustUsedAmount(
    String id,
    double delta, {
    DatabaseExecutor? executor,
  });
  Future<void> deleteCard(String id, {DatabaseExecutor? executor});
}

class SqliteCreditCardRepository implements CreditCardRepository {
  final AppDatabase _db;

  SqliteCreditCardRepository(this._db);

  @override
  Future<List<CreditCardEntity>> getAllCards() {
    return _db.getAllCreditCards();
  }

  @override
  Future<CreditCardEntity?> getCardById(String id) {
    return _db.getCreditCardById(id);
  }

  @override
  Future<void> saveCard(
    CreditCardEntity card, {
    DatabaseExecutor? executor,
  }) async {
    await _db.insertCreditCard(card, executor: executor);
  }

  @override
  Future<void> updateCard(
    CreditCardEntity card, {
    DatabaseExecutor? executor,
  }) async {
    await _db.updateCreditCard(card, executor: executor);
  }

  @override
  Future<void> adjustUsedAmount(
    String id,
    double delta, {
    DatabaseExecutor? executor,
  }) async {
    await _db.adjustCreditCardUsedAmount(id, delta, executor: executor);
  }

  @override
  Future<void> deleteCard(String id, {DatabaseExecutor? executor}) async {
    await _db.deleteCreditCard(id, executor: executor);
  }
}

class InMemoryCreditCardRepository implements CreditCardRepository {
  final List<CreditCardEntity> _cards = [];

  InMemoryCreditCardRepository([List<CreditCardEntity>? initial]) {
    if (initial != null) {
      _cards.addAll(initial);
    }
  }

  @override
  Future<List<CreditCardEntity>> getAllCards() async {
    return List<CreditCardEntity>.from(_cards);
  }

  @override
  Future<CreditCardEntity?> getCardById(String id) async {
    final matches = _cards.where((c) => c.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<void> saveCard(
    CreditCardEntity card, {
    DatabaseExecutor? executor,
  }) async {
    _cards.removeWhere((c) => c.id == card.id);
    _cards.add(card);
  }

  @override
  Future<void> updateCard(
    CreditCardEntity card, {
    DatabaseExecutor? executor,
  }) async {
    final index = _cards.indexWhere((c) => c.id == card.id);
    if (index != -1) {
      _cards[index] = card;
    } else {
      _cards.add(card);
    }
  }

  @override
  Future<void> adjustUsedAmount(
    String id,
    double delta, {
    DatabaseExecutor? executor,
  }) async {
    final index = _cards.indexWhere((c) => c.id == id);
    if (index != -1) {
      final old = _cards[index];
      _cards[index] = old.copyWith(usedAmount: old.usedAmount + delta);
    }
  }

  @override
  Future<void> deleteCard(String id, {DatabaseExecutor? executor}) async {
    _cards.removeWhere((c) => c.id == id);
  }
}

/// Credit Card Repository Provider
final creditCardRepositoryProvider = Provider<CreditCardRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SqliteCreditCardRepository(db);
});
