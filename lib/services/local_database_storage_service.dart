import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class LocalDatabaseStorage {
  Future<Map<String, dynamic>?> loadSnapshot();
  Future<void> saveSnapshot(Map<String, Object?> snapshot);
  Future<void> clearSnapshot();
}

class SharedPreferencesLocalDatabaseStorage implements LocalDatabaseStorage {
  static const _key = 'mini_order_database_snapshot';

  @override
  Future<Map<String, dynamic>?> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      await clearSnapshot();
      return null;
    } on TypeError {
      await clearSnapshot();
      return null;
    }
  }

  @override
  Future<void> saveSnapshot(Map<String, Object?> snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(snapshot));
  }

  @override
  Future<void> clearSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
