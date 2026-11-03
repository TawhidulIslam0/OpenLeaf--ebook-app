import 'package:flutter_ebook_app/src/features/search/data/gutendex_search_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reorders comma-formatted author names for Gutendex search', () {
    expect(
      normalizeGutendexSearchQuery('Ostrander, Isabel'),
      'Isabel Ostrander',
    );
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
}
