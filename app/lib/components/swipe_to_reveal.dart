import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class SwipeToReveal extends StatefulWidget {
  const SwipeToReveal({
    super.key,
    required this.child,
    required this.onDelete,
    this.label = 'Delete',
  });

  final Widget child;
  final VoidCallback onDelete;
  final String label;

  @override
  State<SwipeToReveal> createState() => _SwipeToRevealState();
}

class _SwipeToRevealState extends State<SwipeToReveal> {
  static const _width = 88.0;

  double _offset = 0;

  bool get _isOpen => _offset > _width / 2;

  void _settle() => setState(() => _offset = _isOpen ? _width : 0);

  void _close() => setState(() => _offset = 0);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: _width,
              child: Material(
                color: colors.danger.withValues(alpha: 0.14),
                child: InkWell(
                  onTap: () {
                    _close();
                    widget.onDelete();
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: colors.danger,
                        size: AppSizes.iconMd,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: colors.danger,
                          fontSize: AppTypeScale.caption,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => setState(
            () => _offset = (_offset - details.delta.dx).clamp(0.0, _width),
          ),
          onHorizontalDragEnd: (_) => _settle(),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.easeOut,
            transform: Matrix4.translationValues(-_offset, 0, 0),
            child: AbsorbPointer(absorbing: _isOpen, child: widget.child),
          ),
        ),
        if (_isOpen)
          Positioned.fill(
            right: _width,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
      ],
    );
  }
}
