import 'dart:async';
import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ebook_app/src/common/common.dart';
import 'package:flutter_ebook_app/src/features/features.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final exploreFeedProvider =
    FutureProvider.autoDispose<CategoryFeed>((ref) async {
  final repository = ref.watch(exploreRepositoryProvider);
  final result = await repository.getGenreFeed(popular);
  if (result.feed == null) {
    throw result.failure?.description ?? 'Could not load Explore.';
  }
  return result.feed!;
});

@RoutePage()
class ExploreScreenSmall extends ConsumerStatefulWidget {
  const ExploreScreenSmall({super.key});

  @override
  ConsumerState<ExploreScreenSmall> createState() => _ExploreScreenSmallState();
}

class _ExploreScreenSmallState extends ConsumerState<ExploreScreenSmall>
    with AutomaticKeepAliveClientMixin {
  bool _surpriseLoading = false;
  final Set<String> _prefetchedGenres = {};

  void loadData() {
    BookRepository.invalidateCache(url: popular);
    _prefetchedGenres.clear();
    final previousFeed = ref.read(exploreFeedProvider).asData?.value;
    for (final link in previousFeed?.feed?.link ?? <Link>[]) {
      final url = link.href;
      if (url == null) continue;
      BookRepository.invalidateCache(url: url);
      ref.invalidate(genreFeedNotifierProvider(url));
    }

    ref.invalidate(exploreFeedProvider);
  }

  void _prefetchGenres(List<Link> links) {
    final repository = ref.read(exploreRepositoryProvider);
    for (final link in links) {
      final url = link.href;
      if (url == null || !_prefetchedGenres.add(url)) continue;

      unawaited(
        repository.getGenreFeed(url).then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Could not prefetch Explore genre $url: $error');
            debugPrintStack(stackTrace: stackTrace);
          },
        ),
      );
    }
  }

  Future<void> _refreshExplore() async {
    loadData();
    try {
      await ref.read(exploreFeedProvider.future);
    } catch (error, stackTrace) {
      debugPrint('Could not refresh Explore: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh Explore: $error')),
        );
      }
    }
  }

  Future<void> _surpriseMe() async {
    if (_surpriseLoading) return;
    setState(() => _surpriseLoading = true);
    try {
      final page = Random().nextInt(12) + 1;
      final result = await ref.read(exploreRepositoryProvider).getGenreFeed(
            gutendexBooksUrl(sort: 'popular', page: page),
          );
      final entries = result.feed?.feed?.entry ?? [];
      if (entries.isEmpty) {
        throw result.failure?.description ??
            'No books are available on this catalog page.';
      }
      final entry = entries[Random().nextInt(entries.length)];
      if (!mounted) return;
      final id = entry.id?.t ?? 'book';
      context.router.push(
        BookDetailsRoute(
          entry: entry,
          imgTag: 'surprise-cover-$id',
          titleTag: 'surprise-title-$id',
          authorTag: 'surprise-author-$id',
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Surprise Me discovery failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not find a random book: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _surpriseLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final exploreDataState = ref.watch(exploreFeedProvider);
    return Scaffold(
      appBar: context.isSmallScreen
          ? AppBar(
              centerTitle: true,
              title: const Text('Explore'),
              actions: [
                IconButton(
                  tooltip: 'Surprise me with a book',
                  onPressed: _surpriseLoading ? null : _surpriseMe,
                  icon: _surpriseLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.shuffle),
                ),
              ],
            )
          : null,
      floatingActionButton: context.isSmallScreen
          ? null
          : FloatingActionButton.extended(
              onPressed: _surpriseLoading ? null : _surpriseMe,
              icon: const Icon(Icons.shuffle),
              label: Text(_surpriseLoading ? 'Finding a book…' : 'Surprise Me'),
            ),
      body: exploreDataState.maybeWhen(
        orElse: () => const SizedBox.shrink(),
        loading: () => const LoadingWidget(),
        data: (feeds) {
          final links = feeds.feed?.link ?? [];
          _prefetchGenres(links);
          return RefreshIndicator(
            onRefresh: _refreshExplore,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: links.length + (context.isSmallScreen ? 0 : 1),
              itemBuilder: (BuildContext context, int index) {
                if (!context.isSmallScreen && index == 0) {
                  return const SizedBox(height: 30.0);
                }
                final linkIndex = context.isSmallScreen ? index : index - 1;
                final Link link = links[linkIndex];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: _SectionBookList(link: link),
                );
              },
            ),
          );
        },
        error: (_, __) {
          return MyErrorWidget(
            refreshCallBack: () => loadData(),
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _SectionHeader extends StatelessWidget {
  final Link link;
  final bool hideSeeAll;

  const _SectionHeader({required this.link, this.hideSeeAll = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: Text(
              '${link.title}',
              style: const TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!hideSeeAll)
            GestureDetector(
              onTap: () {
                context.router.push(
                  GenreRoute(title: '${link.title}', url: link.href!),
                );
              },
              child: Text(
                'See All',
                style: TextStyle(
                  color: context.theme.colorScheme.secondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionBookList extends ConsumerStatefulWidget {
  final Link link;

  const _SectionBookList({required this.link});

  @override
  ConsumerState<_SectionBookList> createState() => _SectionBookListState();
}

class _SectionBookListState extends ConsumerState<_SectionBookList>
    with AutomaticKeepAliveClientMixin {
  final ValueNotifier<int> _bookCount = ValueNotifier<int>(0);

  void _fetch() {
    ref.read(genreFeedNotifierProvider(widget.link.href!).notifier).fetch();
  }

  @override
  void dispose() {
    _bookCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<int>(
          valueListenable: _bookCount,
          builder: (context, bookCount, _) {
            return _SectionHeader(
              link: widget.link,
              hideSeeAll: bookCount < 10,
            );
          },
        ),
        const SizedBox(height: 10.0),
        SizedBox(
          height: 200,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: ref
                .watch(genreFeedNotifierProvider(widget.link.href!))
                .maybeWhen(
                  orElse: () => const SizedBox.shrink(),
                  loading: () => const LoadingWidget(),
                  data: (data) {
                    final books = data.books;
                    if (_bookCount.value == 0) {
                      _bookCount.value = books.length;
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 15.0),
                      scrollDirection: Axis.horizontal,
                      itemCount: books.length,
                      shrinkWrap: true,
                      itemBuilder: (BuildContext context, int index) {
                        final Entry entry = books[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5.0,
                            vertical: 10.0,
                          ),
                          child:
                              BookCard(img: entry.link![1].href!, entry: entry),
                        );
                      },
                    );
                  },
                  error: (_, __) {
                    return MyErrorWidget(
                      refreshCallBack: () {
                        _fetch();
                      },
                    );
                  },
                ),
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
