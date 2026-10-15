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
  final VoidCallback onBuild;
  const HomeScreen({
    super.key,
    required this.shop,
    required this.onBrowse,
    required this.onBuild,
  });

  /// The website's department tiles, in the same order.
  static const _departments = [
    'Components', 'Laptops', 'Gaming Gear', 'Monitors',
    'Printers', 'Networking', 'Accessories', 'Branded PC',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            Image.asset('assets/images/etech-logo.png', width: 34, height: 34),
            const SizedBox(width: 8),
            const Text(
              'eTech',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                color: AppTheme.red,
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
                  _departmentTiles(context),
                  // The recommender's row, first thing under the banner.
                  // Signed-in customers only: nobody else has a history
                  // the database can put a name to.
                  if (shop.loggedIn) _picks(context),
                  if (shop.deals.isNotEmpty) _dealStrip(context),
                  const BuiltByEtech(),
                  _section(context, 'Featured products', shop.products.take(6).toList()),
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

  /// The website's Home band: the shop's name over the ROG Hyperion,
  /// on near-black. The case is a still from the website's 3D model
  /// (web/js/hero3d.js, ?hero-still), so both show the same case.
  Widget _hero(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
    height: 300,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppTheme.ink,
      borderRadius: BorderRadius.circular(AppTheme.radius),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -6,
          top: 10,
          bottom: 10,
          child: Image.asset('assets/images/hero-hyperion.png', fit: BoxFit.contain),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const SizedBox(
                width: 210,
                child: Text(
                  'eTech Computer Accessories',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(
                width: 200,
                child: Text(
                  'Computer parts, PCs and laptops, priced in RM. Collect in Bukit Jambul, Penang, or have it delivered.',
                  style: TextStyle(color: Color(0xC7FFFFFF), fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  FilledButton(onPressed: onBrowse, child: const Text('Shop all')),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x80FFFFFF)),
                    ),
                    onPressed: onBuild,
                    child: const Text('Build a PC'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// Departments with their product counts, two to a row, as on the
  /// website. A tap opens the Shop tab filtered to that department.
  Widget _departmentTiles(BuildContext context) {
    final rows = [
      for (final d in _departments)
        (d, shop.products.where((p) => p.category == d).length),
    ].where((r) => r.$2 > 0).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text('Shop by department',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.6,
            children: [
              for (final (name, count) in rows)
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    side: const BorderSide(color: AppTheme.line),
                  ),
                  child: InkWell(
                    onTap: () {
                      shop.browseCategory = name;
                      onBrowse();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          Text('$count',
                              style: const TextStyle(fontSize: 12, color: AppTheme.ink3)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dealStrip(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.brandTint,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      border: Border.all(color: AppTheme.line),
    ),
    child: Row(
      children: [
        const Icon(Icons.local_offer, color: AppTheme.red),
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

  /// "Picked for you": recommend_for_me(), cards only. An account with no role yet is
  /// asked for one first, since that is all a brand-new account has to go
  /// on.
  Widget _picks(BuildContext context) {
    final askRole = shop.shopperRole == null;
    if (!askRole && shop.picks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No explanation under the heading or the cards (user, 1 Oct):
        // like a marketplace's "Recommended for you".
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 10),
          child: Text(
            'Picked for you',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        if (askRole) _rolePrompt(context),
        if (shop.picks.isNotEmpty)
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: shop.picks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(
                width: 160,
                child: ProductCard(product: shop.picks[i].product, shop: shop),
              ),
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
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
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
          height: 300,
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
