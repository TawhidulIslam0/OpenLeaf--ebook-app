import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:fimber/fimber.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:iridium_reader_widget/views/viewers/ui/reader_app_bar.dart';
import 'package:iridium_reader_widget/views/viewers/ui/reader_toolbar.dart';
import 'package:mno_commons/utils/functions.dart';
import 'package:mno_navigator/epub.dart';
import 'package:mno_navigator/publication.dart';
import 'package:mno_server/mno_server.dart';
import 'package:mno_shared/publication.dart';
import 'package:mno_streamer/parser.dart';
import 'package:mno_webview/webview.dart';

typedef PaginationCallback = Function(PaginationInfo paginationInfo);

abstract class BookScreen extends StatefulWidget {
  final PublicationAsset asset;
  final ReaderAnnotationRepository? readerAnnotationRepository;
  final PaginationCallback? paginationCallback;

  const BookScreen({
    super.key,
    required this.asset,
    this.readerAnnotationRepository,
    this.paginationCallback,
  });
}

abstract class BookScreenState<T extends BookScreen,
    PubController extends PublicationController> extends State<T> {
  late PubController publicationController;
  late ReaderContext readerContext;

  ReaderAnnotationRepository get readerAnnotationRepository =>
      widget.readerAnnotationRepository ?? InMemoryReaderAnnotationRepository();

  @override
  void initState() {
    super.initState();
    publicationController = createPublicationController(
        onServerClosed,
        null,
        openLocation,
        widget.asset,
        createStreamer(),
        readerAnnotationRepository,
        handlersProvider);
  }

  Future<bool> loadWebViewConfig() async {
    if (Platform.isAndroid) {
      await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
    }
    return true;
  }

  Future<String?> get openLocation async => null;

  Future<Streamer> createStreamer() async => Streamer();

  Function0<List<RequestHandler>> get handlersProvider;

  PubController createPublicationController(
      Function onServerClosed,
      Function? onPageJump,
      Future<String?> locationFuture,
      PublicationAsset fileAsset,
      Future<Streamer> streamerFuture,
      ReaderAnnotationRepository readerAnnotationRepository,
      Function0<List<RequestHandler>> handlersProvider);

  Widget createPublicationNavigator({
    required WidgetBuilder waitingScreenBuilder,
    required WidgetErrorBuilder displayErrorBuilder,
    required Consumer<ReaderContext> onReaderContextCreated,
    required WrapperWidgetBuilder wrapper,
    required PubController publicationController,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: loadWebViewConfig(),
      initialData: false,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.data!) {
          return WillPopScope(
            onWillPop: onWillPop,
            child: Scaffold(
              body: createPublicationNavigator(
                waitingScreenBuilder: buildWaitingScreen,
                displayErrorBuilder: _displayErrorDialog,
                onReaderContextCreated: onReaderContextCreated,
                wrapper: buildWidgetWrapper,
                publicationController: publicationController,
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      });

  Future<bool> onWillPop() async => true;

  Widget buildWaitingScreen(BuildContext context) => Center(
      child: SpinKitChasingDots(
          size: 100, color: Theme.of(context).colorScheme.secondary));

  Widget _displayErrorDialog(
      BuildContext context, UserException userException) {
    Fimber.d("Display error dialog: $userException");
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unable to open book'),
        leading: IconButton(
          tooltip: 'Close reader',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_outlined, size: 48),
              const SizedBox(height: 16),
              const Text(
                'This EPUB could not be opened. Check that the download '
                'completed, then download the book again.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('Back to book'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void onReaderContextCreated(ReaderContext readerContext) {
    this.readerContext = readerContext;
    if (widget.paginationCallback != null) {
      readerContext.currentLocationStream.listen(widget.paginationCallback);
    }
  }

  Widget buildWidgetWrapper(BuildContext context, Widget child,
          List<Link> spineItems, ServerStarted state) =>
      Stack(
        children: <Widget>[
          buildBackground(),
          SafeArea(
            child: child,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ReaderToolbar(
              readerContext: readerContext,
              onSkipLeft: publicationController.onSkipLeft,
              onSkipRight: publicationController.onSkipRight,
            ),
          ),
          SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ReaderAppBar(
                readerContext: readerContext,
                publicationController: publicationController,
              ),
            ),
          ),
        ],
      );

  Widget buildBackground() => const SizedBox.shrink();

  void onServerClosed() => Navigator.pop(context);
}
