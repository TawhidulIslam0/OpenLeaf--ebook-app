import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iridium_reader_widget/views/viewers/epub_screen.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ReadBookScreen extends StatefulWidget {
  final String id;
  final String title;
  final String url;

  const ReadBookScreen({
    super.key,
    required this.id,
    required this.title,
    required this.url,
  });

  @override
  State<ReadBookScreen> createState() => _ReadBookScreenState();
}

class _ReadBookScreenState extends State<ReadBookScreen> {
  static const _downloadChannel = MethodChannel(
    'dev.jideguru.flutter_ebook_app/book_downloads',
  );
  static const _progressChannel = EventChannel(
    'dev.jideguru.flutter_ebook_app/book_download_progress',
  );

  StreamSubscription<dynamic>? _progressSubscription;
  String? _error;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    unawaited(_openBook());
  }

  Future<void> _openBook() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });

    try {
      final directory = await getTemporaryDirectory();
      final filePath = path.join(directory.path, 'reader-${widget.id}.epub');
      final file = File(filePath);

      if (Platform.isAndroid) {
        _progressSubscription =
            _progressChannel.receiveBroadcastStream().listen((_) {});
        await _downloadChannel.invokeMethod<int>(
          'downloadBook',
          {'url': widget.url, 'filePath': filePath},
        );
      } else {
        final response = await Dio().download(widget.url, filePath);
        if (response.statusCode == null ||
            response.statusCode! < 200 ||
            response.statusCode! >= 300) {
          throw const HttpException('The EPUB request failed.');
        }
      }

      final handle = await file.open();
      final signature = await handle.read(2);
      await handle.close();
      if (signature.length != 2 ||
          signature[0] != 0x50 ||
          signature[1] != 0x4b) {
        throw const FormatException('The server did not return a valid EPUB.');
      }

      if (!mounted) return;
      unawaited(
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute<void>(
            builder: (_) => EpubScreen.fromPath(filePath: filePath),
          ),
        ),
      );
      return;
    } catch (error) {
      debugPrint('Failed to open "${widget.title}" for reading: $error');
      if (mounted) {
        final errorDetails = error.toString();
        final isCertificateError =
            errorDetails.toLowerCase().contains('trust anchor') ||
                errorDetails.toLowerCase().contains('certpath');
        setState(() {
          _error = isCertificateError
              ? 'Android could not verify the Project Gutenberg HTTPS '
                  'certificate. Check the device date and time, update its '
                  'security certificates, or try a network without HTTPS '
                  'filtering. The app will not accept an untrusted '
                  'certificate.'
              : 'Could not open this book. Check your internet connection and '
                  'try again. $error';
        });
      }
    } finally {
      await _progressSubscription?.cancel();
      _progressSubscription = null;
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  void dispose() {
    unawaited(_progressSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _error == null
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Opening book for reading...'),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 48),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _opening ? null : _openBook,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
