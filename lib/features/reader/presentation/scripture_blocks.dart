import 'package:flutter/material.dart';

import '../../../domain/entities/bible.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/tokens/app_typography.dart';

/// Renders a chapter (or a verse range of it) as reading blocks: paragraphs
/// split by section headings, superscript verse numbers, red-letter spans.
/// Shared by the reader and the devotion screen's embedded passage.
List<Widget> buildScriptureBlocks(
  BuildContext context,
  Chapter chap,
  double scale,
  bool showVerses, {
  int? fromVerse,
  int? toVerse,
}) {
  final c = context.colors;
  final blocks = <Widget>[];
  var run = <Verse>[];

  void flush() {
    if (run.isEmpty) return;
    final children = <InlineSpan>[];
    for (var i = 0; i < run.length; i++) {
      if (i > 0) children.add(const TextSpan(text: '\n')); // line break between verses
      children.addAll(_verseSpans(context, run[i], showVerses));
    }
    blocks.add(Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text.rich(
        TextSpan(children: children),
        style: AppType.scripture
            .copyWith(color: c.ink, fontSize: AppType.scripture.fontSize! * scale),
      ),
    ));
    run = [];
  }

  for (final v in chap.verses) {
    if (fromVerse != null && v.number < fromVerse) continue;
    if (toVerse != null && v.number > toVerse) continue;
    final heading = chap.headingBefore(v.number);
    if (heading != null) {
      flush();
      blocks.add(Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
        child: Text(heading.text,
            style: AppType.sectionHead
                .copyWith(color: c.ink2, fontSize: AppType.sectionHead.fontSize! * scale)),
      ));
    }
    run.add(v);
  }
  flush();
  return blocks;
}

List<InlineSpan> _verseSpans(BuildContext context, Verse v, bool showVerses) {
  final c = context.colors;
  return [
    if (showVerses)
      WidgetSpan(
        alignment: PlaceholderAlignment.top,
        child: Transform.translate(
          offset: const Offset(0, 1),
          child: Padding(
            padding: const EdgeInsets.only(right: 3, left: 1),
            child: Text(v.display,
                style: AppType.verseNumber.copyWith(color: c.muted)),
          ),
        ),
      ),
    ..._textSpans(context, v),
  ];
}

List<InlineSpan> _textSpans(BuildContext context, Verse v) {
  final wj = v.spans.where((s) => s.kind == SpanKind.wordsOfChrist).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  if (wj.isEmpty) return [TextSpan(text: v.text)];

  final c = context.colors;
  final out = <InlineSpan>[];
  var i = 0;
  for (final s in wj) {
    final start = s.start.clamp(0, v.text.length);
    final end = s.end.clamp(0, v.text.length);
    if (start > i) out.add(TextSpan(text: v.text.substring(i, start)));
    if (end > start) {
      out.add(TextSpan(
          text: v.text.substring(start, end), style: TextStyle(color: c.red)));
    }
    i = end;
  }
  if (i < v.text.length) out.add(TextSpan(text: v.text.substring(i)));
  return out;
}
