import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ebook_app/src/common/common.dart';

class BookCover extends StatelessWidget {
  static final _coverRequests = <String, Future<Uint8List>>{};
  static const _coverChannel = MethodChannel(
    'dev.jideguru.flutter_ebook_app/book_covers',
  );

  final Entry? entry;
  final String? bookId;
  final String? title;
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const BookCover({
    super.key,
    this.entry,
    this.bookId,
    this.title,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final id = entry?.id?.t ?? bookId;
    final sourceUrls = <String>{
      imageUrl,
      if (id != null)
        'https://www.gutenberg.org/cache/epub/$id/pg$id.cover.medium.jpg',
      if (id != null)
        'https://www.gutenberg.org/cache/epub/$id/pg$id.cover.small.jpg',
    }.where((url) => url.isNotEmpty);
    final imageUrls = <String>{
      for (final url in sourceUrls) ...[
        if (_proxiedUrl(url) case final proxyUrl?) proxyUrl,
        url,
      ],
    }.toList();

    return _buildImage(context, imageUrls, 0);
  }

  static String? _proxiedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        !(uri.host == 'gutenberg.org' || uri.host.endsWith('.gutenberg.org'))) {
      return null;
    }
    return Uri.https('images.weserv.nl', '/', {
      'url': '${uri.host}${uri.path}',
    }).toString();
  }

  Widget _buildImage(
    BuildContext context,
    List<String> imageUrls,
    int index,
  ) {
    if (index == imageUrls.length) {
      return Image.asset(
        'assets/images/place.png',
        fit: fit,
        width: width,
        height: height,
      );
    }

    final url = imageUrls[index];
    final cover = _coverRequests.putIfAbsent(url, () => _fetchCover(url));
    return FutureBuilder<Uint8List>(
      future: cover,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              _coverRequests.remove(url);
              return _nextImage(context, imageUrls, index, error);
            },
          );
        }
        if (snapshot.hasError) {
          return _nextImage(context, imageUrls, index, snapshot.error!);
        }
        return SizedBox(
          width: width,
          height: height,
          child: const LoadingWidget(isImage: true),
        );
      },
    );
  }

  Widget _nextImage(
    BuildContext context,
    List<String> imageUrls,
    int index,
    Object error,
  ) {
    final coverBookId = entry?.id?.t ?? bookId;
    _coverRequests.remove(imageUrls[index]);
    if (index == imageUrls.length - 1) {
      debugPrint(
        'Failed to load cover for '
        '${entry?.title?.t ?? title ?? coverBookId}: '
        '${imageUrls[index]} ($error)',
      );
    }
    return _buildImage(context, imageUrls, index + 1);
  }

  static Future<Uint8List> _fetchCover(String url) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final bytes = await _coverChannel.invokeMethod<Uint8List>(
        'loadCover',
        {'url': url},
      );
      if (bytes == null || bytes.isEmpty) {
        throw FormatException('The cover image at $url was empty.');
      }
      return bytes;
    }

    final response = await Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
      ),
    ).get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: const {'User-Agent': 'OpenLeaf eBook Reader'},
      ),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw FormatException('The cover image at $url was empty.');
    }
    return Uint8List.fromList(bytes);
  }
}
