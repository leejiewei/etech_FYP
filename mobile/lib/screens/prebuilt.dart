import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../widgets/deal_price.dart';
import '../widgets/product_image.dart';
import 'prebuilt_detail.dart';
import 'product_detail.dart';

/// Complete machines, ready to buy.
///
/// The website has had this page since the RigWorks record of 12 August
/// 2026 brought in nineteen real desktops; the app never did, so those
/// machines were reachable on a phone only by finding them among the 389
/// products in the Shop tab. This is the same page, built the same way:
/// the shop's desktops -- Desktops, Branded PC and All-in-One PC --
/// gathered into the four ranges the shop sells against.
///
/// The grouping is deliberately written out rather than derived from the
/// catalogue, and matches PREBUILT_GROUPS in web/js/prebuilt.js. Two
/// reasons: the chips appear in the order the shop thinks in rather than
/// whatever order the rows arrive, and a category added later cannot
/// silently become a fifth chip -- it has to be named here
/// first. The cost is that this list and the website's have to be changed
/// together.
class PrebuiltScreen extends StatefulWidget {
  final Shop shop;
  const PrebuiltScreen({super.key, required this.shop});

  @override
  State<PrebuiltScreen> createState() => _PrebuiltScreenState();

  /// The four ranges, and which catalogue categories feed each. A machine
  /// is matched by its most specific category name -- its sub-category if
  /// it has one, otherwise its category -- because Branded PC and
  /// All-in-One PC stopped being sub-categories of Desktops on
  /// 21 September 2026. The old names stay listed so the screen works on
  /// either side of that rename.
  ///
  /// Office is one range covering two sub-categories. They are the same
  /// kind of machine to a customer -- an E-Tech office tower -- and what
  /// separates the series from the CO1 variants is in the model name,
  /// which is on every card anyway.
  static const Map<String, List<String>> _groups = {
    'Gaming': ['Prebuilt Gaming PCs'],
    'Office': ['Office PC Series', 'Custom Office CO1'],
    'Branded': ['Branded PC', 'Branded Desktops'],
    'AIO PC': ['All-in-One PC', 'AIO Desktops'],
  };

  /// The order specs are listed in. A machine shows the ones it has and
  /// skips the rest, so a tower leads with its processor and graphics
  /// while an all-in-one leads with its processor and screen. Anything
  /// not named here still appears, after these, rather than being lost.
  static const List<String> _specOrder = [
    'cpu',
    'gpu',
    'motherboard',
    'ram',
    'ssd',
    'storageSize',
    'screenSize',
    'resolution',
    'touch',
    'psu',
    'cooler',
    'chassis',
    'colour',
    'sku',
  ];

  /// Which range a machine belongs to, or null if it belongs to none --
  /// in which case this screen does not show it.
  static String? groupOf(Product p) {
    for (final entry in _groups.entries) {
      if (entry.value.contains(p.subcategory ?? p.category)) return entry.key;
    }
    return null;
  }

  /// The record writes upgrade options as prose at the end of a
  /// description -- "Upgrades: +RM499 to RTX 5050 8GB". Shown as a note,
  /// not as priced options: an upgrade is only real once it is a row the
  /// shop can price and stock, and inventing a total on the phone is
  /// exactly what moving the cart into the database was meant to stop.
  static String? upgradeNote(Product p) {
    final match = RegExp(
      r'Upgrades?:\s*([^.]+)',
      caseSensitive: false,
    ).firstMatch(p.description);
    return match?.group(1)?.trim();
  }

  static List<MapEntry<String, dynamic>> orderedSpecs(Product p) {
    final attrs = p.attrs;
    final known = _specOrder.where(attrs.containsKey);
    final rest = attrs.keys.where((k) => !_specOrder.contains(k));
    return [...known, ...rest].map((k) => MapEntry(k, attrs[k])).toList();
  }
}

class _PrebuiltScreenState extends State<PrebuiltScreen> {
  String _filter = 'All';

