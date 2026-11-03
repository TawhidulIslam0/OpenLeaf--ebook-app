import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Locally stores reading history, import metadata, and the latest EPUB position.
class ReadingShelf {
  static const _key = 'openleaf.reading_history.v1';
  static const _collectionsKey = 'openleaf.collections.v1';
  static const _readingTimeKey = 'openleaf.reading_time.v1';
  static const _dailyGoalKey = 'openleaf.daily_goal_minutes.v1';

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
      'status': previous?['status'] == 'wantToRead'
          ? 'currentlyReading'
          : previous?['status'] ?? 'currentlyReading',
      'collections': previous?['collections'] ?? <String>[],
      if (previous?['rating'] != null) 'rating': previous!['rating'],
      if (previous?['review'] != null) 'review': previous!['review'],
      'readingSeconds': previous?['readingSeconds'] ?? 0,
      'pagesRead': previous?['pagesRead'] ?? 0,
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
      'status': 'wantToRead',
      'collections': <String>[],
      'readingSeconds': 0,
      'pagesRead': 0,
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
    if (progress >= 100) items[index]['status'] = 'finished';
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
    final previousPage = (items[index]['page'] as num?)?.toInt() ?? 1;
    items[index]['page'] = page < 1 ? 1 : page;
    if (page > previousPage) {
      items[index]['pagesRead'] =
          ((items[index]['pagesRead'] as num?)?.toInt() ?? 0) +
              page -
              previousPage;
    }
    await prefs.setString(_key, jsonEncode(items));
  }

  static Future<List<String>> getCollections() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_collectionsKey) ?? [];
  }

  static Future<void> addCollection(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Collection names cannot be empty.');
    }
    final preferences = await SharedPreferences.getInstance();
    final collections = await getCollections();
    if (collections.any(
      (collection) => collection.toLowerCase() == normalized.toLowerCase(),
    )) {
      throw StateError('A collection with this name already exists.');
    }
    await preferences.setStringList(_collectionsKey, [
      ...collections,
      normalized,
    ]);
  }

  static Future<void> assignCollection({
    required String id,
    required String collection,
  }) async {
    final collections = await getCollections();
    if (!collections.contains(collection)) {
      throw StateError('The selected collection no longer exists.');
    }
    final preferences = await SharedPreferences.getInstance();
    final books = await getRecent();
    final index = books.indexWhere((book) => book['id'] == id);
    if (index < 0) return;
    final assigned = (books[index]['collections'] as List? ?? [])
        .whereType<String>()
        .toSet();
    assigned.add(collection);
    books[index]['collections'] = assigned.toList();
    await preferences.setString(_key, jsonEncode(books));
  }

  static Future<void> updateStatus({
    required String id,
    required String status,
  }) async {
    const statuses = {'wantToRead', 'currentlyReading', 'finished'};
    if (!statuses.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Unknown reading status.');
    }
    final preferences = await SharedPreferences.getInstance();
    final books = await getRecent();
    final index = books.indexWhere((book) => book['id'] == id);
    if (index < 0) return;
    books[index]['status'] = status;
    if (status == 'finished') books[index]['progress'] = 100;
    await preferences.setString(_key, jsonEncode(books));
  }

  static Future<void> saveReview({
    required String id,
    required int rating,
    required String review,
  }) async {
    if (rating < 1 || rating > 5) {
      throw RangeError.range(rating, 1, 5, 'rating');
    }
    final preferences = await SharedPreferences.getInstance();
    final books = await getRecent();
    final index = books.indexWhere((book) => book['id'] == id);
    if (index < 0) return;
    books[index]['rating'] = rating;
    books[index]['review'] = review.trim();
    await preferences.setString(_key, jsonEncode(books));
  }

  static Future<bool> hasDuplicate({
    required String title,
    String? author,
  }) async {
    final normalizedTitle = _normalize(title);
    final normalizedAuthor = _normalize(author ?? '');
    final books = await getRecent();
    return books.any((book) {
      if (_normalize('${book['title'] ?? ''}') != normalizedTitle) {
        return false;
      }
      return normalizedAuthor.isEmpty ||
          _normalize('${book['author'] ?? ''}') == normalizedAuthor;
    });
  }

  static Future<void> addReadingTime({
    required String id,
    required int seconds,
    DateTime? now,
  }) async {
    if (seconds <= 0) return;
    final preferences = await SharedPreferences.getInstance();
    final books = await getRecent();
    final index = books.indexWhere((book) => book['id'] == id);
    if (index >= 0) {
      books[index]['readingSeconds'] =
          ((books[index]['readingSeconds'] as num?)?.toInt() ?? 0) + seconds;
      await preferences.setString(_key, jsonEncode(books));
    }
    final activity = _readActivity(preferences.getString(_readingTimeKey));
    final day = _dayKey(now ?? DateTime.now());
    activity[day] = (activity[day] ?? 0) + seconds;
    await preferences.setString(_readingTimeKey, jsonEncode(activity));
  }

  static Future<void> setDailyGoalMinutes(int minutes) async {
    if (minutes < 1 || minutes > 1440) {
      throw RangeError.range(minutes, 1, 1440, 'minutes');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_dailyGoalKey, minutes);
  }

  static Future<Map<String, int>> getStatistics() async {
    final preferences = await SharedPreferences.getInstance();
    final books = await getRecent();
    final readingDays = <String>{};
    var sessionCount = 0;
    var openedBooks = 0;
    var importedBooks = 0;
    var completedBooks = 0;
    var readingSeconds = 0;
    var pagesRead = 0;
    for (final book in books) {
      final opens = (book['openCount'] as num?)?.toInt() ?? 1;
      sessionCount += opens;
      if (opens > 0) openedBooks++;
      if (book['imported'] == true) importedBooks++;
      if (book['status'] == 'finished' ||
          ((book['progress'] as num?)?.toInt() ?? 0) >= 100) {
        completedBooks++;
      }
      readingSeconds += (book['readingSeconds'] as num?)?.toInt() ?? 0;
      pagesRead += (book['pagesRead'] as num?)?.toInt() ?? 0;
      final savedDays = book['readingDays'];
      if (savedDays is List) {
        readingDays.addAll(savedDays.whereType<String>());
      } else {
        final openedAt = DateTime.tryParse('${book['openedAt']}');
        if (openedAt != null) readingDays.add(_dayKey(openedAt));
      }
    }
    final activity = _readActivity(preferences.getString(_readingTimeKey));
    final today = DateTime.now();
    final todayKey = _dayKey(today);
    final activityDays = activity.keys.toSet();
    var streakDays = 0;
    for (var offset = 0;; offset++) {
      final date = DateTime(today.year, today.month, today.day - offset);
      if (!activityDays.contains(_dayKey(date))) break;
      streakDays++;
    }
    final weekStart =
        DateTime(today.year, today.month, today.day - (today.weekday - 1));
    final weeklySeconds = activity.entries.where((entry) {
      final date = DateTime.tryParse(entry.key);
      return date != null && !date.isBefore(weekStart);
    }).fold<int>(0, (total, entry) => total + entry.value);
    final monthlySeconds = activity.entries.where((entry) {
      final date = DateTime.tryParse(entry.key);
      return date != null &&
          date.year == today.year &&
          date.month == today.month;
    }).fold<int>(0, (total, entry) => total + entry.value);
    return {
      'books': openedBooks,
      'importedBooks': importedBooks,
      'sessions': sessionCount,
      'readingDays': readingDays.length,
      'completedBooks': completedBooks,
      'readingSeconds': readingSeconds,
      'pagesRead': pagesRead,
      'dailyGoalMinutes': preferences.getInt(_dailyGoalKey) ?? 20,
      'todaySeconds': activity[todayKey] ?? 0,
      'streakDays': streakDays,
      'weeklySeconds': weeklySeconds,
      'monthlySeconds': monthlySeconds,
    };
  }

  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static Map<String, int> _readActivity(String? raw) {
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Saved reading activity is invalid.');
    }
    return decoded.map((key, value) {
      if (key is! String || value is! num) {
        throw const FormatException('Saved reading activity is invalid.');
      }
      return MapEntry(key, value.toInt());
    });
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

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
