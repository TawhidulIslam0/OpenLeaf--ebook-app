import 'package:flutter_ebook_app/src/common/constants/api.dart';
import 'package:flutter_ebook_app/src/common/data/repositories/book/book_repository.dart';
import 'package:flutter_ebook_app/src/common/domain/models/category_feed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reorders comma-formatted author names for Gutendex search', () {
    expect(
      normalizeGutendexSearchQuery('Ostrander, Isabel'),
      'Isabel Ostrander',
    );
  });

  test('normalizes author names in generated Gutendex URLs', () {
    final uri = Uri.parse(gutendexBooksUrl(search: 'Ostrander, Isabel'));
    expect(uri.queryParameters['search'], 'Isabel Ostrander');
  });

  test('does not ask Gutendex to filter EPUB formats server-side', () {
    final uri = Uri.parse(gutendexBooksUrl(topic: 'science fiction'));
    expect(uri.queryParameters.keys, isNot(contains('mime_type')));
    expect(uri.queryParameters['copyright'], 'false');
  });

  test('uses the catalog default popular sort without an extra parameter', () {
    final uri = Uri.parse(gutendexBooksUrl(sort: 'popular'));
    expect(uri.queryParameters.keys, isNot(contains('sort')));
  });

  test('trims ordinary search queries without changing their words', () {
    expect(
      normalizeGutendexSearchQuery('  Pride and Prejudice  '),
      'Pride and Prejudice',
    );
  });

  test('leaves incomplete comma queries unchanged', () {
    expect(normalizeGutendexSearchQuery('Ostrander,'), 'Ostrander,');
  });

  test('matches locally cached titles, authors, and subjects', () {
    final book = Entry(
      id: Id(t: '1513'),
      title: Id(t: 'Romeo and Juliet'),
      author: Author1(name: Id(t: 'Shakespeare, William')),
      category: [Category(label: 'Tragedy')],
    );

    expect(cachedBookMatchesQuery(book, 'Romeo and Juliet'), isTrue);
    expect(cachedBookMatchesQuery(book, 'William Shakespeare'), isTrue);
    expect(cachedBookMatchesQuery(book, 'tragedy'), isTrue);
    expect(cachedBookMatchesQuery(book, 'unrelated book'), isFalse);
    expect(cachedBookMatchesQuery(book, '  '), isFalse);
  });
}
