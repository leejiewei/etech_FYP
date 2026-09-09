import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cart_item.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../widgets/product_card.dart';

/// Two different things share this screen, and they are worth keeping
/// apart in your head:
///
///   Timed deals    a price on one product until a stated moment.
///                  Nothing is typed in; the shopper sees the old price
///                  struck through and a clock running down, and that is
///                  what the checkout charges. From the deals table.
///
///   Promotions     a coupon code for a whole category, typed at the
///                  checkout for a percentage off the order. From the
///                  coupons table.
///
/// Neither list is filtered here. The policies on both tables only ever
/// return what is running, so this screen cannot show a dead one by
/// mistake — a stronger guarantee than remembering to filter.
class DealsScreen extends StatelessWidget {
  final Shop shop;
  const DealsScreen({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    final timed = shop.dealProducts;

    return Scaffold(
      appBar: AppBar(title: const Text('Deals')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          _heading("Today's Deals",
              'A price on the product itself, until the clock runs out. '
              'No code to type.'),
          if (timed.isEmpty)
            _emptyNote(Icons.schedule, 'No timed deals are running right now')
          else
            GridView.builder(
              shrinkWrap: true,
              // The page scrolls, not the grid inside it. Two scrollable
              // areas one inside the other is a thing nobody can use.
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.62,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: timed.length,
              itemBuilder: (_, i) => ProductCard(product: timed[i], shop: shop),
            ),
          const SizedBox(height: 26),
          _heading('Promotion Codes',
              'Type one of these at the checkout for money off a whole '
              'category.'),
          if (shop.deals.isEmpty)
            _emptyNote(
                Icons.local_offer_outlined, 'No promotions running right now')
          else
            ...shop.deals.map((deal) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _couponCard(context, deal),
                )),
        ],
      ),
    );
  }

  Widget _heading(String title, String sub) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(sub,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          ],
        ),
      );

  Widget _emptyNote(IconData icon, String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Column(
          children: [
            Icon(icon, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(message, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );

  Widget _couponCard(BuildContext context, Deal deal) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: const Border(top: BorderSide(color: AppTheme.red, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${deal.discountPercent.round()}%',
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.red)),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text('OFF',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.red)),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF0F3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(deal.category ?? 'Everything',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(deal.description,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: deal.code));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Code ${deal.code} copied — '
                      'paste it at checkout'),
                ));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AppTheme.red,
                      width: 1.4,
                      style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFFDF2F3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(deal.code,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: AppTheme.redDark)),
                    const SizedBox(width: 10),
                    const Icon(Icons.copy, size: 16, color: AppTheme.redDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
