import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class ExpandableText extends StatefulWidget {
  const ExpandableText({
    super.key,
    required this.text,
    this.collapsedLines = 3,
    this.onTapWhenShort,
  });

  final TextSpan text;
  final int collapsedLines;
  final VoidCallback? onTapWhenShort;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: widget.text,
          maxLines: widget.collapsedLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: overflows
                  ? () => setState(() => _isExpanded = !_isExpanded)
                  : widget.onTapWhenShort,
              child: RichText(
                text: widget.text,
                maxLines: _isExpanded ? null : widget.collapsedLines,
                overflow: _isExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
              ),
            ),
            if (overflows)
              GestureDetector(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _isExpanded ? 'less' : 'more',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: AppTypeScale.label,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
