import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';

/// Renders the sanitized HTML of the back-office editor (descriptions, regulations):
/// paragraphs, headings, bold / italic, lists, quotes, links (as text). No web view,
/// no dependency: a few blocks of rich text.
class RichHtml extends StatelessWidget {
  const RichHtml(this.html, {super.key});

  final String html;

  @override
  Widget build(BuildContext context) {
    final blocks = parseHtmlBlocks(html);
    final c = context.colors;
    final body = context.text.bodyLarge!.copyWith(color: c.text, height: 1.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: switch (block.kind) {
              HtmlBlockKind.heading => Text.rich(_spans(block.inline, context.text.titleMedium!.copyWith(fontWeight: FontWeight.w700), c)),
              HtmlBlockKind.bullet || HtmlBlockKind.numbered => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 24, child: Text(block.kind == HtmlBlockKind.bullet ? '•' : '${block.index}.', style: body.copyWith(color: c.accent))),
                    Expanded(child: Text.rich(_spans(block.inline, body, c))),
                  ],
                ),
              HtmlBlockKind.quote => Container(
                  padding: const EdgeInsets.only(left: Space.md),
                  decoration: BoxDecoration(border: Border(left: BorderSide(color: c.primary, width: 3))),
                  child: Text.rich(_spans(block.inline, body.copyWith(fontStyle: FontStyle.italic, color: c.textMuted), c)),
                ),
              HtmlBlockKind.paragraph => Text.rich(_spans(block.inline, body, c)),
            },
          ),
      ],
    );
  }

  TextSpan _spans(List<HtmlRun> runs, TextStyle base, AppColors c) => TextSpan(
        style: base,
        children: [
          for (final run in runs)
            TextSpan(
              text: run.text,
              style: TextStyle(
                fontWeight: run.bold ? FontWeight.w700 : null,
                fontStyle: run.italic ? FontStyle.italic : null,
                color: run.link ? c.accent : null,
                decoration: run.link ? TextDecoration.underline : null,
              ),
            ),
        ],
      );
}

enum HtmlBlockKind { paragraph, heading, bullet, numbered, quote }

class HtmlRun {
  const HtmlRun(this.text, {this.bold = false, this.italic = false, this.link = false});

  final String text;
  final bool bold;
  final bool italic;
  final bool link;
}

class HtmlBlock {
  HtmlBlock(this.kind, {this.index = 0});

  final HtmlBlockKind kind;
  final int index;
  final List<HtmlRun> inline = [];

  bool get isEmpty => inline.every((r) => r.text.trim().isEmpty);
}

/// Splits sanitized HTML into blocks of styled runs (exposed for tests).
List<HtmlBlock> parseHtmlBlocks(String html) {
  final blocks = <HtmlBlock>[];
  HtmlBlock? current;
  var bold = 0, italic = 0, link = 0, listIndex = 0;
  var ordered = false;

  HtmlBlock open(HtmlBlockKind kind, {int index = 0}) {
    if (current != null && !current!.isEmpty) blocks.add(current!);
    return current = HtmlBlock(kind, index: index);
  }

  void close() {
    if (current != null && !current!.isEmpty) blocks.add(current!);
    current = null;
  }

  for (final token in RegExp(r'<(/?)([a-zA-Z0-9]+)[^>]*>|([^<]+)').allMatches(html)) {
    final text = token.group(3);
    if (text != null) {
      final clean = _entities(text.replaceAll(RegExp(r'\s+'), ' '));
      if (clean.trim().isEmpty && current == null) continue;
      (current ?? open(HtmlBlockKind.paragraph)).inline.add(HtmlRun(clean, bold: bold > 0, italic: italic > 0, link: link > 0));
      continue;
    }
    final closing = token.group(1) == '/';
    switch (token.group(2)!.toLowerCase()) {
      case 'p' || 'div':
        closing ? close() : open(HtmlBlockKind.paragraph);
      case 'h1' || 'h2' || 'h3' || 'h4':
        closing ? close() : open(HtmlBlockKind.heading);
      case 'blockquote':
        closing ? close() : open(HtmlBlockKind.quote);
      case 'ul':
        ordered = false;
        if (closing) close();
      case 'ol':
        ordered = true;
        listIndex = 0;
        if (closing) close();
      case 'li':
        closing ? close() : open(ordered ? HtmlBlockKind.numbered : HtmlBlockKind.bullet, index: ++listIndex);
      case 'br':
        current?.inline.add(const HtmlRun('\n'));
      case 'strong' || 'b':
        bold += closing ? -1 : 1;
      case 'em' || 'i':
        italic += closing ? -1 : 1;
      case 'a':
        link += closing ? -1 : 1;
    }
  }
  close();
  return blocks;
}

String _entities(String text) => text
    .replaceAllMapped(RegExp(r'&#(x?)([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m.group(2)!, radix: m.group(1)!.isEmpty ? 10 : 16);
      return code == null ? m.group(0)! : String.fromCharCode(code);
    })
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&rsquo;', '’')
    .replaceAll('&laquo;', '«')
    .replaceAll('&raquo;', '»');
