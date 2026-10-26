import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_ebook_app/src/common/common.dart';

typedef BookRepositoryData = ({CategoryFeed? feed, HttpFailure? failure});

class _CachedBookFeed {
  final BookRepositoryData data;
  final DateTime cachedAt;

  const _CachedBookFeed(this.data, this.cachedAt);
}

abstract class BookRepository {
  static const _cacheDuration = Duration(minutes: 5);
  static const _maximumCachedFeeds = 50;
  static final Map<String, _CachedBookFeed> _feedCache = {};
  static final Map<String, Future<BookRepositoryData>> _pendingRequests = {};

  final Dio httpClient;

  const BookRepository(this.httpClient);

  Future<BookRepositoryData> getCategory(String url) async {
    final cached = _feedCache.remove(url);
    if (cached != null &&
        DateTime.now().difference(cached.cachedAt) < _cacheDuration) {
      _feedCache[url] = cached;
      return cached.data;
    }

    final pendingRequest = _pendingRequests[url];
    if (pendingRequest != null) {
      return pendingRequest;
    }

    final request = _fetchCategory(url);
    _pendingRequests[url] = request;
    try {
      final result = await request;
      if (result.feed != null) {
        _feedCache[url] = _CachedBookFeed(result, DateTime.now());
        while (_feedCache.length > _maximumCachedFeeds) {
          _feedCache.remove(_feedCache.keys.first);
        }
      }
      return result;
    } finally {
      if (identical(_pendingRequests[url], request)) {
        _pendingRequests.remove(url);
      }
    }
  }

  Future<BookRepositoryData> _fetchCategory(String url) async {
    try {
      final res = await httpClient.get(url);
      final Object? decoded =
          res.data is String ? jsonDecode(res.data as String) : res.data;
      if (decoded is! Map) {
        throw const FormatException('Gutendex returned an invalid response.');
      }

      final results = decoded['results'];
      if (results is! List) {
        throw const FormatException('Gutendex response has no book results.');
      }

      final entries = results
          .whereType<Map>()
          .map((book) {
            return Map<String, dynamic>.from(book);
          })
          .where((book) {
            final formats = book['formats'];
            return formats is Map && formats['application/epub+zip'] is String;
          })
          .map(_toEntry)
          .toList();

      return (
        feed: CategoryFeed(
          feed: Feed(
            link: _genreLinks(),
            entry: entries,
          ),
        ),
        failure: null,
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode ?? 500;
      if (statusCode == 404) {
        return (feed: null, failure: HttpFailure.notFound);
      }
      return (feed: null, failure: HttpFailure.unknown);
    }
  }

  Entry _toEntry(Map<String, dynamic> book) {
    final id = book['id'].toString();
    final title = book['title'] as String? ?? 'Untitled';
    final authors = book['authors'];
    final author = authors is List && authors.isNotEmpty
        ? authors.first as Map<String, dynamic>
        : <String, dynamic>{};
    final authorName = author['name'] as String? ?? 'Unknown author';
    final formats = book['formats'] as Map<String, dynamic>? ?? {};
    final epubUrl = formats['application/epub+zip'] as String?;
    if (epubUrl == null) {
      throw FormatException('Book $id has no EPUB download.');
    }

    final summaries = book['summaries'];
    final subjects = book['subjects'];
    final bookshelves = book['bookshelves'];
    final description = summaries is List
        ? summaries.whereType<String>().firstWhere(
              (summary) => summary.trim().isNotEmpty,
              orElse: () => '',
            )
        : '';
    final summary = description.isNotEmpty
        ? description
        : _catalogDescription(
            authorName: authorName,
            subjects: subjects,
            bookshelves: bookshelves,
          );
    final categories = subjects is List
        ? subjects.whereType<String>().take(5).map(
              (subject) => Category(label: subject),
            )
        : <Category>[];
    final coverUrl = formats['image/jpeg'] as String? ??
        'https://www.gutenberg.org/cache/epub/$id/pg$id.cover.medium.jpg';

    return Entry(
      id: Id(t: id),
      title: Id(t: title),
      author: Author1(
        name: Id(t: authorName),
        uri: Id(t: gutendexBooksUrl(search: authorName)),
      ),
      summary: Id(t: summary),
      category: categories.toList(),
      link: [
        Link1(rel: 'self', href: 'https://gutendex.com/books/$id/'),
        Link1(rel: 'cover', type: 'image/jpeg', href: coverUrl),
        Link1(
          rel: 'alternate',
          href: 'https://www.gutenberg.org/ebooks/$id',
        ),
        Link1(rel: 'download', type: 'application/epub+zip', href: epubUrl),
      ],
    );
  }

  String _catalogDescription({
    required String authorName,
    required Object? subjects,
    required Object? bookshelves,
  }) {
    final labels = <String>{
      if (subjects is List) ...subjects.whereType<String>(),
      if (bookshelves is List) ...bookshelves.whereType<String>(),
    }.take(5).toList();
    if (labels.isEmpty) {
      return 'A public-domain ebook by $authorName, available from Project '
          'Gutenberg.';
    }
    return 'A public-domain ebook by $authorName. Catalog subjects: '
        '${labels.join(', ')}.';
  }

  List<Link> _genreLinks() => [
        Link(title: 'Short Stories', href: shortStory),
        Link(title: 'Science Fiction', href: sciFi),
        Link(title: 'Adventure', href: actionAdventure),
        Link(title: 'Mystery', href: mystery),
        Link(title: 'Romance', href: romance),
        Link(title: 'Horror', href: horror),
        Link(title: 'History', href: history),
        Link(title: 'Poetry', href: poetry),
        Link(title: 'Children', href: children),
        Link(title: 'Drama', href: drama),
      ];
}
