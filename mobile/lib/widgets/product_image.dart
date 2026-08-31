import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';

/// Shows a product picture.
///
/// Most products use the drawn illustrations, which are SVG files and so
/// need a different widget from an ordinary photo. Those illustrations are
/// bundled into the app now rather than fetched from the website, so they
/// draw instantly and work with no connection at all — hence .asset rather
/// than .network below.
///
/// If a real photo has been uploaded through the admin panel it is a JPEG
/// in Supabase Storage, and that still comes over the network.
class ProductImage extends StatelessWidget {
  final String url;
  final bool isSvg;
  final double height;
  final BoxFit fit;

  const ProductImage({
    super.key,
    required this.url,
    required this.isSvg,
    this.height = 120,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: height,
      alignment: Alignment.center,
      child: const Icon(Icons.inventory_2_outlined, color: AppTheme.line, size: 34),
    );

    if (isSvg) {
      return SizedBox(
        height: height,
        child: SvgPicture.asset(
          url,
          fit: fit,
          placeholderBuilder: (_) => placeholder,
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Image.network(
        url,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
      ),
    );
  }
}

/// The In Stock / Low Stock / Out of Stock pill.
class StockPill extends StatelessWidget {
  final String stock;
  final String label;
  const StockPill({super.key, required this.stock, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.stockBg(stock),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.stockColour(stock))),
    );
  }
}
