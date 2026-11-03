import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ebook_app/src/common/common.dart';
import 'package:flutter_ebook_app/src/features/library/data/epub_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DownloadAlert extends ConsumerStatefulWidget {
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

  static Future<void> show({
    required BuildContext context,
    required String url,
    required String name,
    required String image,
    required String id,
  }) async {
    await showDialog<void>(
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
  ConsumerState<DownloadAlert> createState() => _DownloadAlertState();
}

class _DownloadAlertState extends ConsumerState<DownloadAlert> {
  final Dio _dio = Dio()..interceptors.add(LogmanDioInterceptor());
  int _received = 0;
  int _total = 0;
  bool _saving = false;
  bool _running = false;
  bool _cancelling = false;
  String? _error;
  CancelToken? _cancelToken;

  Future<void> _startDownload() async {
    if (_running) return;
    setState(() {
      _running = true;
      _saving = false;
      _cancelling = false;
      _error = null;
      _received = 0;
      _total = 0;
      _cancelToken = CancelToken();
    });
    try {
      final cached = await epubCache.contains(widget.id);
      final file = cached
          ? await epubCache.fileFor(widget.id)
          : await epubCache.download(
              dio: _dio,
              id: widget.id,
              url: widget.url,
              cancelToken: _cancelToken!,
              onProgress: _updateProgress,
            );
      final length = await file.length();
      if (!await epubCache.isValidFile(file)) {
        throw const FormatException('The downloaded file is not a valid EPUB.');
      }

      if (!mounted) return;
      setState(() => _saving = true);
      await ref.read(downloadsNotifierProvider.notifier).addBook(
        {
          'id': widget.id,
          'path': file.path,
          'image': widget.image,
          'size': formatBytes(length, 1),
          'name': widget.name,
          'url': widget.url,
        },
        widget.id,
      );
      if (mounted) Navigator.pop(context, file.path);
    } catch (error, stackTrace) {
      if (error is DioException && CancelToken.isCancel(error)) {
        if (mounted) Navigator.pop(context);
        return;
      }
      debugPrint('Failed to download "${widget.name}": $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _error = _downloadError(error));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String _downloadError(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'The download timed out. Check your connection and retry.';
      }
      if (error.response?.statusCode case final int statusCode) {
        return 'The catalog returned HTTP $statusCode. Retry in a moment.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'You appear to be offline. Reconnect and retry the download.';
      }
    }
    return 'Could not download this book: $error';
  }

  void _cancelDownload() {
    if (_running) {
      setState(() => _cancelling = true);
      _cancelToken?.cancel('Download cancelled by the user.');
    } else {
      Navigator.pop(context);
    }
  }

  void _updateProgress(int receivedBytes, int totalBytes) {
    if (!mounted) return;
    setState(() {
      _received = receivedBytes;
      _total = totalBytes > 0 ? totalBytes : 0;
    });
  }

  @override
  void initState() {
    super.initState();
    unawaited(_startDownload());
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent =
        _total > 0 ? (_received / _total).clamp(0, 1).toDouble() : null;
    return PopScope(
      canPop: false,
      child: CustomAlert(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error == null) ...[
                Text(
                  _saving ? 'Saving to your downloads...' : 'Downloading...',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                LinearProgressIndicator(value: percent),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      percent == null
                          ? 'Downloading'
                          : '${(percent * 100).round()}%',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      '${formatBytes(_received, 1)}'
                      '${_total > 0 ? ' of ${formatBytes(_total, 1)}' : ''}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ] else ...[
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _running ? _cancelDownload : _cancelDownload,
                    child: Text(_running
                        ? (_cancelling ? 'Cancelling…' : 'Cancel')
                        : 'Close'),
                  ),
                  if (_error != null)
                    FilledButton(
                      onPressed: _running ? null : _startDownload,
                      child: const Text('Retry'),
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
