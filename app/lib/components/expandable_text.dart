import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'text_measure.dart';

class ExpandableText extends StatefulWidget {
  const ExpandableText({
    super.key,
    required this.text,
    this.expandedText,
    this.onExpand,
    this.maxExpandedHeight,
    this.collapsedLines = 3,
    this.onTapWhenShort,
    this.onTooLong,
    this.inlineLines = 10,
  });

  final TextSpan text;
  final TextSpan? expandedText;
  final Future<TextSpan?> Function()? onExpand;
  final double? maxExpandedHeight;
  final int collapsedLines;
  final VoidCallback? onTapWhenShort;
  final ValueChanged<TextSpan>? onTooLong;
  final int inlineLines;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;
  bool _isLoading = false;
  double _width = 0;

  Future<void> _toggle() async {
    if (_isExpanded) {
      setState(() => _isExpanded = false);
      return;
    }

    final load = widget.onExpand;
    TextSpan? loaded;
    if (load != null && !_isLoading) {
      setState(() => _isLoading = true);
      loaded = await load();
      if (!mounted) return;
      setState(() => _isLoading = false);
    }

    if (!mounted) return;

    final whole = loaded ?? widget.expandedText ?? widget.text;
    final roomNeeded = widget.onTooLong;

    if (roomNeeded != null &&
        longerThanLines(
          span: whole,
          width: _width,
          lines: widget.inlineLines,
          direction: Directionality.of(context),
          scaler: MediaQuery.textScalerOf(context),
        )) {
      roomNeeded(whole);
      return;
    }

    setState(() => _isExpanded = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final span = _isExpanded ? (widget.expandedText ?? widget.text) : widget.text;

    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;

        final painter = TextPainter(
          text: widget.text,
          maxLines: widget.collapsedLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;

        Widget body = RichText(
          text: span,
          maxLines: _isExpanded ? null : widget.collapsedLines,
          overflow: _isExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
        );

        if (_isExpanded && widget.maxExpandedHeight != null) {
          body = ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxExpandedHeight!),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: body,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: overflows ? _toggle : widget.onTapWhenShort,
              child: body,
            ),
            if (overflows)
              GestureDetector(
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _isLoading
                      ? SizedBox(
                          width: AppTypeScale.label,
                          height: AppTypeScale.label,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        )
                      : Text(
                          _isExpanded ? 'less' : 'more',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: AppTypeScale.label,
                            fontWeight: FontWeight.w500,
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
