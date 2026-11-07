import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ebook_app/src/common/common.dart';
import 'package:flutter_ebook_app/src/features/explore/data/repositories/explore_repository.dart';
import 'package:flutter_ebook_app/src/features/explore/presentation/ui/screens/explore_screen_small.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts every Explore genre request concurrently',
      (tester) async {
    final links = List.generate(
      10,
      (index) => Link(
        title: 'Genre $index',
        href: 'https://gutendex.com/books/?topic=genre-$index',
      ),
    );
    final repository = _ConcurrentExploreRepository(links.length);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exploreFeedProvider.overrideWith(
            (ref) async => CategoryFeed(feed: Feed(link: links)),
          ),
          exploreRepositoryProvider.overrideWith((ref) => repository),
        ],
        child: const MaterialApp(home: ExploreScreenSmall()),
      ),
    );

    for (var attempt = 0; attempt < 5; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (repository.completedRequests == links.length) break;
    }

    expect(repository.startedRequests, links.length);
    expect(repository.maximumConcurrentRequests, links.length);
  });
}

class _ConcurrentExploreRepository extends ExploreRepository {
  _ConcurrentExploreRepository(this.expectedRequests) : super(Dio());

  final int expectedRequests;
  final Completer<void> _allRequestsStarted = Completer<void>();
  int startedRequests = 0;
  int completedRequests = 0;
  int _activeRequests = 0;
  int maximumConcurrentRequests = 0;

  @override
  Future<BookRepositoryData> getGenreFeed(String url) async {
    startedRequests++;
    _activeRequests++;
    if (_activeRequests > maximumConcurrentRequests) {
      maximumConcurrentRequests = _activeRequests;
    }
    if (startedRequests == expectedRequests) {
      _allRequestsStarted.complete();
    }

    await _allRequestsStarted.future;
    _activeRequests--;
    completedRequests++;
    return (
      feed: CategoryFeed(feed: Feed(link: [], entry: [])),
      failure: null,
    );
  }
}
