import 'package:flutter/material.dart';
import 'package:flutter_ebook_app/src/features/library/data/reading_shelf.dart';
import 'package:flutter_ebook_app/src/features/book_details/presentation/ui/screens/read_book_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<List<Map<String, dynamic>>> _books;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() => _books = ReadingShelf.getRecent();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Library'), actions: [
      IconButton(tooltip: 'Clear reading history', icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
            title: const Text('Clear reading history?'),
            content: const Text('This removes your recently opened list. It does not delete downloaded books or favorites.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear'))],
          ));
          if (yes == true) { await ReadingShelf.clear(); setState(_reload); }
        }),
    ]),
    body: FutureBuilder<List<Map<String, dynamic>>>(future: _books, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return const Center(child: Text('Could not load your reading shelf. Please try again.'));
      final books = snapshot.data ?? [];
      if (books.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.menu_book_outlined, size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(.55)),
          const SizedBox(height: 16), const Text('Your reading shelf is empty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8), const Text('Books you open will appear here, ready for you to pick up again.', textAlign: TextAlign.center),
        ],
      )));
      return ListView.separated(padding: const EdgeInsets.all(16), itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final book = books[index];
          return Card(clipBehavior: Clip.antiAlias, child: ListTile(
            contentPadding: const EdgeInsets.all(10),
            leading: ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.network('${book['cover']}', width: 54, height: 76, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(width: 54, height: 76, child: Icon(Icons.menu_book)))),
            title: Text('${book['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${book['author']}\nOpened ${_date(book['openedAt'])}', maxLines: 2),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(onSelected: (value) async {
              if (value == 'remove') { await ReadingShelf.remove('${book['id']}'); setState(_reload); }
            }, itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Remove from history'))]),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReadBookScreen(
              id: '${book['id']}', title: '${book['title']}', author: '${book['author']}', url: '${book['url']}'))),
          ));
        });
    }),
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
