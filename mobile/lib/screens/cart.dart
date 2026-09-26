import 'package:flutter/material.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../widgets/product_image.dart';
import 'login.dart';
import 'checkout.dart';

class CartScreen extends StatelessWidget {
  final Shop shop;
  const CartScreen({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Cart')),
      body: !shop.loggedIn
          ? _signInPrompt(context)
          : shop.cart.isEmpty
              ? _empty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 190),
                  itemCount: shop.cart.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final item = shop.cart[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: ProductImage(
                                url: item.imageUrl, isSvg: item.isSvg, height: 52),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3)),
                                if (item.colour != null)
                                  Text('Colour: ${item.colour}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600)),
                                const SizedBox(height: 4),
                                // The line's own price, struck through
                                // when a deal took it down -- the basket
                                // shows the saving rather than quietly
                                // showing a smaller number.
                                if (item.onDeal)
                                  Row(children: [
                                    Text(money(item.listPrice),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                          decoration: TextDecoration.lineThrough,
                                        )),
                                    const SizedBox(width: 6),
                                    Text(money(item.price),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.red)),
                                  ])
                                else
                                  Text(money(item.price),
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey.shade600)),
                                // Upgrades chosen on the prebuilt card.
                                // Listed on the line they belong to,
                                // priced, and removable here -- this is
                                // where the customer confirms them, so
                                // this is where changing their mind has
                                // to be possible.
                                if (item.upgrades.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  ...item.upgrades.map(
                                    (u) => Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.add,
                                              size: 12, color: AppTheme.redDark),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '${u.label}  +${money(u.priceDelta)}',
                                              style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: Colors.grey.shade800),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () => shop.removeUpgrade(
                                                item.id, u.id),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(3),
                                              child: Icon(Icons.close,
                                                  size: 13,
                                                  color: Colors.grey.shade500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _qtyButton(Icons.remove,
                                        () => shop.setQty(item.id, item.qty - 1),
                                        enabled: item.qty > 1),
                                    Padding(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 14),
                                      child: Text('${item.qty}',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    _qtyButton(Icons.add,
                                        () => shop.setQty(item.id, item.qty + 1)),
                                    const Spacer(),
                                    Text(money(item.lineTotal),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.redDark)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppTheme.red, size: 20),
                            onPressed: () => shop.removeFromCart(item.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      bottomSheet: (!shop.loggedIn || shop.cart.isEmpty)
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.line)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        Text(money(shop.cartTotal),
                            style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.redDark)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CheckoutScreen(shop: shop))),
                        child: const Text('Proceed to Checkout'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap, {bool enabled = true}) =>
      InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFEEF0F3) : const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon,
              size: 16, color: enabled ? AppTheme.ink : Colors.grey.shade400),
        ),
      );

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text('Your cart is empty',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
          ],
        ),
      );

  Widget _signInPrompt(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 50, color: Colors.grey.shade400),
              const SizedBox(height: 14),
              const Text('Sign in to use your cart',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                'Your basket is kept with your account, so it follows you '
                'between your phone and the website.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => LoginScreen(shop: shop))),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      );
}
