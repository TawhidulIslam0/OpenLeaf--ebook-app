import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Locally stores reading history, import metadata, and the latest EPUB position.
class ReadingShelf {
  static const _key = 'openleaf.reading_history.v1';

  static Future<List<Map<String, dynamic>>> getRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Saved library data is invalid.');
    }
    return decoded.map((item) {
      if (item is! Map) {
        throw const FormatException('Saved library item is invalid.');
      }
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  static Future<void> record(
      {required String id,
      required String title,
      required String author,
      required String cover,
      required String url,
      String format = 'epub',
      String? path}) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getRecent();
    final matching = items.where((item) => item['id'] == id).toList();
    final previous = matching.isEmpty ? null : matching.first;
    final openedAt = DateTime.now();
    final now = openedAt.toIso8601String();
    final readingDays = <String>{
      if (previous?['readingDays'] is List)
        ...(previous!['readingDays'] as List).whereType<String>(),
      _dayKey(openedAt),
    };
    items.removeWhere((item) => item['id'] == id);
    items.insert(0, {
      'id': id,
      'title': title,
      'author': author,
      'cover': cover,
      'url': url,
      'format': format,
      'openedAt': now,
      'firstOpenedAt':
          previous?['firstOpenedAt'] ?? previous?['openedAt'] ?? now,
      'openCount': ((previous?['openCount'] as num?)?.toInt() ?? 0) + 1,
      'progress': previous?['progress'] ?? 0,
      'page': previous?['page'] ?? 1,
      'imported': previous?['imported'] ?? false,
      'readingDays': readingDays.toList(),
      if (path != null) 'path': path,
      if (previous?['position'] != null) 'position': previous!['position'],
    });
    await prefs.setString(_key, jsonEncode(items.take(100).toList()));
  }

  static Future<void> importBook({
    required String id,
    required String title,
    required String path,
    required String format,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getRecent();
    items.removeWhere((item) => item['id'] == id);
    items.insert(0, {
      'id': id,
      'title': title,
      'author': 'Imported book',
      'cover': '',
      'url': '',
      'path': path,
      'format': format,
      'imported': true,
      'addedAt': DateTime.now().toIso8601String(),
      'progress': 0,
      'page': 1,
      'openCount': 0,
      'readingDays': <String>[],
    });
    await prefs.setString(_key, jsonEncode(items.take(100).toList()));
  }

  static Future<void> updateProgress({
    required String id,
    required int progress,
    required String position,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getRecent();
    final index = items.indexWhere((item) => item['id'] == id);
    if (index == -1) return;
    items[index]['progress'] = progress.clamp(0, 100);
    items[index]['position'] = position;
    await prefs.setString(_key, jsonEncode(items));
  }

  static Future<void> updatePdfPage({
    required String id,
    required int page,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getRecent();
    final index = items.indexWhere((item) => item['id'] == id);
    if (index == -1) return;
    items[index]['page'] = page < 1 ? 1 : page;
    await prefs.setString(_key, jsonEncode(items));
  }

  static Future<Map<String, int>> getStatistics() async {
    final books = await getRecent();
    final readingDays = <String>{};
    var sessionCount = 0;
    var openedBooks = 0;
    var importedBooks = 0;
    for (final book in books) {
      final opens = (book['openCount'] as num?)?.toInt() ?? 1;
      sessionCount += opens;
      if (opens > 0) openedBooks++;
      if (book['imported'] == true) importedBooks++;
      final savedDays = book['readingDays'];
      if (savedDays is List) {
        readingDays.addAll(savedDays.whereType<String>());
      } else {
        final openedAt = DateTime.tryParse('${book['openedAt']}');
        if (openedAt != null) readingDays.add(_dayKey(openedAt));
      }
    }
    return {
      'books': openedBooks,
      'importedBooks': importedBooks,
      'sessions': sessionCount,
      'readingDays': readingDays.length,
    };
  }

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getRecent();
    final removed = items.where((item) => item['id'] == id).toList();
    items.removeWhere((item) => item['id'] == id);
    await prefs.setString(_key, jsonEncode(items));
    for (final item in removed) {
      final path = item['path'];
      if (item['imported'] == true && path is String) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final imports =
        (await getRecent()).where((item) => item['imported'] == true).toList();
    if (imports.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, jsonEncode(imports));
    }
  }
}
