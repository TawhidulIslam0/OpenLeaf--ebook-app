import 'package:flutter/material.dart';
import 'package:flutter_ebook_app/src/common/presentation/ui/widgets/error_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fits a catalog error and retry button in a genre card',
      (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 352.7,
              height: 200,
              child: MyErrorWidget(
                message: 'The catalog did not respond within 30 seconds. '
                    'Check your internet connection and retry.',
                refreshCallBack: () => retried = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('TRY AGAIN'), findsOneWidget);

    await tester.tap(find.text('TRY AGAIN'));
    expect(retried, isTrue);
  });
}
