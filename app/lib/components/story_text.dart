import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

enum StoryBlockKind { paragraph, heading, bullet, rule }

class StoryBlock {
  const StoryBlock(this.kind, this.text);

  final StoryBlockKind kind;
  final String text;
}

final _emphasis = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|_(.+?)_');
final _headingLine = RegExp(r'^\*\*(.+)\*\*$');
final _bulletLine = RegExp(r'^\s*[-*•]\s+(.*)$');
final _ruleLine = RegExp(r'^\s*[-–—_*]{3,}\s*$');

List<StoryBlock> parseStoryBlocks(String source) {
  final blocks = <StoryBlock>[];
  final paragraph = StringBuffer();

  void flush() {
    final text = paragraph.toString().trim();
    if (text.isNotEmpty) blocks.add(StoryBlock(StoryBlockKind.paragraph, text));
    paragraph.clear();
  }

  for (final raw in source.split('\n')) {
    final line = raw.trimRight();

    if (line.trim().isEmpty) {
      flush();
      continue;
    }

    if (_ruleLine.hasMatch(line)) {
      flush();
      blocks.add(const StoryBlock(StoryBlockKind.rule, ''));
      continue;
    }

    final heading = _headingLine.firstMatch(line.trim());
    if (heading != null) {
      flush();
      blocks.add(StoryBlock(StoryBlockKind.heading, heading.group(1)!.trim()));
      continue;
    }

    final bullet = _bulletLine.firstMatch(line);
    if (bullet != null) {
      flush();
      blocks.add(StoryBlock(StoryBlockKind.bullet, bullet.group(1)!.trim()));
      continue;
    }

    if (paragraph.isNotEmpty) paragraph.write(' ');
    paragraph.write(line.trim());
  }

  flush();
  return blocks;
}

List<InlineSpan> _spansOf(String text) {
  final spans = <InlineSpan>[];
  var cursor = 0;

  for (final match in _emphasis.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }

    final bold = match.group(1);
    if (bold != null) {
      spans.add(
        TextSpan(
          text: bold,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: match.group(2) ?? match.group(3),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }
    cursor = match.end;
  }

  if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
  return spans.isEmpty ? [TextSpan(text: text)] : spans;
}

String plainStoryText(String source) {
  final buffer = StringBuffer();
  for (final block in parseStoryBlocks(source)) {
    if (block.kind == StoryBlockKind.rule) continue;
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(
      block.text.replaceAllMapped(_emphasis, (match) {
        return match.group(1) ?? match.group(2) ?? match.group(3) ?? '';
      }),
    );
  }
  return buffer.toString();
}

class StoryText extends StatelessWidget {
  const StoryText({super.key, required this.text, required this.fontSize});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final blocks = parseStoryBlocks(text);

    final body = TextStyle(
      color: colors.textPrimary,
      fontSize: fontSize,
      height: 1.75,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          if (index > 0)
            SizedBox(
              height: blocks[index].kind == StoryBlockKind.heading
                  ? AppSpacing.xl
                  : AppSpacing.md,
            ),
          switch (blocks[index].kind) {
            StoryBlockKind.heading => SelectableText.rich(
              TextSpan(
                children: _spansOf(blocks[index].text),
                style: body.copyWith(fontWeight: FontWeight.w600, height: 1.4),
              ),
            ),
            StoryBlockKind.bullet => Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: fontSize * 0.55),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SelectableText.rich(
                      TextSpan(
                        children: _spansOf(blocks[index].text),
                        style: body,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            StoryBlockKind.rule => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(
                color: colors.border,
                thickness: AppSizes.hairline,
                height: AppSizes.hairline,
              ),
            ),
            StoryBlockKind.paragraph => SelectableText.rich(
              TextSpan(children: _spansOf(blocks[index].text), style: body),
            ),
          },
        ],
      ],
    );
  }
}
