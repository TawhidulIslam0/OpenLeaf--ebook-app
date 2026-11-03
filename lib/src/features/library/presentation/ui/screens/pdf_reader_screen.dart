import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:flutter_ebook_app/src/features/library/data/reading_shelf.dart';

class PdfReaderScreen extends StatelessWidget {
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: PdfViewer.file(
          path,
          initialPageNumber: initialPageNumber,
          params: PdfViewerParams(
            enableTextSelection: true,
            onPageChanged: (pageNumber) {
              if (pageNumber == null) return;
              unawaited(
                ReadingShelf.updatePdfPage(
                  id: bookId,
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
