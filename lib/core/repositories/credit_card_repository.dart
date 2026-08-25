import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../domain/entities/credit_card_entity.dart';
import 'transaction_repository.dart';

abstract class CreditCardRepository {
  Future<List<CreditCardEntity>> getAllCards();
  Future<CreditCardEntity?> getCardById(String id);
  Future<void> saveCard(CreditCardEntity card);
  Future<void> updateCard(CreditCardEntity card);
  Future<void> deleteCard(String id);
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
  Future<void> saveCard(CreditCardEntity card) async {
    await _db.insertCreditCard(card);
  }

  @override
  Future<void> updateCard(CreditCardEntity card) async {
    await _db.updateCreditCard(card);
  }

  @override
  Future<void> deleteCard(String id) async {
    await _db.deleteCreditCard(id);
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
  Future<void> saveCard(CreditCardEntity card) async {
    _cards.removeWhere((c) => c.id == card.id);
    _cards.add(card);
  }

  @override
  Future<void> updateCard(CreditCardEntity card) async {
    final index = _cards.indexWhere((c) => c.id == card.id);
    if (index != -1) {
      _cards[index] = card;
    } else {
      _cards.add(card);
    }
  }

  @override
  Future<void> deleteCard(String id) async {
    _cards.removeWhere((c) => c.id == id);
  }
}

/// Credit Card Repository Provider
final creditCardRepositoryProvider = Provider<CreditCardRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SqliteCreditCardRepository(db);
});
