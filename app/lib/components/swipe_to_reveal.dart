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
  bool _isDragging = false;

  bool get _isOpen => _offset >= _width;

  void _close() => setState(() {
    _isDragging = false;
    _offset = 0;
  });

  void _drag(DragUpdateDetails details) => setState(() {
    _isDragging = true;
    _offset = (_offset - details.delta.dx).clamp(0.0, _width);
  });

  void _settle(DragEndDetails details) {
    final flung = details.primaryVelocity ?? 0;

    setState(() {
      _isDragging = false;
      if (flung < -320) {
        _offset = _width;
      } else if (flung > 320) {
        _offset = 0;
      } else {
        _offset = _offset > _width * 0.4 ? _width : 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _drag,
      onHorizontalDragEnd: _settle,
      onTap: _isOpen ? _close : null,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: _width,
                child: ColoredBox(
                  color: colors.danger.withValues(alpha: 0.14),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
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
          AnimatedContainer(
            duration: _isDragging ? Duration.zero : AppMotion.base,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(-_offset, 0, 0),
            child: ColoredBox(
              color: colors.bg,
              child: AbsorbPointer(absorbing: _isOpen, child: widget.child),
            ),
          ),
        ],
      ),
    );
  }
}
