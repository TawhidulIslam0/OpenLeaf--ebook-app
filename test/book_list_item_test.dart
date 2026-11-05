import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ebook_app/src/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const coverChannel = MethodChannel(
    'dev.jideguru.flutter_ebook_app/book_covers',
  );
  const pngBytes = <int>[
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    0x00,
    0x00,
    0x00,
    0x0d,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1f,
    0x15,
    0xc4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0b,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9c,
    0x63,
    0x60,
    0x00,
    0x02,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0xa5,
    0xf6,
    0x45,
    0x40,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4e,
    0x44,
    0xae,
    0x42,
    0x60,
    0x82,
  ];

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      coverChannel,
      (call) async => Uint8List.fromList(pngBytes),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(coverChannel, null);
  });

  testWidgets('long book metadata does not overflow its fixed-height row',
      (tester) async {
    final entry = Entry(
      id: Id(t: '1'),
      title: Id(
        t: 'A very long book title that should be shortened in the list row',
      ),
      author: Author1(
        name: Id(
          t: 'A very long author name with multiple parts that should be '
              'truncated without overflowing the book card',
        ),
      ),
      summary: Id(
        t: List<String>.filled(20, 'A long catalog summary.').join(' '),
      ),
      link: [
        Link1(rel: 'self', href: 'https://gutendex.com/books/1/'),
        Link1(
          rel: 'cover',
          href: 'https://www.gutenberg.org/cache/epub/1/pg1.cover.medium.jpg',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: BookListItem(entry: entry),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
