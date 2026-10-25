import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ebook_app/src/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class DownloadAlert extends ConsumerStatefulWidget {
  static const _downloadChannel = MethodChannel(
    'dev.jideguru.flutter_ebook_app/book_downloads',
  );
  static const _progressChannel = EventChannel(
    'dev.jideguru.flutter_ebook_app/book_download_progress',
  );

  final String url;
  final String name;
  final String image;
  final String id;

  const DownloadAlert({
    super.key,
    required this.url,
    required this.name,
    required this.image,
    required this.id,
  });

  static Future show({
    required BuildContext context,
    required String url,
    required String name,
    required String image,
    required String id,
  }) async {
    return showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => DownloadAlert(
        url: url,
        name: name,
        image: image,
        id: id,
      ),
    );
  }

  @override
  _DownloadAlertState createState() => _DownloadAlertState();
}

class _DownloadAlertState extends ConsumerState<DownloadAlert> {
  Dio dio = Dio()..interceptors.add(LogmanDioInterceptor());
  StreamSubscription<dynamic>? _progressSubscription;
  int received = 0;
  String progress = '0';
  int total = 0;

  String get fileName => widget.name
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .replaceAll(' ', '_')
      .replaceAll(RegExp('_+'), '_');

  Future<void> _startDownload() async {
    await createFile();
  }

  Future<void> createFile() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final directory = Directory(path.join(appDocDir.path, appName));
      await directory.create(recursive: true);
      final name = fileName.isEmpty ? widget.id : fileName;
      final filePath = path.join(directory.path, '$name-${widget.id}.epub');
      await download(filePath: filePath);
    } catch (error) {
      _reportDownloadFailure(error);
    }
  }

  Future<void> download({required String filePath}) async {
    final file = File(filePath);
    final isAndroid = Platform.isAndroid;
    try {
      if (isAndroid) {
        _progressSubscription =
            DownloadAlert._progressChannel.receiveBroadcastStream().listen(
          _onDownloadProgress,
          onError: (Object error) {
            debugPrint('Book download progress stream failed: $error');
          },
        );
        await DownloadAlert._downloadChannel.invokeMethod<int>(
          'downloadBook',
          {'url': widget.url, 'filePath': filePath},
        );
      } else {
        final response = await dio.download(
          widget.url,
          filePath,
          onReceiveProgress: (receivedBytes, totalBytes) {
            _updateProgress(receivedBytes, totalBytes);
          },
        );
        if (response.statusCode == null ||
            response.statusCode! < 200 ||
            response.statusCode! >= 300) {
          throw DioException(
            requestOptions: response.requestOptions,
            response: response,
            message: 'The EPUB download returned an unsuccessful response.',
          );
        }
      }

      final length = await file.length();
      final handle = await file.open();
      final signature = await handle.read(2);
      await handle.close();
      if (length < 2 ||
          signature.length != 2 ||
          signature[0] != 0x50 ||
          signature[1] != 0x4b) {
        throw const FormatException(
          'The download was not a valid EPUB book.',
        );
      }

      final size = formatBytes(length, 1);
      final book = {
        'id': widget.id,
        'path': filePath,
        'image': widget.image,
        'size': size,
        'name': widget.name,
      };
      await ref
          .read(downloadsNotifierProvider.notifier)
          .addBook(book, widget.id);
      await _progressSubscription?.cancel();
      _progressSubscription = null;
      if (mounted) {
        Navigator.pop(context, filePath);
      }
    } catch (error) {
      if (!isAndroid && await file.exists()) {
        await file.delete();
      }
      _reportDownloadFailure(error);
    }
  }

  void _onDownloadProgress(dynamic event) {
    if (event is! Map) return;
    final receivedBytes = event['received'];
    final totalBytes = event['total'];
    if (receivedBytes is int && totalBytes is int) {
      _updateProgress(receivedBytes, totalBytes);
    }
  }

  void _updateProgress(int receivedBytes, int totalBytes) {
    if (!mounted) return;
    setState(() {
      received = receivedBytes;
      total = totalBytes > 0 ? totalBytes : 0;
      progress = total > 0
          ? (received / total * 100).clamp(0, 100).toStringAsFixed(0)
          : '0';
    });
  }

  void _reportDownloadFailure(Object error) {
    debugPrint('Failed to download "${widget.name}": $error');
    unawaited(_progressSubscription?.cancel());
    _progressSubscription = null;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.pop(context);
    messenger?.showSnackBar(
      SnackBar(content: Text('Could not download this book: $error')),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_startDownload());
  }

  @override
  void dispose() {
    unawaited(_progressSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: CustomAlert(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Downloading...',
                style: TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20.0),
              Container(
                height: 5,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.circular(10),
                  ),
                ),
                child: LinearProgressIndicator(
                  value: double.parse(progress) / 100.0,
                  valueColor: AlwaysStoppedAnimation(
                    context.theme.colorScheme.secondary,
                  ),
                  backgroundColor:
                      context.theme.colorScheme.secondary.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 5.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    '$progress %',
                    style: const TextStyle(
                      fontSize: 13.0,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${formatBytes(received, 1)} '
                    'of ${formatBytes(total, 1)}',
                    style: const TextStyle(
                      fontSize: 13.0,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
