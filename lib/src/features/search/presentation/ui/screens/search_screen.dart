import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ebook_app/src/common/constants/api.dart';
import 'package:flutter_ebook_app/src/common/domain/models/category_feed.dart';
import 'package:flutter_ebook_app/src/features/book_details/presentation/ui/screens/book_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _maximumSearchResults = 500;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );
  final Duration _debounceDuration = const Duration(milliseconds: 300);
  List<Entry> _results = [];
  Timer? _debounce;
  CancelToken? _activeRequest;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _searchCompleted = false;
  String? _error;
  String _sort = 'popular';
  String _language = 'en';
  int _requestId = 0;
  int _nextPage = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNearEnd);
  }

  void _loadMoreWhenNearEnd() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 500) {
      _loadNextPage();
    }
  }

  void _loadNextPage() {
    if (!_hasMore || _loading || _loadingMore) return;
    unawaited(_search(_controller.text, _nextPage));
  }

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    _activeRequest?.cancel('Search query changed.');
    _activeRequest = null;
    _requestId++;
    _nextPage = 1;
    _hasMore = false;
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _error = null;
      _loading = false;
      _results = [];
      _searchCompleted = false;
    });
    _debounce = Timer(_debounceDuration, () => _search(query));
  }

  Future<void> _search([String? value, int page = 1]) async {
    _debounce?.cancel();
    final query = (value ?? _controller.text).trim();
    if (query.isEmpty) return;
    if (page == 1) {
      _nextPage = 1;
      _hasMore = false;
    }

    _activeRequest?.cancel('Search query changed.');
    final cancelToken = CancelToken();
    _activeRequest = cancelToken;
    final requestId = ++_requestId;
    setState(() {
      _loading = page == 1;
      _loadingMore = page > 1;
      _error = null;
    });

    try {
      final response = await _dio.get(
        'https://gutendex.com/books/',
        cancelToken: cancelToken,
        queryParameters: {
          'search': normalizeGutendexSearchQuery(query),
          'mime_type': 'application/epub+zip',
          if (_language.isNotEmpty) 'languages': _language,
          'copyright': 'false',
          'sort': _sort == 'newest' ? 'descending' : 'popular',
          'page': page,
        },
      );
      final data = response.data;
      if (data is! Map || data['results'] is! List) {
        throw const FormatException(
          'The catalog returned invalid search data.',
        );
      }
      final raw = data['results'] as List;
      final results = page == 1 ? <Entry>[] : List<Entry>.from(_results);
      for (final item in raw.whereType<Map>()) {
        final book = Map<String, dynamic>.from(item);
        final formats = book['formats'];
        if (formats is! Map) continue;
        final epub = formats['application/epub+zip'];
        if (epub is! String) continue;

        final id = '${book['id']}';
        final authors = book['authors'];
        final author =
            authors is List && authors.isNotEmpty && authors.first is Map
                ? authors.first as Map
                : <String, dynamic>{};
        final authorName = '${author['name'] ?? 'Unknown author'}';
        final subjects = book['subjects'];
        final cover = formats['image/jpeg'] ??
            'https://www.gutenberg.org/cache/epub/$id/pg$id.cover.medium.jpg';
        final summaries = book['summaries'];
        final entry = Entry(
          id: Id(t: id),
          title: Id(t: '${book['title'] ?? 'Untitled'}'),
          author: Author1(
            name: Id(t: authorName),
            uri: Id(t: gutendexBooksUrl(search: authorName)),
          ),
          summary: Id(
            t: summaries is List && summaries.isNotEmpty
                ? '${summaries.first}'
                : 'A public-domain ebook available from Project Gutenberg.',
          ),
          category: subjects is List
              ? subjects
                  .whereType<String>()
                  .take(5)
                  .map((subject) => Category(label: subject))
                  .toList()
              : [],
          link: [
            Link1(rel: 'self', href: 'https://gutendex.com/books/$id/'),
            Link1(rel: 'cover', href: '$cover'),
            Link1(
              rel: 'alternate',
              href: 'https://www.gutenberg.org/ebooks/$id',
            ),
            Link1(
              rel: 'download',
              type: 'application/epub+zip',
              href: epub,
            ),
          ],
        );
        if (!results.any((existing) => existing.id?.t == id)) {
          results.add(entry);
        }
      }

      final hasNextPage = data['next'] is String;
      if (!mounted || requestId != _requestId) return;
      if (results.length > _maximumSearchResults) {
        results.removeRange(_maximumSearchResults, results.length);
      }
      _hasMore = hasNextPage && results.length < _maximumSearchResults;
      _nextPage = hasNextPage ? page + 1 : page;
      if (_sort == 'title') {
        results.sort(
          (a, b) => (a.title?.t ?? '')
              .toLowerCase()
              .compareTo((b.title?.t ?? '').toLowerCase()),
        );
      }
      if (mounted && requestId == _requestId) {
        setState(() {
          _results = results;
          _searchCompleted = true;
        });
      }
    } on DioException catch (error) {
      if (error.type != DioExceptionType.cancel &&
          mounted &&
          requestId == _requestId) {
        setState(() => _error = _errorMessage(error));
      }
    } catch (error, stackTrace) {
      debugPrint('Catalog search failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted && requestId == _requestId) {
        setState(
          () => _error =
              'Could not search the catalog. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  String _errorMessage(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'The catalog did not respond within 12 seconds. Check your '
          'internet connection and retry.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Could not connect to the book catalog. Check your internet '
          'connection and retry.';
    }
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      return 'The catalog returned HTTP $statusCode. Retry in a moment.';
    }
    return 'Could not search the catalog. Check your connection and try again.';
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreWhenNearEnd)
      ..dispose();
    _debounce?.cancel();
    _activeRequest?.cancel('Search screen closed.');
    _controller.dispose();
    _dio.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Find your next read')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onChanged: _scheduleSearch,
                onSubmitted: (value) => _search(value),
                decoration: InputDecoration(
                  hintText: 'Search titles, authors, subjects…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _scheduleSearch('');
                    },
                  ),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Sort'),
                  DropdownButton<String>(
                    value: _sort,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: 'popular',
                        child: Text('Popular'),
                      ),
                      DropdownMenuItem(value: 'title', child: Text('Title')),
                      DropdownMenuItem(value: 'newest', child: Text('Newest')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _sort = value);
                      if (_controller.text.trim().isNotEmpty) _search();
                    },
                  ),
                  const Text('Language'),
                  DropdownButton<String>(
                    value: _language,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'fr', child: Text('French')),
                      DropdownMenuItem(value: 'es', child: Text('Spanish')),
                      DropdownMenuItem(value: 'de', child: Text('German')),
                      DropdownMenuItem(value: '', child: Text('Any')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _language = value);
                      if (_controller.text.trim().isNotEmpty) _search();
                    },
                  ),
                  if (_controller.text.trim().isNotEmpty)
                    Text(
                      _error != null
                          ? 'Unavailable'
                          : !_searchCompleted
                              ? 'Searching…'
                              : '${_results.length} results',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _buildResults(context)),
          ],
        ),
      );

  Widget _buildResults(BuildContext context) {
    if (_error != null && _results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _search(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry search'),
              ),
            ],
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.travel_explore, size: 56),
              const SizedBox(height: 14),
              Text(
                _controller.text.trim().isEmpty
                    ? 'Search the library'
                    : 'No books found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Find public-domain books by title, author, or subject.',
                textAlign: TextAlign.center,
              ),
              if (_controller.text.trim().isEmpty) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () {
                    _controller.text = 'science fiction';
                    _search('science fiction');
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Explore science fiction'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _results.length + (_hasMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= _results.length) {
                return Center(
                  child: _loadingMore
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        )
                      : TextButton(
                          onPressed: _loadNextPage,
                          child: const Text('Load more books'),
                        ),
                );
              }
              final entry = _results[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(
                      entry.link![1].href!,
                      width: 58,
                      height: 82,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 58,
                        height: 82,
                        child: Icon(Icons.menu_book),
                      ),
                    ),
                  ),
                  title: Text(
                    entry.title?.t ?? 'Untitled',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    entry.author?.name?.t ?? 'Unknown author',
                    maxLines: 2,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookDetailsScreen(
                        entry: entry,
                        imgTag: 'search-cover-${entry.id?.t}',
                        titleTag: 'search-title-${entry.id?.t}',
                        authorTag: 'search-author-${entry.id?.t}',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
