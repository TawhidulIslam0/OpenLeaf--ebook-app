import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:iridium_reader_widget/publication.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class PersistentReaderAnnotationRepository extends ReaderAnnotationRepository {
  PersistentReaderAnnotationRepository(String bookId)
      : _bookId = bookId,
        _key =
            'openleaf.reader.annotations.${base64Url.encode(utf8.encode(bookId)).replaceAll('=', '')}';

  final String _bookId;
  final String _key;
  final List<ReaderAnnotation> _annotations = [];
  Future<void>? _loadFuture;
  Future<void> _writeQueue = Future<void>.value();

  String get _positionKey => '$_key.position';

  Future<void> _load() => _loadFuture ??= _readSavedAnnotations();

  Future<void> _readSavedAnnotations() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Saved reader annotations are invalid.');
    }
    _annotations
      ..clear()
      ..addAll(decoded.map((item) {
        if (item is! Map) {
          throw const FormatException('Saved reader annotation is invalid.');
        }
        return ReaderAnnotation.fromJson(Map<String, dynamic>.from(item));
      }));
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(_annotations.map((item) => item.toJson()).toList()),
    );
  }

  void _queuePersist() {
    _writeQueue = _writeQueue.catchError((Object error, StackTrace stackTrace) {
      debugPrint('Could not save reader annotations: $error\n$stackTrace');
    }).then((_) => _persist());
    unawaited(_writeQueue.catchError((Object error, StackTrace stackTrace) {
      debugPrint('Could not save reader annotations: $error\n$stackTrace');
    }));
  }

  @override
  Future<List<ReaderAnnotation>> allWhere({
    Predicate<ReaderAnnotation> predicate = const AcceptAllPredicate(),
  }) async {
    await _load();
    return _annotations.where(predicate.test).toList();
  }

  @override
  Future<ReaderAnnotation> createBookmark(PaginationInfo paginationInfo) async {
    await _load();
    final annotation = ReaderAnnotation(
      const Uuid().v4(),
      _bookId,
      paginationInfo.locator.json,
      AnnotationType.bookmark,
    );
    _annotations.add(annotation);
    _queuePersist();
    notifyBookmark(annotation);
    return annotation;
  }

  @override
  Future<ReaderAnnotation?> savePosition(PaginationInfo paginationInfo) async {
    final position = ReaderAnnotation(
      'position',
      _bookId,
      paginationInfo.locator.json,
      AnnotationType.bookmark,
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_positionKey, jsonEncode(position.toJson()));
    return position;
  }

  @override
  Future<ReaderAnnotation?> getPosition() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_positionKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Saved reading position is invalid.');
    }
    return ReaderAnnotation.fromJson(Map<String, dynamic>.from(decoded));
  }

  @override
  Future<ReaderAnnotation> createHighlight(
    PaginationInfo? paginationInfo,
    Locator locator,
    HighlightStyle? style,
    int? tint,
    String? annotation,
  ) async {
    await _load();
    final highlight = ReaderAnnotation(
      const Uuid().v4(),
      _bookId,
      locator.json,
      AnnotationType.highlight,
      style: style,
      tint: tint,
      annotation: annotation,
    );
    _annotations.add(highlight);
    _queuePersist();
    return highlight;
  }

  @override
  Future<ReaderAnnotation?> get(String id) async {
    await _load();
    for (final annotation in _annotations) {
      if (annotation.id == id) return annotation;
    }
    return null;
  }

  @override
  void save(ReaderAnnotation readerAnnotation) {
    unawaited(
      _saveAnnotation(readerAnnotation).catchError(
        (Object error, StackTrace stackTrace) {
          debugPrint(
              'Could not update a reader annotation: $error\n$stackTrace');
        },
      ),
    );
  }

  Future<void> _saveAnnotation(ReaderAnnotation annotation) async {
    await _load();
    final index = _annotations.indexWhere((item) => item.id == annotation.id);
    if (index == -1) {
      _annotations.add(annotation);
    } else {
      _annotations[index] = annotation;
    }
    _queuePersist();
  }

  @override
  Future<void> delete(Iterable<String> deletedIds) async {
    await _load();
    final ids = deletedIds.toSet();
    _annotations.removeWhere((annotation) => ids.contains(annotation.id));
    _queuePersist();
    super.delete(ids);
  }
}
