import 'package:flutter/material.dart';
import '../responsive_helper.dart';
import 'shimmer_loading.dart';

/// Responsive Image Widget - Automatically loads appropriate image sizes
class ResponsiveImage extends StatelessWidget {
  final String imageUrl;
  final String? smallImageUrl;
  final String? mediumImageUrl;
  final String? largeImageUrl;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double? aspectRatio;
  final Alignment alignment;
  final Color? color;
  final BlendMode? colorBlendMode;
  final Map<String, String>? headers;

  const ResponsiveImage({
    super.key,
    required this.imageUrl,
    this.smallImageUrl,
    this.mediumImageUrl,
    this.largeImageUrl,
    this.placeholder,
    this.errorWidget,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.aspectRatio,
    this.alignment = Alignment.center,
    this.color,
    this.colorBlendMode,
    this.headers,
  });

  String _getImageUrl(BuildContext context) {
    if (ResponsiveHelper.isSmallDevice(context) && smallImageUrl != null) {
      return smallImageUrl!;
    } else if (ResponsiveHelper.isMediumDevice(context) && mediumImageUrl != null) {
      return mediumImageUrl!;
    } else if (ResponsiveHelper.isLargeDevice(context) && largeImageUrl != null) {
      return largeImageUrl!;
    }
    return imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _getImageUrl(context);
    final responsiveWidth = width != null
        ? ResponsiveHelper.getResponsiveWidth(context, width!)
        : null;
    final responsiveHeight = height != null
        ? ResponsiveHelper.getResponsiveHeight(context, height!)
        : null;

    Widget imageWidget = Image.network(
      imageUrl,
      width: responsiveWidth,
      height: responsiveHeight,
      fit: fit,
      alignment: alignment,
      color: color,
      colorBlendMode: colorBlendMode,
      headers: headers,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ??
            ShimmerContainer(
              width: responsiveWidth,
              height: responsiveHeight,
            );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ??
            Container(
              width: responsiveWidth,
              height: responsiveHeight,
              color: Colors.grey.shade300,
              child: Icon(
                Icons.broken_image,
                size: ResponsiveHelper.getResponsiveSize(context, 48),
                color: Colors.grey.shade600,
              ),
            );
      },
    );

    if (aspectRatio != null) {
      imageWidget = AspectRatio(
        aspectRatio: aspectRatio!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
