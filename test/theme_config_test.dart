import 'package:flutter/material.dart';
import 'package:flutter_ebook_app/src/common/presentation/theme/theme_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dark theme uses a dark scheme with readable foreground colors', () {
    final scheme = darkTheme.colorScheme;

    expect(scheme.brightness, Brightness.dark);
    expect(
      scheme.onSurface.computeLuminance(),
      greaterThan(scheme.surface.computeLuminance()),
    );
    expect(darkTheme.textTheme.bodyMedium?.color, isNot(Colors.black));
  });

  test('light theme retains a light color scheme', () {
    expect(lightTheme.colorScheme.brightness, Brightness.light);
    expect(lightTheme.textTheme.bodyMedium?.color, isNot(Colors.white));
  });
}