  String? _groupOf(Product p) => PrebuiltScreen.groupOf(p);

  List<Product> get _machines {
    final list =
        widget.shop.products
            .where((p) => _groupOf(p) != null)
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    if (_filter == 'All') return list;
    return list.where((p) => _groupOf(p) == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.shop,
      builder: (context, _) {
        final machines = _machines;

        // Only ranges that have something in them: a chip that finds
        // nothing when tapped is worse than no chip at all.
        final stocked = widget.shop.products
            .map(_groupOf)
            .whereType<String>()
            .toSet();
        final chips = ['All', ...PrebuiltScreen._groups.keys.where(stocked.contains)];

        return Scaffold(
          appBar: AppBar(title: const Text('Prebuilt PCs')),
          body: Column(
            children: [
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: chips.map((c) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: c == _filter,
                        onSelected: (_) => setState(() => _filter = c),
                        selectedColor: AppTheme.redDark,
                        labelStyle: TextStyle(
                          color: c == _filter ? Colors.white : null,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: machines.isEmpty
                    ? _empty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                        itemCount: machines.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => _machineCard(machines[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _empty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.desktop_windows_outlined,
          size: 50,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 12),
        Text(
          widget.shop.loadingProducts
              ? 'Loading machines…'
              : 'No prebuilt PCs to show',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    ),
  );

  Widget _machineCard(Product p) {
    // Not p.stock. For the shop's own builds this is the answer the
    // parts give -- one component out and the machine is out -- and for
    // everything else it is p.stock unchanged. See Shop.stockOf.
    final stock = widget.shop.stockOf(p);
    final outOfStock = stock == 'out';
    final blockedBy = widget.shop.blockedBy(p);
    final optionCount = widget.shop.upgradesFor(p.id).length;
    final specs = PrebuiltScreen.orderedSpecs(p);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
        
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The picture and the name open the machine's own screen, where
          // the upgrades are chosen. See prebuilt_detail.dart.
          InkWell(
            onTap: () => _open(p),
            child: Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFFFAFBFC),
                border: Border.all(color: const Color(0xFFE8EAED)),
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              padding: const EdgeInsets.all(8),
              child: ProductImage(url: p.imageUrl, isSvg: p.isSvg, height: 130),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFDE7E9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _groupOf(p) ?? '',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.redDark,
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _open(p),
            child: Text(
              p.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          StockPill(stock: stock, label: widget.shop.stockLabelOf(p)),
          // Saying which part is missing is the difference between a
          // customer giving up and a customer asking when it is back.
          if (blockedBy != null) ...[
            const SizedBox(height: 6),
            Text(
              'Waiting on: $blockedBy',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
          if (specs.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...specs.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${ProductDetailScreen.specLabel(s.key)}: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      TextSpan(
                        text: s.value is List
                            ? (s.value as List).join(', ')
                            : '${s.value}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          DealPriceText(product: p, shop: widget.shop, size: 19),
          // The upgrades themselves are chosen on the machine's own
          // screen; the card only says there are some, so the list stays
          // easy to scan.
          if (optionCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '$optionCount upgrade option${optionCount == 1 ? '' : 's'} available',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _open(p),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.redDark,
                    side: const BorderSide(color: AppTheme.redDark),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
                  child: Text(optionCount > 0 ? 'Customise' : 'View details'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: outOfStock ? null : () => _add(p),
                  child: Text(outOfStock ? 'Out of Stock' : 'Add to Cart'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Opening a machine's screen is a view, the same path a product card
  /// takes, so a prebuilt counts for exactly as much as anything else.
  void _open(Product p) {
    widget.shop.trackView(p.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrebuiltDetailScreen(product: p, shop: widget.shop),
      ),
    );
  }

  /// The card's own Add button buys the standard build. Upgrades are
  /// added from the machine's screen.
  Future<void> _add(Product p) async {
    final error = await widget.shop.addToCart(p.id, upgradeIds: const []);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? '${p.name} added to your cart.')),
    );
  }
}
