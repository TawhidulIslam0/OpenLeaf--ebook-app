import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_ebook_app/src/features/library/data/epub_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  const cache = EpubCache();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('openbook-epub-test-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('accepts a structurally valid EPUB archive', () async {
    final file = File('${directory.path}\\valid.epub');
    await file.writeAsBytes(_epubBytes());

    expect(await cache.isValidFile(file), isTrue);
  });

  test('rejects a ZIP archive without the EPUB container', () async {
    final archive = Archive()
      ..addFile(_file('mimetype', 'application/epub+zip'))
      ..addFile(_file('chapter.xhtml', '<html/>'));
    final file = File('${directory.path}\\missing-container.epub');
    await file.writeAsBytes(ZipEncoder().encode(archive)!);

    expect(await cache.isValidFile(file), isFalse);
  });

  test('rejects files that are not ZIP archives', () async {
    final file = File('${directory.path}\\corrupt.epub');
    await file.writeAsBytes(Uint8List.fromList([0x50, 0x4b, 0x03, 0x04]));

    expect(await cache.isValidFile(file), isFalse);
  });
}

List<int> _epubBytes() {
  final archive = Archive()
    ..addFile(_file('mimetype', 'application/epub+zip'))
    ..addFile(
      _file(
        'META-INF/container.xml',
        '<container version="1.0"></container>',
      ),
    )
    ..addFile(_file('chapter.xhtml', '<html/>'));
  return ZipEncoder().encode(archive)!;
}

ArchiveFile _file(String name, String content) {
  final bytes = utf8.encode(content);
  final file = ArchiveFile(name, bytes.length, bytes);
  if (name == 'mimetype') file.compress = false;
  return file;
}
