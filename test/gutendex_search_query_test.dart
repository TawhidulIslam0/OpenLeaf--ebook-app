import 'package:flutter_ebook_app/src/common/constants/api.dart';
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
