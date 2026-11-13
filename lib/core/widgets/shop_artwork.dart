import 'package:flutter/material.dart';

/// Compact shop illustration — uses decode-size limits so the asset isn't
/// decoded at full resolution for small list / banner slots.
class Shop3DArtworkWidget extends StatelessWidget {
  final double width;
  final double height;

  const Shop3DArtworkWidget({
    super.key,
    this.width = 90,
    this.height = 90,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = (width * dpr).round().clamp(64, 512);
    final cacheH = (height * dpr).round().clamp(64, 512);
    return Image.asset(
      'assets/images/shop.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      cacheWidth: cacheW,
      cacheHeight: cacheH,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, err, stack) {
        return Image.asset(
          'assets/images/shop-banner.png',
          width: width,
          height: height,
          fit: BoxFit.contain,
          cacheWidth: cacheW,
          cacheHeight: cacheH,
          errorBuilder: (context, err2, stack2) {
            return SizedBox(
              width: width,
              height: height,
              child: const Icon(Icons.storefront_rounded, color: Color(0xFFDB0215)),
            );
          },
        );
      },
    );
  }
}
