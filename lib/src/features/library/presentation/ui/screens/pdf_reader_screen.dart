import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:flutter_ebook_app/src/features/library/data/reading_shelf.dart';

class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({
    super.key,
    required this.bookId,
    required this.path,
    required this.title,
    required this.initialPageNumber,
  });

  final String bookId;
  final String path;
  final String title;
  final int initialPageNumber;

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final Stopwatch _readingSession = Stopwatch();

  @override
  void initState() {
    super.initState();
    _readingSession.start();
  }

  @override
  void dispose() {
    _readingSession.stop();
    unawaited(
      ReadingShelf.addReadingTime(
        id: widget.bookId,
        seconds: _readingSession.elapsed.inSeconds,
      ).catchError((Object error, StackTrace stackTrace) {
        debugPrint('Could not save PDF reading time: $error\n$stackTrace');
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: PdfViewer.file(
          widget.path,
          initialPageNumber: widget.initialPageNumber,
          params: PdfViewerParams(
            enableTextSelection: true,
            onPageChanged: (pageNumber) {
              if (pageNumber == null) return;
              unawaited(
                ReadingShelf.updatePdfPage(
                  id: widget.bookId,
                  page: pageNumber,
                ).catchError((Object error, StackTrace stackTrace) {
                  debugPrint(
                    'Could not save PDF reading position: $error\n$stackTrace',
                  );
                }),
              );
            },
          ),
        ),
      );
}
