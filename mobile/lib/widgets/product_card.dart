import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../screens/product_detail.dart';
import 'deal_price.dart';
import 'product_image.dart';

/// One product in a grid or list.
class ProductCard extends StatelessWidget {
  final Product product;
  final Shop shop;
  const ProductCard({super.key, required this.product, required this.shop});

  @override
  Widget build(BuildContext context) {
    final saved = shop.inWishlist(product.id);

    return InkWell(
      onTap: () {
        shop.trackView(product.id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product, shop: shop),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: const Border(top: BorderSide(color: AppTheme.red, width: 3)),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 5, offset: Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Center(
                    child: ProductImage(
                        url: product.imageUrl, isSvg: product.isSvg, height: 88)),
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
                    child: Icon(
                      saved ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: saved ? AppTheme.red : Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, height: 1.25),
            ),
            const SizedBox(height: 3),
            Text(product.categoryPath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const Spacer(),
            const SizedBox(height: 6),
            // shop.stockOf, not product.stock: one of the shop's own
            // builds is only available when its parts are, and it has to
            // read the same here as on the Prebuilt tab.
            StockPill(
              stock: shop.stockOf(product),
              label: shop.stockLabelOf(product),
            ),
            const SizedBox(height: 6),
            // shop.priceOf, not product.price: a product with a deal
            // running shows the old price struck through and the deal
            // price under it, which is what the checkout will charge.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: DealPriceText(product: product, shop: shop)),
                // The maker's own spec page, so the full details are one
                // tap away without opening the product first.
                if (product.officialUrl != null)
                  InkWell(
                    onTap: () =>
                        ProductDetailScreen.openOfficial(context, product),
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(6, 6, 0, 2),
                      child: Text(
                        'Specs ↗',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.red),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
