import 'package:flutter/material.dart';

import '../../../core/api/endpoints.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

const storyImageRatio = 4 / 5;

String storyImageUrl(String path) =>
    path.startsWith('http') ? path : '${Endpoints.baseUrl.replaceAll('/v1', '')}$path';

class StoryImages extends StatefulWidget {
  const StoryImages({super.key, required this.images, this.onRemove});

  final List<String> images;
  final void Function(String path)? onRemove;

  @override
  State<StoryImages> createState() => _StoryImagesState();
}

class _StoryImagesState extends State<StoryImages> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: storyImageRatio,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pages,
                physics: widget.images.length == 1
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                onPageChanged: (index) => setState(() => _page = index),
                itemCount: widget.images.length,
                itemBuilder: (context, index) => _Frame(
                  path: widget.images[index],
                  onRemove: widget.onRemove,
                ),
              ),
              if (widget.images.length > 1)
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${_page + 1}/${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppTypeScale.caption,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.images.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < widget.images.length; index += 1)
                AnimatedContainer(
                  duration: AppMotion.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == _page ? 7 : 5,
                  height: index == _page ? 7 : 5,
                  decoration: BoxDecoration(
                    color: index == _page ? colors.accent : colors.border,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.path, this.onRemove});

  final String path;
  final void Function(String path)? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          storyImageUrl(path),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            color: colors.surfaceRaised,
            child: Icon(Icons.broken_image_outlined, color: colors.textMuted),
          ),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : Container(color: colors.surfaceRaised),
        ),
        if (onRemove != null)
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: InkWell(
              onTap: () => onRemove!(path),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: AppSizes.iconSm, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
