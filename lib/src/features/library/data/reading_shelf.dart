import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local reading history. This records books the reader has opened;
/// it deliberately does not pretend to know an EPUB's internal page position.
class ReadingShelf {
  static const _key = 'openleaf.reading_history.v1';

  static Future<List<Map<String, dynamic>>> getRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> record({required String id, required String title,
    required String author, required String cover, required String url}) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getRecent();
    items.removeWhere((item) => item['id'] == id);
    items.insert(0, {
      'id': id, 'title': title, 'author': author, 'cover': cover,
      'url': url, 'openedAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_key, jsonEncode(items.take(100).toList()));
  }

  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getRecent();
    items.removeWhere((item) => item['id'] == id);
    await prefs.setString(_key, jsonEncode(items));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
