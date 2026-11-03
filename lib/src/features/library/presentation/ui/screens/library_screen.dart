import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ebook_app/src/features/book_details/presentation/ui/screens/read_book_screen.dart';
import 'package:flutter_ebook_app/src/features/library/data/epub_cache.dart';
import 'package:flutter_ebook_app/src/features/library/data/reading_shelf.dart';
import 'package:flutter_ebook_app/src/features/library/presentation/ui/screens/pdf_reader_screen.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<List<Map<String, dynamic>>> _books;
  late Future<Map<String, int>> _statistics;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _books = ReadingShelf.getRecent();
    _statistics = ReadingShelf.getStatistics();
  }

  Future<void> _importBook() async {
    try {
      final selection = await FilePicker.pickFiles(
        dialogTitle: 'Import an EPUB or PDF',
        type: FileType.custom,
        allowedExtensions: const ['epub', 'pdf'],
      );
      if (selection.isEmpty) return;
      final picked = selection.first;
      final sourcePath = picked.path;
      if (sourcePath == null) {
        throw const FileSystemException(
          'This platform did not provide a local file path.',
        );
      }

      final extension = path.extension(picked.name).toLowerCase();
      if (extension != '.epub' && extension != '.pdf') {
        throw const FormatException('Choose an EPUB or PDF file.');
      }
      final source = File(sourcePath);
      if (!await _isSupportedBook(source, extension)) {
        throw const FormatException(
          'The selected file is not a valid EPUB or PDF.',
        );
      }

      final duplicate = await ReadingShelf.hasDuplicate(
        title: path.basenameWithoutExtension(picked.name),
      );
      if (!mounted) return;
      if (duplicate) {
        final importDuplicate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Possible duplicate'),
            content: const Text(
              'A book with this title is already in your library. Import '
              'another copy anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Import anyway'),
              ),
            ],
          ),
        );
        if (importDuplicate != true) return;
      }

      setState(() => _importing = true);
      final id = 'import-${const Uuid().v4()}';
      final supportDirectory = await getApplicationSupportDirectory();
      final importDirectory = Directory(
        path.join(supportDirectory.path, 'openleaf', 'imports'),
      );
      await importDirectory.create(recursive: true);
      final destination = await source.copy(
        path.join(importDirectory.path, '$id$extension'),
      );
      await ReadingShelf.importBook(
        id: id,
        title: path.basenameWithoutExtension(picked.name),
        path: destination.path,
        format: extension.substring(1),
      );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Book imported to your library.')),
      );
    } catch (error, stackTrace) {
      debugPrint('Could not import a book: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not import this book: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<bool> _isSupportedBook(File file, String extension) async {
    if (!await file.exists() || await file.length() < 4) return false;
    if (extension == '.epub') return epubCache.isValidFile(file);
    final handle = await file.open();
    try {
      final signature = await handle.read(4);
      if (extension == '.pdf') {
        return signature.length == 4 &&
            signature[0] == 0x25 &&
            signature[1] == 0x50 &&
            signature[2] == 0x44 &&
            signature[3] == 0x46;
      }
      return signature.length == 4 &&
          signature[0] == 0x50 &&
          signature[1] == 0x4b;
    } finally {
      await handle.close();
    }
  }

  Future<void> _openBook(Map<String, dynamic> book) async {
    final id = '${book['id']}';
    final title = '${book['title'] ?? 'Untitled'}';
    final author = '${book['author'] ?? 'Unknown author'}';
    final cover = '${book['cover'] ?? ''}';
    final bookPath = book['path'] is String ? book['path'] as String : null;
    final format = '${book['format'] ?? 'epub'}';

    if (format == 'pdf') {
      if (bookPath == null || !await File(bookPath).exists()) {
        _showMissingBookMessage();
        return;
      }
      await ReadingShelf.record(
        id: id,
        title: title,
        author: author,
        cover: cover,
        url: '',
        format: 'pdf',
        path: bookPath,
      );
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PdfReaderScreen(
            bookId: id,
            path: bookPath,
            title: title,
            initialPageNumber: (book['page'] as num?)?.toInt() ?? 1,
          ),
        ),
      );
      if (mounted) setState(_reload);
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReadBookScreen(
          id: id,
          title: title,
          author: author,
          url: '${book['url'] ?? ''}',
          cover: cover,
          localPath: book['imported'] == true ? bookPath : null,
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  void _showMissingBookMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('The book file is missing. Import it again.')),
    );
  }

  Future<void> _clearHistory() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear reading history?'),
        content: const Text(
          'This removes your recently opened books. Imported books will remain in your library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (shouldClear == true) {
      await ReadingShelf.clear();
      if (mounted) setState(_reload);
    }
  }

  Future<void> _removeBook(Map<String, dynamic> book) async {
    await ReadingShelf.remove('${book['id']}');
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('My Library'),
          actions: [
            IconButton(
              tooltip: 'Import EPUB or PDF',
              onPressed: _importing ? null : _importBook,
              icon: const Icon(Icons.file_upload_outlined),
            ),
            IconButton(
              tooltip: 'Clear reading history',
              onPressed: _clearHistory,
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              tooltip: 'Manage collections',
              onPressed: _manageCollections,
              icon: const Icon(Icons.collections_bookmark_outlined),
            ),
          ],
        ),
        body: _importing
            ? const LinearProgressIndicator()
            : FutureBuilder<List<Map<String, dynamic>>>(
                future: _books,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Could not load your library. Please try again.',
                      ),
                    );
                  }

                  final books = snapshot.data ?? [];
                  if (books.isEmpty) return _buildEmptyState(context);
                  final continuing = books.where((book) {
                    final status = book['status'] ?? 'currentlyReading';
                    return status == 'currentlyReading' &&
                        ((book['openCount'] as num?)?.toInt() ?? 1) > 0;
                  }).toList();
                  final wantToRead = books
                      .where((book) => book['status'] == 'wantToRead')
                      .toList();
                  final finished = books
                      .where((book) => book['status'] == 'finished')
                      .toList();

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStatistics(),
                      if (continuing.isNotEmpty) ...[
                        _SectionHeading(
                          title: 'Continue Reading',
                          subtitle: 'Pick up where you left off',
                        ),
                        for (final book in continuing) _bookTile(book),
                      ],
                      if (wantToRead.isNotEmpty) ...[
                        _SectionHeading(
                          title: 'Want to Read',
                          subtitle: 'Saved for a future reading session',
                        ),
                        for (final book in wantToRead) _bookTile(book),
                      ],
                      if (finished.isNotEmpty) ...[
                        _SectionHeading(
                          title: 'Finished',
                          subtitle: 'Books you have completed',
                        ),
                        for (final book in finished) _bookTile(book),
                      ],
                    ],
                  );
                },
              ),
      );

  Widget _buildStatistics() => FutureBuilder<Map<String, int>>(
        future: _statistics,
        builder: (context, snapshot) {
          final stats = snapshot.data;
          final goalMinutes = stats?['dailyGoalMinutes'] ?? 20;
          final todaySeconds = stats?['todaySeconds'] ?? 0;
          final goalProgress =
              (todaySeconds / (goalMinutes * 60)).clamp(0, 1).toDouble();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceAround,
                    runSpacing: 16,
                    children: [
                      _Statistic(
                        label: 'Books opened',
                        value: '${stats?['books'] ?? 0}',
                        icon: Icons.menu_book_outlined,
                      ),
                      _Statistic(
                        label: 'Finished',
                        value: '${stats?['completedBooks'] ?? 0}',
                        icon: Icons.check_circle_outline,
                      ),
                      _Statistic(
                        label: 'Reading streak',
                        value: '${stats?['streakDays'] ?? 0} days',
                        icon: Icons.local_fire_department_outlined,
                      ),
                      _Statistic(
                        label: 'Pages read',
                        value: '${stats?['pagesRead'] ?? 0}',
                        icon: Icons.auto_stories_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Text("Today's reading goal")),
                      TextButton(
                        onPressed: () => _editDailyGoal(goalMinutes),
                        child: Text('$goalMinutes min'),
                      ),
                    ],
                  ),
                  LinearProgressIndicator(value: goalProgress),
                  const SizedBox(height: 4),
                  Text(
                    '${todaySeconds ~/ 60} of $goalMinutes minutes · '
                    '${(stats?['readingSeconds'] ?? 0) ~/ 60} minutes total · '
                    '${(stats?['weeklySeconds'] ?? 0) ~/ 60} this week',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );

  Future<void> _editDailyGoal(int currentMinutes) async {
    final controller = TextEditingController(text: '$currentMinutes');
    try {
      final minutes = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Daily reading goal'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minutes per day',
              helperText: 'Choose between 1 and 1440 minutes.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value == null || value < 1 || value > 1440) return;
                Navigator.pop(context, value);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (minutes == null) return;
      await ReadingShelf.setDailyGoalMinutes(minutes);
      if (mounted) setState(_reload);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _manageCollections() async {
    final controller = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create a collection'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Collection name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Create'),
            ),
          ],
        ),
      );
      if (name == null) return;
      await ReadingShelf.addCollection(name);
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collection created.')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Could not create collection: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create collection: $error')),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _assignCollection(Map<String, dynamic> book) async {
    final collections = await ReadingShelf.getCollections();
    if (!mounted) return;
    if (collections.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Create a collection first using the bookmark icon.'),
          ),
        );
      }
      return;
    }
    var selected = collections.first;
    final collection = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add to a collection'),
          content: DropdownButton<String>(
            value: selected,
            isExpanded: true,
            items: collections
                .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                .toList(),
            onChanged: (value) {
              if (value != null) setDialogState(() => selected = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (collection == null) return;
    await ReadingShelf.assignCollection(
      id: '${book['id']}',
      collection: collection,
    );
    if (mounted) setState(_reload);
  }

  Future<void> _editReview(Map<String, dynamic> book) async {
    final controller = TextEditingController(
      text: '${book['review'] ?? ''}',
    );
    var rating = (book['rating'] as num?)?.toInt() ?? 5;
    try {
      final review = await showDialog<({int rating, String review})>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Your review'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  value: rating,
                  items: List.generate(
                    5,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('${index + 1} stars'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => rating = value);
                  },
                ),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(labelText: 'Review'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  (rating: rating, review: controller.text),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (review == null) return;
      await ReadingShelf.saveReview(
        id: '${book['id']}',
        rating: review.rating,
        review: review.review,
      );
      if (mounted) setState(_reload);
    } finally {
      controller.dispose();
    }
  }

  Widget _bookTile(Map<String, dynamic> book) {
    final cover = book['cover'];
    final progress = (book['progress'] as num?)?.toInt() ?? 0;
    final page = (book['page'] as num?)?.toInt() ?? 1;
    final isPdf = book['format'] == 'pdf';
    final imported = book['imported'] == true;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: cover is String && cover.isNotEmpty
              ? Image.network(
                  cover,
                  width: 54,
                  height: 76,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _coverPlaceholder(),
                )
              : _coverPlaceholder(),
        ),
        title: Text(
          '${book['title'] ?? 'Untitled'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${imported ? '${book['format']?.toString().toUpperCase()} · Imported' : '${book['author'] ?? 'Unknown author'} · ${_date(book['openedAt'])}'}'
              ' · ${_statusLabel(book['status'])}'
              '${book['rating'] is num ? ' · ★ ${book['rating']}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isPdf)
              Text('Page $page')
            else if (!imported && progress > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress / 100),
              const SizedBox(height: 3),
              Text('$progress% complete'),
            ],
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'remove') {
              await _removeBook(book);
            } else if (value == 'collection') {
              await _assignCollection(book);
            } else if (value == 'review') {
              await _editReview(book);
            } else if (value.startsWith('status:')) {
              await ReadingShelf.updateStatus(
                id: '${book['id']}',
                status: value.substring('status:'.length),
              );
              if (mounted) setState(_reload);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'status:wantToRead',
              child: Text('Want to Read'),
            ),
            const PopupMenuItem(
              value: 'status:currentlyReading',
              child: Text('Currently Reading'),
            ),
            const PopupMenuItem(
              value: 'status:finished',
              child: Text('Finished'),
            ),
            const PopupMenuItem(
              value: 'collection',
              child: Text('Add to collection'),
            ),
            const PopupMenuItem(
              value: 'review',
              child: Text('Rate and review'),
            ),
            PopupMenuItem(
              value: 'remove',
              child: Text(
                  imported ? 'Remove from library' : 'Remove from history'),
            ),
          ],
        ),
        onTap: () => _openBook(book),
      ),
    );
  }

  String _statusLabel(dynamic status) {
    switch (status) {
      case 'wantToRead':
        return 'Want to Read';
      case 'finished':
        return 'Finished';
      default:
        return 'Currently Reading';
    }
  }

  Widget _coverPlaceholder() => const SizedBox(
        width: 54,
        height: 76,
        child: Icon(Icons.menu_book),
      );

  Widget _buildEmptyState(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withOpacity(.55),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your reading shelf is empty',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Open a book or import an EPUB or PDF to start your library.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _importBook,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Import a book'),
              ),
            ],
          ),
        ),
      );

  String _date(dynamic value) {
    final date = DateTime.tryParse('$value');
    if (date == null) return 'recently';
    final days = DateTime.now().difference(date).inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'yesterday';
    return '$days days ago';
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _Statistic extends StatelessWidget {
  const _Statistic({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
