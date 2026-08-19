import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DoubleTapLike extends StatefulWidget {
  const DoubleTapLike({
    super.key,
    required this.child,
    required this.isLiked,
    this.onLike,
    this.onTap,
    this.size = 96,
  });

  final Widget child;
  final bool isLiked;
  final VoidCallback? onLike;

  /// A single tap, once the gesture arena has ruled out a second one.
  final VoidCallback? onTap;
  final double size;

  @override
  State<DoubleTapLike> createState() => _DoubleTapLikeState();
}

class _DoubleTapLikeState extends State<DoubleTapLike>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.2, end: 1.25).chain(
        CurveTween(curve: Curves.easeOutBack),
      ),
      weight: 26,
    ),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 14),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 34),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.7), weight: 26),
  ]).animate(_controller);

  late final Animation<double> _fade = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 14),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 26),
  ]).animate(_controller);

  late final Animation<double> _shake = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 26),
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.14), weight: 12),
    TweenSequenceItem(tween: Tween(begin: -0.14, end: 0.11), weight: 12),
    TweenSequenceItem(tween: Tween(begin: 0.11, end: -0.07), weight: 12),
    TweenSequenceItem(tween: Tween(begin: -0.07, end: 0.04), weight: 12),
    TweenSequenceItem(tween: Tween(begin: 0.04, end: 0.0), weight: 26),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (widget.onLike == null) return;

    widget.onLike!.call();
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTap: widget.onLike == null ? null : _handleDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => _controller.isAnimating
                      ? Opacity(
                          opacity: _fade.value.clamp(0.0, 1.0),
                          child: Transform.rotate(
                            angle: _shake.value,
                            child: Transform.scale(
                              scale: _scale.value,
                              child: child,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                  child: Icon(
                    Icons.favorite,
                    size: widget.size,
                    color: colors.like,
                    shadows: const [
                      Shadow(color: Colors.black45, blurRadius: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
