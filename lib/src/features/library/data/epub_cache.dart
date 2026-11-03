import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class EpubCache {
  const EpubCache();

  Future<File> fileFor(String id) async {
    final directory = await _directory();
    final safeId = base64Url.encode(utf8.encode(id)).replaceAll('=', '');
    return File(path.join(directory.path, '$safeId.epub'));
  }

  Future<bool> contains(String id) async {
    final file = await fileFor(id);
    if (await isValidFile(file)) return true;
    if (!await file.exists()) return false;
    await file.delete();
    return false;
  }

  Future<int> sizeOf(String id) async {
    final file = await fileFor(id);
    if (!await file.exists()) return 0;
    return file.length();
  }

  Future<void> delete(String id) async {
    final file = await fileFor(id);
    if (await file.exists()) await file.delete();
  }

  Future<bool> isValidFile(File file) => _isValidEpub(file);

  Future<File> download({
    required Dio dio,
    required String id,
    required String url,
    required void Function(int received, int total) onProgress,
    required CancelToken cancelToken,
  }) async {
    final uri = Uri.tryParse(url);
    final host = uri?.host.toLowerCase();
    if (uri == null ||
        uri.scheme != 'https' ||
        host == null ||
        !(host == 'gutenberg.org' || host.endsWith('.gutenberg.org'))) {
      throw const FormatException('Unsupported EPUB download URL.');
    }

    final destination = await fileFor(id);
    final temporary = File('${destination.path}.part');
    try {
      await _downloadWithRedirects(
        dio: dio,
        initialUri: uri,
        destination: temporary,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      if (!await _isValidEpub(temporary)) {
        throw const FormatException('The downloaded file is not a valid EPUB.');
      }
      if (await destination.exists()) await destination.delete();
      return await temporary.rename(destination.path);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  static Future<void> _downloadWithRedirects({
    required Dio dio,
    required Uri initialUri,
    required File destination,
    required void Function(int received, int total) onProgress,
    required CancelToken cancelToken,
  }) async {
    var currentUri = initialUri;
    for (var redirectCount = 0; redirectCount <= 5; redirectCount++) {
      if (!_isGutenbergUri(currentUri)) {
        throw const FormatException('Unsupported EPUB download redirect.');
      }
      if (await destination.exists()) await destination.delete();
      final response = await dio.download(
        currentUri.toString(),
        destination.path,
        cancelToken: cancelToken,
        onReceiveProgress: onProgress,
        options: Options(
          receiveTimeout: const Duration(minutes: 2),
          followRedirects: false,
          maxRedirects: 0,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        ),
      );
      final status = response.statusCode;
      if (status != null && status >= 300 && status < 400) {
        if (redirectCount == 5) {
          throw const HttpException(
              'The EPUB download exceeded its redirect limit.');
        }
        final location = response.headers.value('location');
        if (location == null) {
          throw const HttpException('The EPUB redirect has no destination.');
        }
        currentUri = currentUri.resolve(location);
        continue;
      }
      if (status == null || status < 200 || status >= 300) {
        throw const HttpException('The EPUB request failed.');
      }
      return;
    }
    throw const HttpException('Could not download the EPUB.');
  }

  static bool _isGutenbergUri(Uri uri) {
    final host = uri.host.toLowerCase();
    return uri.scheme == 'https' &&
        (host == 'gutenberg.org' || host.endsWith('.gutenberg.org'));
  }

  static Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(path.join(support.path, 'openleaf', 'books'));
    await directory.create(recursive: true);
    return directory;
  }

  static Future<bool> _isValidEpub(File file) async {
    if (!await file.exists()) return false;
    final handle = await file.open(mode: FileMode.read);
    try {
      final length = await handle.length();
      if (length < 22) return false;

      final tailLength = length < 65557 ? length : 65557;
      await handle.setPosition(length - tailLength);
      final tail = await handle.read(tailLength);
      final tailData = ByteData.sublistView(Uint8List.fromList(tail));
      var endOffset = -1;
      for (var offset = tail.length - 22; offset >= 0; offset--) {
        if (tailData.getUint32(offset, Endian.little) == 0x06054b50 &&
            offset + 22 + tailData.getUint16(offset + 20, Endian.little) ==
                tail.length) {
          endOffset = offset;
          break;
        }
      }
      if (endOffset < 0 ||
          tailData.getUint16(endOffset + 4, Endian.little) != 0 ||
          tailData.getUint16(endOffset + 6, Endian.little) != 0) {
        return false;
      }

      final entryCount = tailData.getUint16(endOffset + 10, Endian.little);
      final directorySize = tailData.getUint32(endOffset + 12, Endian.little);
      final directoryOffset = tailData.getUint32(endOffset + 16, Endian.little);
      if (entryCount == 0 ||
          entryCount == 0xffff ||
          directorySize > 16 * 1024 * 1024 ||
          directoryOffset + directorySize > length - tailLength + endOffset) {
        return false;
      }

      await handle.setPosition(directoryOffset);
      final directory = await handle.read(directorySize);
      final directoryData = ByteData.sublistView(Uint8List.fromList(directory));
      var cursor = 0;
      var hasMimetype = false;
      var hasContainer = false;
      for (var index = 0; index < entryCount; index++) {
        if (cursor + 46 > directory.length ||
            directoryData.getUint32(cursor, Endian.little) != 0x02014b50) {
          return false;
        }
        final method = directoryData.getUint16(cursor + 10, Endian.little);
        final compressedSize =
            directoryData.getUint32(cursor + 20, Endian.little);
        final uncompressedSize =
            directoryData.getUint32(cursor + 24, Endian.little);
        final nameLength = directoryData.getUint16(cursor + 28, Endian.little);
        final extraLength = directoryData.getUint16(cursor + 30, Endian.little);
        final commentLength =
            directoryData.getUint16(cursor + 32, Endian.little);
        final localOffset = directoryData.getUint32(cursor + 42, Endian.little);
        final entryEnd = cursor + 46 + nameLength + extraLength + commentLength;
        if (entryEnd > directory.length) return false;
        final name = utf8.decode(
          directory.sublist(cursor + 46, cursor + 46 + nameLength),
          allowMalformed: true,
        );
        if (index == 0) {
          if (name != 'mimetype' ||
              method != 0 ||
              compressedSize != 20 ||
              uncompressedSize != 20 ||
              localOffset != 0) {
            return false;
          }
          await handle.setPosition(localOffset);
          final localHeader = await handle.read(30);
          if (localHeader.length != 30) return false;
          final localData =
              ByteData.sublistView(Uint8List.fromList(localHeader));
          if (localData.getUint32(0, Endian.little) != 0x04034b50) {
            return false;
          }
          if (localData.getUint16(6, Endian.little) & 0x08 != 0 ||
              localData.getUint16(8, Endian.little) != 0) {
            return false;
          }
          final localNameLength = localData.getUint16(26, Endian.little);
          final localExtraLength = localData.getUint16(28, Endian.little);
          if (localNameLength != 'mimetype'.length) return false;
          final localName = await handle.read(localNameLength);
          if (utf8.decode(localName, allowMalformed: true) != 'mimetype') {
            return false;
          }
          await handle.setPosition(30 + localNameLength + localExtraLength);
          final mimetype = await handle.read(20);
          hasMimetype = utf8.decode(mimetype, allowMalformed: true) ==
              'application/epub+zip';
        }
        if (name == 'META-INF/container.xml') hasContainer = true;
        cursor = entryEnd;
      }
      return hasMimetype && hasContainer && cursor == directory.length;
    } finally {
      await handle.close();
    }
  }
}

const epubCache = EpubCache();
