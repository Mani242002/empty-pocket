import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting and managing frequently used split friends / roommates
class SavedFriendsService {
  static const String _storageKey = 'saved_split_friends_list';

  Future<List<String>> getSavedFriends() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_storageKey) ?? [];
  }

  Future<void> saveFriends(List<String> friends) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, friends);
  }

  Future<List<String>> addFriend(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return await getSavedFriends();

    final current = await getSavedFriends();
    if (!current.any((f) => f.toLowerCase() == clean.toLowerCase())) {
      final updated = [...current, clean]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      await saveFriends(updated);
      return updated;
    }
    return current;
  }

  Future<List<String>> removeFriend(String name) async {
    final clean = name.trim();
    final current = await getSavedFriends();
    final updated = current.where((f) => f.toLowerCase() != clean.toLowerCase()).toList();
    await saveFriends(updated);
    return updated;
  }
}

final savedFriendsServiceProvider = Provider<SavedFriendsService>((ref) {
  return SavedFriendsService();
});

/// Riverpod notifier providing reactive state of saved split companions
class SavedFriendsNotifier extends StateNotifier<List<String>> {
  final SavedFriendsService _service;

  SavedFriendsNotifier(this._service) : super([]) {
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final list = await _service.getSavedFriends();
    state = list;
  }

  Future<void> addFriend(String name) async {
    final updated = await _service.addFriend(name);
    state = updated;
  }

  Future<void> removeFriend(String name) async {
    final updated = await _service.removeFriend(name);
    state = updated;
  }
}

final savedFriendsProvider =
    StateNotifierProvider<SavedFriendsNotifier, List<String>>((ref) {
  final service = ref.watch(savedFriendsServiceProvider);
  return SavedFriendsNotifier(service);
});
