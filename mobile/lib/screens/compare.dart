import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../widgets/product_image.dart';
import 'product_detail.dart';

/// Up to three products side by side.
///
/// The website has had this since before the catalogue moved into the
/// database; the app never did, so a customer choosing between two
/// graphics cards on a phone had to hold the specs in their head or open
/// two tabs. This is the same feature and the same three-product ceiling,
/// built from the same product attributes, so a row means the same thing
/// on both — see renderComparePage() in web/js/compare.js.
///
/// The one real difference is the direction of the table. The website
/// puts products across the top and specifications down the side, which
/// needs as many columns as products. A phone has room for one column, so
/// this turns the table on its side: one card per specification, with the
/// products across it. Three short values fit; three columns of a real
/// table would not.
class CompareScreen extends StatelessWidget {
  final Shop shop;
  const CompareScreen({super.key, required this.shop});

  /// Specifications first in the order a buyer actually reads them, then
  /// everything else. Matches PREBUILT_SPEC_ORDER on the prebuilt screen
  /// so a machine reads the same way in both places.
  static const List<String> _leadWith = [
    'cpu', 'gpu', 'motherboard', 'ram', 'ssd', 'storageSize',
    'socket', 'ramGen', 'formFactor',
    'screenSize', 'resolution', 'refreshRate', 'panel',
    'capacity', 'speed', 'wattage', 'rating',
    'psu', 'cooler', 'chassis', 'colour', 'sku',
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shop,
      builder: (context, _) {
        final list = shop.compareProducts;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Compare'),
            actions: [
              if (list.isNotEmpty)
                TextButton(
                  onPressed: shop.clearCompare,
                  child: const Text('Clear',
                      style: TextStyle(color: Colors.white)),
                ),
            ],
          ),
          body: list.isEmpty ? _empty(context) : _table(context, list),
        );
      },
    );
  }

  Widget _empty(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.compare_arrows, size: 50, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Nothing to compare yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Open any product and tap the compare button in the top bar. '
            'You can line up ${Shop.maxCompare} at a time.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    ),
  );

  Widget _table(BuildContext context, List<Product> list) {
    // Every specification any of them carries, so a row exists even when
    // only one product has that spec -- which is often the interesting
    // case. The others show a dash.
    final keys = <String>[];
    for (final key in _leadWith) {
      if (list.any((p) => p.attrs.containsKey(key))) keys.add(key);
    }
    for (final p in list) {
      for (final key in p.attrs.keys) {
        if (!keys.contains(key)) keys.add(key);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _headings(context, list),
        const SizedBox(height: 12),
        _row(list, 'Brand', (p) => p.brand),
        _row(list, 'Price', (p) => money(p.price), bold: true),
        _row(list, 'Stock', (p) => shop.stockLabelOf(p)),
        ...keys.map((key) => _row(
              list,
              ProductDetailScreen.specLabel(key),
              (p) {
                final value = p.attrs[key];
                if (value == null) return '—';
                return value is List ? value.join(', ') : '$value';
              },
            )),
      ],
    );
  }

  /// The products themselves, across the top and staying there as the
  /// specifications scroll under them would be nicer still; a phone
  /// scrolls the whole thing, so they are simply first.
  Widget _headings(BuildContext context, List<Product> list) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: list.map((p) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  shop.trackView(p.id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProductDetailScreen(product: p, shop: shop),
                    ),
                  );
                },
                child: ProductImage(
                    url: p.imageUrl, isSvg: p.isSvg, height: 66),
              ),
              const SizedBox(height: 6),
              Text(
                p.name,
                maxLines: 3,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.25),
              ),
              TextButton(
                onPressed: () => shop.toggleCompare(p.id),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Remove',
                    style: TextStyle(fontSize: 11, color: AppTheme.redDark)),
              ),
            ],
          ),
        ),
      );
    }).toList(),
  );

  Widget _row(
    List<Product> list,
    String label,
    String Function(Product) value, {
    bool bold = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: list.map((p) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    value(p),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                      color: bold ? AppTheme.redDark : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
