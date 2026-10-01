import 'package:flutter/material.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../widgets/built_by_etech.dart';
import '../widgets/product_card.dart';
import 'deals.dart';
import 'rigs.dart';
import 'account.dart';
import 'chat.dart';
import 'notifications.dart';

class HomeScreen extends StatelessWidget {
  final Shop shop;
  final VoidCallback onBrowse;
  const HomeScreen({super.key, required this.shop, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'e',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: 'Tech',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.red,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'COMPUTER ACCESSORIES',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.5,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          // Prebuilt PCs holds a bottom-bar destination now that it is
          // four shop-facing ranges. Account trades places with it: it is
          // opened once in a while, not browsed, so it sits up here
          // beside Deals.
          //
          // The bell is only there for a signed-in customer: the messages
          // are about their orders, and nobody else has any.
          if (shop.loggedIn)
            IconButton(
              tooltip: 'Notifications',
              icon: Badge(
                isLabelVisible: shop.unreadNotifications > 0,
                label: Text('${shop.unreadNotifications}'),
                child: const Icon(Icons.notifications_none),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NotificationsScreen(shop: shop)),
              ),
            ),
          IconButton(
            tooltip: 'Account',
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AccountScreen(shop: shop)),
            ),
          ),
          IconButton(
            tooltip: 'Deals',
            icon: const Icon(Icons.local_offer_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DealsScreen(shop: shop)),
            ),
          ),
          IconButton(
            tooltip: 'Powered by ASUS',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RigsScreen(shop: shop)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.redDark,
        tooltip: 'Ask the hardware consultant',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(shop: shop)),
        ),
        child: const Icon(Icons.smart_toy_outlined, color: Colors.white),
      ),
      body: shop.loadingProducts && shop.products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : shop.loadError != null
          ? _error(context)
          : RefreshIndicator(
              onRefresh: () => shop.start(),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  _hero(context),
                  // The recommender's row, first thing under the banner.
                  // Signed-in customers only: nobody else has a history
                  // the database can put a name to.
                  if (shop.loggedIn) _picks(context),
                  if (shop.deals.isNotEmpty) _dealStrip(context),
                  const BuiltByEtech(),
                  _section(context, 'Featured', shop.products.take(6).toList()),
                  _section(
                    context,
                    'Popular picks',
                    shop.products
                        .where((p) => p.stock == 'in')
                        .skip(20)
                        .take(6)
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _error(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 46, color: AppTheme.red),
          const SizedBox(height: 14),
          Text(
            shop.loadError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => shop.start(),
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  Widget _hero(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.redDark, AppTheme.redDarker],
      ),
      border: Border(bottom: BorderSide(color: AppTheme.red, width: 4)),
    ),
    child: Column(
      children: [
        const Text(
          'Build Your Dream PC',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Quality computer parts, laptops and gaming gear at student-friendly prices.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onBrowse, child: const Text('Shop Now')),
      ],
    ),
  );

  Widget _dealStrip(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4DD),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFF0D9A8)),
    ),
    child: Row(
      children: [
        const Icon(Icons.local_offer, color: AppTheme.amber),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${shop.deals.length} promotions running — up to '
            '${shop.deals.map((d) => d.discountPercent).reduce((a, b) => a > b ? a : b).round()}% off',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DealsScreen(shop: shop)),
          ),
          child: const Text('View'),
        ),
      ],
    ),
  );

  /// "Picked for you": recommend_for_me(), with the reason the database
  /// gave for each pick under the card. An account with no role yet is
  /// asked for one first, since that is all a brand-new account has to go
  /// on.
  Widget _picks(BuildContext context) {
    final askRole = shop.shopperRole == null;
    if (!askRole && shop.picks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 2),
          child: Text(
            'Picked for you',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            'Based on what you view, save and buy',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        if (askRole) _rolePrompt(context),
        if (shop.picks.isNotEmpty)
          SizedBox(
            height: 290,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: shop.picks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final pick = shop.picks[i];
                return SizedBox(
                  width: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 250,
                        child: ProductCard(product: pick.product, shop: shop),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        pick.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.red,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _rolePrompt(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How do you shop? We will tune these picks to suit.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in Shop.shopperRoles)
                OutlinedButton(
                  onPressed: () async {
                    final error = await shop.setShopperRole(r.value);
                    if (error != null && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(error)));
                    }
                  },
                  child: Text(r.label),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _section(BuildContext context, String title, List products) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => SizedBox(
              width: 160,
              child: ProductCard(product: products[i], shop: shop),
            ),
          ),
        ),
      ],
    );
  }
}
