import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ebook_app/src/common/domain/models/category_feed.dart';
import 'package:flutter_ebook_app/src/features/book_details/presentation/ui/screens/book_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)));
  List<Entry> _results = [];
  bool _loading = false;
  String? _error;
  String _sort = 'popular';

  Future<void> _search([String? value]) async {
    final query = (value ?? _controller.text).trim();
    if (query.isEmpty) { setState(() { _results = []; _error = null; }); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final response = await _dio.get('https://gutendex.com/books/', queryParameters: {
        'search': query, 'languages': 'en', 'copyright': 'false',
        'sort': _sort == 'newest' ? 'descending' : 'popular',
      });
      final data = response.data;
      final raw = data is Map ? data['results'] : null;
      final results = <Entry>[];
      if (raw is List) {
        for (final item in raw.whereType<Map>()) {
          final book = Map<String, dynamic>.from(item);
          final formats = book['formats'];
          if (formats is! Map) continue;
          final epub = formats['application/epub+zip'];
          if (epub is! String) continue;
          final id = '${book['id']}';
          final authors = book['authors'];
          final author = authors is List && authors.isNotEmpty && authors.first is Map ? authors.first as Map : <String, dynamic>{};
          final subjects = book['subjects'];
          final cover = formats['image/jpeg'] ?? 'https://www.gutenberg.org/cache/epub/$id/pg$id.cover.medium.jpg';
          results.add(Entry(
            id: Id(t: id), title: Id(t: '${book['title'] ?? 'Untitled'}'),
            author: Author1(name: Id(t: '${author['name'] ?? 'Unknown author'}'), uri: Id(t: 'https://gutendex.com/books/?search=${Uri.encodeQueryComponent('${author['name'] ?? ''}')}')),
            summary: Id(t: (book['summaries'] is List && (book['summaries'] as List).isNotEmpty) ? '${(book['summaries'] as List).first}' : 'A public-domain ebook available from Project Gutenberg.'),
            category: subjects is List ? subjects.whereType<String>().take(5).map((s) => Category(label: s)).toList() : [],
            link: [Link1(rel: 'self', href: 'https://gutendex.com/books/$id/'), Link1(rel: 'cover', href: '$cover'), Link1(rel: 'alternate', href: 'https://www.gutenberg.org/ebooks/$id'), Link1(rel: 'download', type: 'application/epub+zip', href: epub)],
          ));
        }
      }
      if (_sort == 'title') {
        results.sort((a, b) => (a.title?.t ?? '').toLowerCase().compareTo(
          (b.title?.t ?? '').toLowerCase(),
        ));
      }
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not search the catalog. Check your connection and try again.');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  void dispose() { _controller.dispose(); _dio.close(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Find your next read')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: TextField(
        controller: _controller, textInputAction: TextInputAction.search, onSubmitted: _search,
        decoration: InputDecoration(hintText: 'Search titles, authors, subjects…', prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { _controller.clear(); setState(() { _results = []; _error = null; }); }),
          filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
      )),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [const Text('Sort by'), const SizedBox(width: 10),
        DropdownButton<String>(value: _sort, underline: const SizedBox.shrink(), items: const [DropdownMenuItem(value: 'popular', child: Text('Popularity')), DropdownMenuItem(value: 'title', child: Text('Title A–Z')), DropdownMenuItem(value: 'newest', child: Text('Newest'))], onChanged: (v) { if (v != null) { setState(() => _sort = v); if (_controller.text.trim().isNotEmpty) _search(); } }),
        const Spacer(), Text('${_results.length} results', style: Theme.of(context).textTheme.bodySmall),
      ])),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))) : _results.isEmpty ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.travel_explore, size: 56), const SizedBox(height: 14), Text('Search the library', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 6), const Text('Find public-domain books by title, author, or subject.', textAlign: TextAlign.center), const SizedBox(height: 14), FilledButton.icon(onPressed: () => _search('science fiction'), icon: const Icon(Icons.auto_awesome), label: const Text('Explore science fiction'))]))) : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _results.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (context, index) {
        final entry = _results[index];
        return Card(clipBehavior: Clip.antiAlias, child: ListTile(contentPadding: const EdgeInsets.all(10),
          leading: ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.network(entry.link![1].href!, width: 58, height: 82, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 58, height: 82, child: Icon(Icons.menu_book)))),
          title: Text(entry.title?.t ?? 'Untitled', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(entry.author?.name?.t ?? 'Unknown author', maxLines: 2), trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailsScreen(entry: entry, imgTag: 'search-cover-${entry.id?.t}', titleTag: 'search-title-${entry.id?.t}', authorTag: 'search-author-${entry.id?.t}'))),
        ));
      })),
    ]),
    floatingActionButton: _controller.text.trim().isEmpty ? null : FloatingActionButton.small(onPressed: () => _search(), child: const Icon(Icons.search)),
  );
}
