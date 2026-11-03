import 'package:flutter/widgets.dart' hide SelectionListener;
import 'package:mno_navigator/epub.dart';
import 'package:mno_navigator/src/publication/reader_context.dart';

abstract class SelectionListenerFactory {
  SelectionListener create(ReaderContext readerContext, BuildContext context);
}

class SimpleSelectionListenerFactory extends SelectionListenerFactory {
  final State state;
  final ValueChanged<String>? onTextSelected;

  SimpleSelectionListenerFactory(this.state, {this.onTextSelected});

  @override
  SelectionListener create(ReaderContext readerContext, BuildContext context) =>
      _TextSelectionListener(
        state,
        readerContext,
        context,
        onTextSelected,
      );
}

class _TextSelectionListener extends SimpleSelectionListener {
  final ValueChanged<String>? onTextSelected;

  _TextSelectionListener(
    super.state,
    super.readerContext,
    super.context,
    this.onTextSelected,
  );

  @override
  void displayPopup(Selection selection) {
    final selectedText = selection.locator.text.highlight?.trim();
    if (selectedText != null && selectedText.isNotEmpty) {
      onTextSelected?.call(selectedText);
    }
    super.displayPopup(selection);
  }
}
