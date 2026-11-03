import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ebook_app/src/common/common.dart';
import 'package:flutter_ebook_app/src/features/features.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class GenreScreen extends ConsumerStatefulWidget {
  final String title;
  final String url;

  const GenreScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  ConsumerState<GenreScreen> createState() => _GenreScreenState();
}

class _GenreScreenState extends ConsumerState<GenreScreen> {
  final _scrollController = ScrollController();
  int _nextPage = 2;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(paginationListener);
  }

  void paginationListener() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 300) _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    final notifier = ref.read(genreFeedNotifierProvider(widget.url).notifier);
    final page = _nextPage;
    await notifier.paginate(page);
    final result =
        ref.read(genreFeedNotifierProvider(widget.url)).asData?.value;
    if (result != null && result.paginationError == null) {
      _nextPage = page + 1;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(paginationListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final autoRouteTopRoute = context.watchRouter.currentChild;
    final canPop = context.router.canPop();

    return Scaffold(
      appBar: AppBar(
        leading: !canPop && autoRouteTopRoute?.name == 'GenreRoute'
            ? CloseButton(
                onPressed: () {
                  Navigator.pop(context);
                },
              )
            : null,
        backgroundColor: context.isSmallScreen ? null : Colors.transparent,
        centerTitle: true,
        title: Text(widget.title),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: ref.watch(genreFeedNotifierProvider(widget.url)).maybeWhen(
              orElse: () => const SizedBox.shrink(),
              loading: () => const LoadingWidget(),
              data: (data) {
                final books = data.books;
                return RefreshIndicator(
                  onRefresh: () async {
                    _nextPage = 2;
                    await ref
                        .read(genreFeedNotifierProvider(widget.url).notifier)
                        .fetch();
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    itemCount: books.length +
                        (data.loadingMore || data.paginationError != null
                            ? 1
                            : 0),
                    itemBuilder: (context, index) {
                      if (index < books.length) {
                        return Padding(
                          padding: const EdgeInsets.all(5),
                          child: BookListItem(entry: books[index]),
                        );
                      }
                      if (data.loadingMore) {
                        return const SizedBox(
                          height: 80,
                          child: LoadingWidget(),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Could not load more books: '
                              '${data.paginationError}',
                              textAlign: TextAlign.center,
                            ),
                            TextButton(
                              onPressed: _loadNextPage,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      ),
    );
  }
}
