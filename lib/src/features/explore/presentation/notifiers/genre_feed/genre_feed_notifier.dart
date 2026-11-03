import 'dart:async';

import 'package:flutter_ebook_app/src/common/common.dart';
import 'package:flutter_ebook_app/src/features/features.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'genre_feed_notifier.g.dart';

typedef GenreFeedData = ({
  List<Entry> books,
  bool loadingMore,
  bool hasMore,
  String? paginationError,
});

@riverpod
class GenreFeedNotifier extends _$GenreFeedNotifier {
  GenreFeedNotifier() : super();

  late ExploreRepository _exploreRepository;
  late String _url;
  final Set<int> _loadedPages = {1};

  @override
  Future<GenreFeedData> build(String url) async {
    _exploreRepository = ref.read(exploreRepositoryProvider);
    _url = url;
    final books = await _fetch();
    return (
      books: books,
      loadingMore: false,
      hasMore: books.isNotEmpty,
      paginationError: null,
    );
  }

  Future<void> fetch() async {
    BookRepository.invalidateCache(url: _url);
    _loadedPages
      ..clear()
      ..add(1);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async {
        final books = await _fetch();
        return (
          books: books,
          loadingMore: false,
          hasMore: books.isNotEmpty,
          paginationError: null,
        );
      },
    );
  }

  Future<List<Entry>> _fetch() async {
    final successOrFailure = await _exploreRepository.getGenreFeed(_url);
    final success = successOrFailure.feed;
    final failure = successOrFailure.failure;
    if (success == null) {
      throw failure?.description ?? '';
    }
    return success.feed?.entry ?? [];
  }

  Future<void> paginate(int page) async {
    final current = state.asData?.value;
    if (current == null ||
        current.loadingMore ||
        !current.hasMore ||
        _loadedPages.contains(page)) {
      return;
    }

    state = AsyncValue.data((
      books: current.books,
      loadingMore: true,
      hasMore: current.hasMore,
      paginationError: null,
    ));
    try {
      final result = await _exploreRepository.getGenreFeed('$_url&page=$page');
      if (result.feed == null) {
        throw result.failure?.description ?? 'Could not load more books.';
      }
      final additions = result.feed?.feed?.entry ?? [];
      final ids = current.books.map((book) => book.id?.t).toSet();
      final books = [
        ...current.books,
        ...additions.where((book) => ids.add(book.id?.t)),
      ];
      _loadedPages.add(page);
      state = AsyncValue.data((
        books: books,
        loadingMore: false,
        hasMore: additions.isNotEmpty,
        paginationError: null,
      ));
    } catch (error, stackTrace) {
      state = AsyncValue.data((
        books: current.books,
        loadingMore: false,
        hasMore: true,
        paginationError: error.toString(),
      ));
      debugPrint('Could not load genre page $page for $_url: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
