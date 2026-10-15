import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../screens/product_detail.dart';
import 'deal_price.dart';
import 'product_image.dart';

/// One product in a grid, the same card as the website's: the photo,
/// then category, name, item number, stock, the price, and a labelled
/// Add to cart. The whole card opens the product; only the heart and the
/// button do something else.
class ProductCard extends StatelessWidget {
  final Product product;
  final Shop shop;
  const ProductCard({super.key, required this.product, required this.shop});

  void _open(BuildContext context) {
    shop.trackView(product.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product, shop: shop),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = shop.inWishlist(product.id);
    // shop.stockOf, not product.stock: one of the shop's own builds is
    // only available when its parts are, and it has to read the same
    // here as on the Prebuilt tab.
    final stock = shop.stockOf(product);
    final out = stock == 'out';
    final hasOptions = product.colourOptions.isNotEmpty;
    final switches = hasOptions && product.colourOptions.every((o) => o.endsWith(' Switch'));

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: const BorderSide(color: AppTheme.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 104,
                    width: double.infinity,
                    child: Center(
                        child: ProductImage(
                            url: product.imageUrl, isSvg: product.isSvg, height: 100)),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: InkWell(
                      onTap: () async {
                        final error = await shop.toggleWishlist(product.id);
                        if (error != null && context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(error)));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: AppTheme.line),
                        ),
                        child: Icon(
                          saved ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: saved ? AppTheme.red : AppTheme.ink3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(product.categoryPath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppTheme.ink3)),
              const SizedBox(height: 2),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.25),
              ),
              const SizedBox(height: 2),
              Text('Item ${product.id}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.ink3)),
              const SizedBox(height: 4),
              StockPill(stock: stock, label: shop.stockLabelOf(product)),
              const Spacer(),
              // shop.priceOf, not product.price: a product with a deal
              // running shows the old price struck through and the deal
              // price under it, which is what the checkout will charge.
              DealPriceText(product: product, shop: shop),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  icon: out ? const SizedBox.shrink() : const Icon(Icons.shopping_cart_outlined, size: 16),
                  label: Text(out
                      ? 'Out of stock'
                      : hasOptions
                          ? (switches ? 'Choose switch' : 'Choose colour')
                          : 'Add to cart'),
                  // A product sold in several colours opens, so the
                  // colour is picked where it can be seen.
                  onPressed: out
                      ? null
                      : hasOptions
                          ? () => _open(context)
                          : () async {
                              final error = await shop.addToCart(product.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(error ?? '${product.name} added to cart'),
                                duration: const Duration(seconds: 2),
                              ));
                            },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
