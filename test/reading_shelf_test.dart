import 'package:flutter_ebook_app/src/features/library/data/reading_shelf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts with an empty personal reading shelf', () async {
    expect(await ReadingShelf.getRecent(), isEmpty);
  });

  test('records books newest first and updates an existing record', () async {
    await ReadingShelf.record(
        id: '1',
        title: 'First',
        author: 'Author A',
        cover: 'cover-a',
        url: 'url-a');
    await ReadingShelf.record(
        id: '2',
        title: 'Second',
        author: 'Author B',
        cover: 'cover-b',
        url: 'url-b');
    await ReadingShelf.record(
        id: '1',
        title: 'First revised',
        author: 'Author A',
        cover: 'cover-a',
        url: 'url-a');

    final books = await ReadingShelf.getRecent();
    expect(books, hasLength(2));
    expect(books.first['id'], '1');
    expect(books.first['title'], 'First revised');
    expect(books.last['id'], '2');
  });

  test('removes one record and can clear the shelf', () async {
    await ReadingShelf.record(
        id: '1', title: 'One', author: 'A', cover: '', url: '');
    await ReadingShelf.record(
        id: '2', title: 'Two', author: 'B', cover: '', url: '');
    await ReadingShelf.remove('1');
    expect((await ReadingShelf.getRecent()).map((book) => book['id']), ['2']);
    await ReadingShelf.clear();
    expect(await ReadingShelf.getRecent(), isEmpty);
  });

  test('tracks reading progress and useful library statistics', () async {
    await ReadingShelf.record(
      id: '1',
      title: 'One',
      author: 'A',
      cover: '',
      url: '',
    );
    await ReadingShelf.updateProgress(
      id: '1',
      progress: 42,
      position: '{"location":"chapter-2"}',
    );

    final books = await ReadingShelf.getRecent();
    expect(books.single['progress'], 42);
    expect(books.single['position'], '{"location":"chapter-2"}');
    final statistics = await ReadingShelf.getStatistics();
    expect(statistics['books'], 1);
    expect(statistics['importedBooks'], 0);
    expect(statistics['sessions'], 1);
    expect(statistics['readingDays'], 1);
  });

  test('persists statuses, reviews, collections, and reading goals', () async {
    await ReadingShelf.record(
      id: '1',
      title: 'The Book',
      author: 'A. Author',
      cover: '',
      url: '',
    );
    await ReadingShelf.addCollection('Favorites');
    await ReadingShelf.assignCollection(id: '1', collection: 'Favorites');
    await ReadingShelf.updateStatus(id: '1', status: 'wantToRead');
    await ReadingShelf.saveReview(
      id: '1',
      rating: 5,
      review: 'A lovely read.',
    );
    await ReadingShelf.setDailyGoalMinutes(30);

    final book = (await ReadingShelf.getRecent()).single;
    expect(book['status'], 'wantToRead');
    expect(book['collections'], ['Favorites']);
    expect(book['rating'], 5);
    expect(book['review'], 'A lovely read.');
    expect(await ReadingShelf.getCollections(), ['Favorites']);
    expect((await ReadingShelf.getStatistics())['dailyGoalMinutes'], 30);
  });

  test('detects existing titles without duplicating matching entries',
      () async {
    await ReadingShelf.record(
      id: '1',
      title: 'A   Book',
      author: 'Author',
      cover: '',
      url: '',
    );

    expect(await ReadingShelf.hasDuplicate(title: 'a book'), isTrue);
    expect(
      await ReadingShelf.hasDuplicate(title: 'A Book', author: 'Different'),
      isFalse,
    );
  });

  test('aggregates time, pages, streaks, and reading goals', () async {
    await ReadingShelf.importBook(
      id: 'pdf-1',
      title: 'PDF',
      path: 'not-a-real-file',
      format: 'pdf',
    );
    await ReadingShelf.updatePdfPage(id: 'pdf-1', page: 5);
    await ReadingShelf.addReadingTime(
      id: 'pdf-1',
      seconds: 900,
      now: DateTime.now(),
    );

    final statistics = await ReadingShelf.getStatistics();
    expect(statistics['pagesRead'], 4);
    expect(statistics['readingSeconds'], 900);
    expect(statistics['todaySeconds'], 900);
    expect(statistics['streakDays'], greaterThanOrEqualTo(1));
  });

  test('saves and restores the current PDF page', () async {
    await ReadingShelf.importBook(
      id: 'pdf-1',
      title: 'PDF',
      path: 'not-a-real-file',
      format: 'pdf',
    );
    await ReadingShelf.updatePdfPage(id: 'pdf-1', page: 8);

    final books = await ReadingShelf.getRecent();
    expect(books.single['page'], 8);
  });

  test('clearing reading history preserves imported books', () async {
    await ReadingShelf.importBook(
      id: 'import-1',
      title: 'Imported',
      path: 'not-a-real-file',
      format: 'pdf',
    );
    await ReadingShelf.record(
      id: 'online-1',
      title: 'Online',
      author: 'A',
      cover: '',
      url: '',
    );

    await ReadingShelf.clear();

    final books = await ReadingShelf.getRecent();
    expect(books, hasLength(1));
    expect(books.single['id'], 'import-1');
  });
}
