import 'package:flutter/material.dart';
import '../services/shop.dart';
import '../widgets/product_card.dart';

class WishlistScreen extends StatelessWidget {
  final Shop shop;
  const WishlistScreen({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shop,
      builder: (context, _) {
        final saved = shop.wishlist
            .map((id) => shop.byId(id))
            .where((p) => p != null)
            .cast<dynamic>()
            .toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Wishlist')),
          body: saved.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_border,
                          size: 50, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('Nothing saved yet',
                          style:
                              TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Text('Tap the heart on any product to save it here.',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 300,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: saved.length,
                  itemBuilder: (_, i) =>
                      ProductCard(product: saved[i], shop: shop, index: i),
                ),
        );
      },
    );
  }
}
