import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ebook_app/src/features/library/data/reading_shelf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts with an empty personal reading shelf', () async {
    expect(await ReadingShelf.getRecent(), isEmpty);
  });

  test('records books newest first and updates an existing record', () async {
    await ReadingShelf.record(id: '1', title: 'First', author: 'Author A', cover: 'cover-a', url: 'url-a');
    await ReadingShelf.record(id: '2', title: 'Second', author: 'Author B', cover: 'cover-b', url: 'url-b');
    await ReadingShelf.record(id: '1', title: 'First revised', author: 'Author A', cover: 'cover-a', url: 'url-a');

    final books = await ReadingShelf.getRecent();
    expect(books, hasLength(2));
    expect(books.first['id'], '1');
    expect(books.first['title'], 'First revised');
    expect(books.last['id'], '2');
  });

  test('removes one record and can clear the shelf', () async {
    await ReadingShelf.record(id: '1', title: 'One', author: 'A', cover: '', url: '');
    await ReadingShelf.record(id: '2', title: 'Two', author: 'B', cover: '', url: '');
    await ReadingShelf.remove('1');
    expect((await ReadingShelf.getRecent()).map((book) => book['id']), ['2']);
    await ReadingShelf.clear();
    expect(await ReadingShelf.getRecent(), isEmpty);
  });
}
