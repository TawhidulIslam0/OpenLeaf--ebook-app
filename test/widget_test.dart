import 'package:flutter/material.dart';
import 'package:flutter_ebook_app/src/features/search/presentation/ui/screens/search_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows an empty catalog search without sample data',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SearchScreen()),
    );

    expect(find.text('Find your next read'), findsOneWidget);
    expect(find.text('Search the library'), findsOneWidget);
    expect(find.text('Explore science fiction'), findsOneWidget);
    expect(find.text('0 results'), findsNothing);
  });
}
