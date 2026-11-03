import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  Future<bool> isValidFile(File file) => _isValidEpub(file);

  Future<File> download({
    required Dio dio,
    required String id,
    required String url,
    required void Function(int received, int total) onProgress,
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
      if (Platform.isAndroid) {
        await _downloadOnAndroid(url, destination, onProgress);
      } else {
        await _downloadWithRedirects(
          dio: dio,
          initialUri: uri,
          destination: temporary,
          onProgress: onProgress,
        );
        if (!await _isValidEpub(temporary)) {
          throw const FormatException(
              'The downloaded file is not a valid EPUB.');
        }

        if (await destination.exists()) await destination.delete();
        await temporary.rename(destination.path);
      }

      if (!await _isValidEpub(destination)) {
        throw const FormatException('The downloaded file is not a valid EPUB.');
      }
      return destination;
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

  static Future<void> _downloadOnAndroid(
    String url,
    File destination,
    void Function(int received, int total) onProgress,
  ) async {
    const channel = MethodChannel(
      'dev.jideguru.flutter_ebook_app/book_downloads',
    );
    const progressChannel = EventChannel(
      'dev.jideguru.flutter_ebook_app/book_download_progress',
    );

    final subscription = progressChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final received = event['received'];
          final total = event['total'];
          if (received is num && total is num) {
            onProgress(received.toInt(), total.toInt());
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('EPUB download progress stream failed: $error');
      },
    );
    try {
      await channel.invokeMethod<int>('downloadBook', {
        'url': url,
        'filePath': destination.path,
      });
    } finally {
      await subscription.cancel();
    }
  }

  static Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(path.join(support.path, 'openleaf', 'books'));
    await directory.create(recursive: true);
    return directory;
  }

  static Future<bool> _isValidEpub(File file) async {
    if (!await file.exists() || await file.length() < 4) return false;
    final handle = await file.open();
    try {
      final signature = await handle.read(2);
      return signature.length == 2 &&
          signature[0] == 0x50 &&
          signature[1] == 0x4b;
    } finally {
      await handle.close();
    }
  }
}

const epubCache = EpubCache();
