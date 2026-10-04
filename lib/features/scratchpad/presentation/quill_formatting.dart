import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../render/markdown_quill_bridge.dart';

/// Toggles a Quill attribute on the current selection without writing markup.
void toggleQuillAttribute(QuillController controller, Attribute attribute) {
  final current = controller.getSelectionStyle().attributes[attribute.key];
  final enabled = current != null && current.value == attribute.value;
  controller.formatSelection(
    enabled ? Attribute.clone(attribute, null) : attribute,
  );
}

/// Cycles the current block through Heading 1, Heading 2, and body text.
void cycleQuillHeading(QuillController controller) {
  final level = controller.getSelectionStyle().attributes[Attribute.header.key]?.value;
  if (level == 1) {
    controller.formatSelection(Attribute.h2);
  } else if (level == 2) {
    controller.formatSelection(Attribute.clone(Attribute.header, null));
  } else {
    controller.formatSelection(Attribute.h1);
  }
}

/// Toggles inline code, or a code block when the selection spans lines.
void toggleQuillCode(QuillController controller) {
  final selection = controller.selection;
  final plain = controller.document.toPlainText();
  final start = selection.isValid ? selection.start : 0;
  final end = selection.isValid ? selection.end : start;
  final safeStart = start.clamp(0, plain.length);
  final safeEnd = end.clamp(0, plain.length);
  final selected = plain.substring(safeStart, safeEnd);
  if (selected.contains('\n')) {
    toggleQuillAttribute(controller, Attribute.codeBlock);
  } else {
    toggleQuillAttribute(controller, Attribute.inlineCode);
  }
}

/// Inserts a slide-break embed on its own line and places the caret after it.
void insertQuillSlideBreak(QuillController controller) {
  final selection = controller.selection;
  final length = controller.document.length;
  final index = selection.isValid
      ? selection.start.clamp(0, length)
      : (length == 0 ? 0 : length - 1);
  final span = selection.isValid ? selection.end - selection.start : 0;

  if (span > 0) {
    controller.replaceText(index, span, '', null);
  }

  var cursor = index;
  final before = controller.document.toPlainText();
  final needsLeadingBreak =
      cursor > 0 && cursor <= before.length && before[cursor - 1] != '\n';
  if (needsLeadingBreak) {
    controller.replaceText(cursor, 0, '\n', null);
    cursor += 1;
  }

  controller.replaceText(
    cursor,
    0,
    BlockEmbed.custom(const SlideBreakEmbed()),
    null,
  );
  cursor += 1;

  final after = controller.document.toPlainText();
  final needsTrailingBreak =
      cursor >= after.length || (cursor < after.length && after[cursor] != '\n');
  if (needsTrailingBreak) {
    controller.replaceText(cursor, 0, '\n', null);
    cursor += 1;
  }

  final maxOffset = controller.document.length - 1;
  final offset = cursor.clamp(0, maxOffset < 0 ? 0 : maxOffset);
  controller.updateSelection(
    TextSelection.collapsed(offset: offset),
    ChangeSource.local,
  );
}
