import 'package:flutter/material.dart';

class CardImage extends StatelessWidget {
  final String? url;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final String? semanticLabel;

  /// Shown centered on the placeholder background when the network image fails
  /// or the url is null/empty — a much better degraded experience than a bare
  /// grey rectangle when an external image service glitches.
  final IconData? fallbackIcon;

  const CardImage({
    super.key,
    required this.url,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.semanticLabel,
    this.fallbackIcon,
  });

  /// Unified image-source resolver for the whole card system.
  ///
  /// Mock/offline data points at bundled assets (`assets/images/...`), while
  /// the live API returns absolute http(s) URLs. One check here means every
  /// card renders both modes without per-card special-casing — flipping the
  /// real API on later needs zero widget changes.
  static bool isAssetSource(String url) => url.startsWith('assets/');

  /// Resolves an image source string into the matching [ImageProvider]:
  /// bundled asset (`assets/...`) → [AssetImage], http(s) → [NetworkImage].
  /// Returns null for null/empty input so callers can keep their
  /// "no image → no provider" branching.
  ///
  /// [cacheWidth]/[cacheHeight] bound the DECODE size (physical pixels). The
  /// small logo marks pass them so a provider's 512px logo is not decoded at
  /// full size just to fill a 40dp circle.
  static ImageProvider? providerFor(
    String? url, {
    int? cacheWidth,
    int? cacheHeight,
  }) {
    if (url == null || url.isEmpty) return null;
    final ImageProvider provider = isAssetSource(url)
        ? AssetImage(url)
        : NetworkImage(url);
    return ResizeImage.resizeIfNeeded(cacheWidth, cacheHeight, provider);
  }

  /// Decode ceiling (physical pixels). A provider photo can be multi-megapixel
  /// while the card shows at most a phone width; decoding it at source size
  /// costs several MB per card and is what pushed low-RAM Android devices into
  /// the Low Memory Killer on long result lists.
  static const int _maxDecodeWidth = 4096;

  /// The physical width this card will paint at, used as [Image.cacheWidth].
  ///
  /// Falls back to the screen width when the parent gives no bounded width
  /// (e.g. a horizontal rail), so a decode size is always a real number.
  static int _decodeWidthFor(BuildContext context, BoxConstraints constraints) {
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 360.0;
    final layoutWidth = constraints.hasBoundedWidth && constraints.maxWidth > 0
        ? constraints.maxWidth
        : screenWidth;
    if (!layoutWidth.isFinite || layoutWidth <= 0) return 0;
    return (layoutWidth * dpr).round().clamp(1, _maxDecodeWidth);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Brightness-aware placeholder so degradation also looks right in dark mode.
    Widget buildFallback() {
      if (placeholder != null) return placeholder!;
      final fallbackColor = scheme.surfaceContainerHighest;
      if (fallbackIcon == null) {
        return ColoredBox(color: fallbackColor);
      }
      return ColoredBox(
        color: fallbackColor,
        child: Center(
          child: Icon(fallbackIcon, size: 40, color: scheme.onSurfaceVariant),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final int decodeWidth = _decodeWidthFor(context, constraints);

        final Widget image;
        if (url == null || url!.isEmpty) {
          // No photo is not "still loading": a missing URL gets the static
          // fallback, never a shimmer that never ends.
          image = buildFallback();
        } else if (isAssetSource(url!)) {
          image = Image.asset(
            url!,
            fit: fit,
            semanticLabel: semanticLabel,
            cacheWidth: decodeWidth > 0 ? decodeWidth : null,
            errorBuilder: (context, error, stackTrace) => buildFallback(),
          );
        } else {
          image = Image.network(
            url!,
            fit: fit,
            semanticLabel: semanticLabel,
            cacheWidth: decodeWidth > 0 ? decodeWidth : null,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _SkeletonImage();
            },
            errorBuilder: (context, error, stackTrace) => buildFallback(),
          );
        }

        return Semantics(
          label: semanticLabel,
          image: true,
          child: ClipRRect(
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: image,
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonImage extends StatefulWidget {
  const _SkeletonImage();

  @override
  State<_SkeletonImage> createState() => _SkeletonImageState();
}

class _SkeletonImageState extends State<_SkeletonImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.4,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          color: scheme.surfaceContainerHighest.withValues(
            alpha: _animation.value,
          ),
          child: Center(
            child: Icon(
              Icons.image_outlined,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        );
      },
    );
  }
}
