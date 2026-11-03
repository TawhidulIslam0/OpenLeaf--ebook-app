import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ebook_app/src/common/common.dart';
import 'package:flutter_ebook_app/src/features/book_details/presentation/ui/screens/read_book_screen.dart';
import 'package:flutter_ebook_app/src/features/library/data/epub_cache.dart';
import 'package:flutter_ebook_app/src/features/library/data/reading_shelf.dart';
import 'package:flutter_ebook_app/src/features/library/presentation/ui/screens/epub_reader_screen.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.isSmallScreen ? null : Colors.transparent,
        centerTitle: true,
        title: const Text('Downloads'),
        actions: [
          IconButton(
            tooltip: 'Manage storage',
            onPressed: downloads.asData == null
                ? null
                : () => _manageStorage(
                      context,
                      downloads.asData!.value,
                    ),
            icon: const Icon(Icons.storage_outlined),
          ),
        ],
      ),
      body: downloads.maybeWhen(
        orElse: () => const EmptyView(),
        data: (books) {
          if (books.isEmpty) return const EmptyView();
          return ListView.separated(
            shrinkWrap: true,
            itemCount: books.length,
            itemBuilder: (BuildContext context, int index) {
              final book = books[index];

              return Dismissible(
                key: ValueKey<String>(book['id'] as String),
                direction: DismissDirection.endToStart,
                background: const _DismissibleBackground(),
                confirmDismiss: (_) async {
                  final shouldRemove = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Remove download?'),
                      content: const Text(
                        'This deletes the downloaded file and its '
                        'download entry. Your library and reading history '
                        'will remain.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  );
                  if (shouldRemove != true || !context.mounted) {
                    return false;
                  }
                  try {
                    await epubCache.delete(book['id'] as String);
                    await ref
                        .read(downloadsNotifierProvider.notifier)
                        .deleteBook(book['id'] as String);
                    return true;
                  } catch (error, stackTrace) {
                    debugPrint(
                      'Could not remove downloaded book: '
                      '$error\n$stackTrace',
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not remove download: $error'),
                        ),
                      );
                    }
                    return false;
                  }
                },
                child: InkWell(
                  onTap: () async {
                    final path = book['path'] as String;
                    final bookFile = File(path);
                    if (await bookFile.exists() &&
                        await epubCache.isValidFile(bookFile)) {
                      await ReadingShelf.record(
                        id: book['id'] as String,
                        title: book['name'] as String,
                        author: book['author'] as String? ?? 'Unknown author',
                        cover: book['image'] as String,
                        url: book['url'] as String? ?? '',
                        path: path,
                      );
                      if (!context.mounted) return;
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => EpubReaderScreen(
                            bookId: book['id'] as String,
                            filePath: path,
                          ),
                        ),
                      );
                    } else {
                      if (!context.mounted) return;
                      final id = book['id'] as String;
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ReadBookScreen(
                            id: id,
                            title: book['name'] as String,
                            author:
                                book['author'] as String? ?? 'Unknown author',
                            url: book['url'] as String? ??
                                'https://www.gutenberg.org/ebooks/$id.epub.images',
                            cover: book['image'] as String?,
                          ),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 15,
                    ),
                    child: Row(
                      children: <Widget>[
                        BookCover(
                          bookId: book['id'] as String,
                          title: book['name'] as String,
                          imageUrl: book['image'] as String,
                          height: 70.0,
                          width: 70.0,
                        ),
                        const SizedBox(width: 10.0),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                book['name'] as String,
                                style: const TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Text(
                                    'COMPLETED',
                                    style: TextStyle(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          context.theme.colorScheme.secondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    book['size'] as String,
                                    style: const TextStyle(
                                      fontSize: 13.0,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (BuildContext context, int index) {
              return const Divider();
            },
          );
        },
      ),
    );
  }

  Future<void> _manageStorage(
    BuildContext context,
    List<Map<String, dynamic>> books,
  ) async {
    final cachedBooks = <({Map<String, dynamic> book, int bytes})>[];
    for (final book in books) {
      final file = await epubCache.fileFor(book['id'] as String);
      if (await file.exists()) {
        cachedBooks.add((book: book, bytes: await file.length()));
      }
    }
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final totalBytes =
              cachedBooks.fold<int>(0, (total, book) => total + book.bytes);
          return AlertDialog(
            title: const Text('Downloaded storage'),
            content: SizedBox(
              width: 420,
              child: cachedBooks.isEmpty
                  ? const Text('No downloaded books are stored on this device.')
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Total: ${formatBytes(totalBytes, 1)}'),
                        const SizedBox(height: 8),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: cachedBooks.length,
                            itemBuilder: (context, index) {
                              final item = cachedBooks[index];
                              final book = item.book;
                              return ListTile(
                                title: Text(
                                  book['name'] as String? ?? 'Untitled',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(formatBytes(item.bytes, 1)),
                                trailing: IconButton(
                                  tooltip: 'Delete downloaded file',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    try {
                                      await epubCache.delete(
                                        book['id'] as String,
                                      );
                                      setDialogState(
                                        () => cachedBooks.removeAt(index),
                                      );
                                    } catch (error, stackTrace) {
                                      debugPrint(
                                        'Could not delete downloaded file: '
                                        '$error\n$stackTrace',
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not delete this file: '
                                              '$error',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Deleting a file keeps its library and download '
                          'details. It can be downloaded again later.',
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DismissibleBackground extends StatelessWidget {
  const _DismissibleBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20.0),
      color: Colors.red,
      child: const Icon(Feather.trash_2, color: Colors.white),
    );
  }
}
