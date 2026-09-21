import 'package:flutter/material.dart';
import '../models/prebuilt.dart';
import '../models/product.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../widgets/deal_price.dart';
import '../widgets/product_image.dart';
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
}

class _PrebuiltScreenState extends State<PrebuiltScreen> {
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

  String _filter = 'All';

  /// The upgrades ticked on each machine's card, by machine id. Held on
  /// the screen rather than in the basket, because nothing has been
  /// bought yet -- they travel to the basket with the Add button, and
  /// the cart screen is where they become real.
  final Map<int, Set<int>> _chosen = {};

  Set<int> _chosenFor(int id) => _chosen.putIfAbsent(id, () => <int>{});

  /// Which range a machine belongs to, or null if it belongs to none --
  /// in which case this screen does not show it.
  String? _groupOf(Product p) {
    for (final entry in _groups.entries) {
      if (entry.value.contains(p.subcategory ?? p.category)) return entry.key;
    }
    return null;
  }

  List<Product> get _machines {
    final list =
        widget.shop.products
            .where((p) => _groupOf(p) != null)
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    if (_filter == 'All') return list;
    return list.where((p) => _groupOf(p) == _filter).toList();
  }

  /// The record writes upgrade options as prose at the end of a
  /// description -- "Upgrades: +RM499 to RTX 5050 8GB". Shown as a note,
  /// not as priced options: an upgrade is only real once it is a row the
  /// shop can price and stock, and inventing a total on the phone is
  /// exactly what moving the cart into the database was meant to stop.
  String? _upgradeNote(Product p) {
    final match = RegExp(
      r'Upgrades?:\s*([^.]+)',
      caseSensitive: false,
    ).firstMatch(p.description);
    return match?.group(1)?.trim();
  }

  List<MapEntry<String, dynamic>> _orderedSpecs(Product p) {
    final attrs = p.attrs;
    final known = _specOrder.where(attrs.containsKey);
    final rest = attrs.keys.where((k) => !_specOrder.contains(k));
    return [...known, ...rest].map((k) => MapEntry(k, attrs[k])).toList();
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
        final chips = ['All', ..._groups.keys.where(stocked.contains)];

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
    final options = widget.shop.upgradesFor(p.id);
    // An upgrade changes the machine itself; an accessory is sold beside
    // it at a with-purchase price. Same tick box, different fact, so
    // they get separate headings rather than one mixed list.
    final upgradeOptions = options.where((u) => !u.isAccessory).toList();
    final accessoryOptions = options.where((u) => u.isAccessory).toList();
    final chosen = _chosenFor(p.id);
    final extra = options
        .where((u) => chosen.contains(u.id))
        .fold<double>(0, (sum, u) => sum + u.priceDelta);
    // Only fall back to the prose when there is nothing better. A machine
    // with real options should not show the sentence they came from.
    final upgrades = options.isEmpty ? _upgradeNote(p) : null;
    final specs = _orderedSpecs(p);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: const Border(top: BorderSide(color: AppTheme.red, width: 3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The picture opens the machine's own screen, and records the
          // view on the way -- the same path a product card takes, so a
          // prebuilt counts for exactly as much as anything else.
          InkWell(
            onTap: () {
              widget.shop.trackView(p.id);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProductDetailScreen(product: p, shop: widget.shop),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFFFAFBFC),
                border: Border.all(color: const Color(0xFFE8EAED)),
                borderRadius: BorderRadius.circular(8),
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
          Text(
            p.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
          if (upgrades != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4DD),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Available upgrades: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: upgrades,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (upgradeOptions.isNotEmpty)
            _optionBlock(
              title: 'Add on at build time',
              hint: 'Ticked here, confirmed in your cart.',
              options: upgradeOptions,
              all: options,
              chosen: chosen,
              enabled: !outOfStock,
            ),
          if (accessoryOptions.isNotEmpty)
            _optionBlock(
              title: 'Buy with this machine',
              hint: 'Shop prices for buying alongside a PC.',
              options: accessoryOptions,
              all: options,
              chosen: chosen,
              enabled: !outOfStock,
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A deal is on the machine, not on the options
                    // bolted to it -- the till works the same way -- so
                    // the ticks are added on top of the deal price.
                    DealPriceText(
                      product: p,
                      shop: widget.shop,
                      size: 19,
                      extra: extra,
                    ),
                    // The base price stays visible next to the new one,
                    // so nobody has to work out what the ticks did.
                    if (extra > 0)
                      Text(
                        '${money(widget.shop.priceOf(p))} + ${money(extra)} upgrades',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: outOfStock ? null : () => _add(p),
                child: Text(outOfStock ? 'Out of Stock' : 'Add to Cart'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// One tickable list. [options] is what this block shows; [all] is
  /// every option on the machine, because the one-swap-per-slot rule has
  /// to see across both blocks -- a cooler upgrade and a cooler
  /// accessory would still be two coolers.
  Widget _optionBlock({
    required String title,
    required String hint,
    required List<PrebuiltUpgrade> options,
    required List<PrebuiltUpgrade> all,
    required Set<int> chosen,
    required bool enabled,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FA),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE8EAED)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            ...options.map((u) {
              return CheckboxListTile(
                value: chosen.contains(u.id),
                onChanged: !enabled
                    ? null
                    : (on) => setState(() {
                        if (on == true) {
                          // One swap per slot: a machine has one graphics
                          // card, so ticking a second graphics upgrade
                          // replaces the first rather than charging for
                          // both. The two peripheral sets are
                          // alternatives for the same reason.
                          chosen.removeWhere((id) =>
                              all.any((o) => o.id == id && o.slot == u.slot));
                          chosen.add(u.id);
                        } else {
                          chosen.remove(u.id);
                        }
                      }),
                title: Text(u.label, style: const TextStyle(fontSize: 12.5)),
                subtitle: Text(
                  '+${money(u.priceDelta)}  ·  '
                  '${ProductDetailScreen.specLabel(u.slot)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                dense: true,
                visualDensity: VisualDensity.compact,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: AppTheme.redDark,
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _add(Product p) async {
    final picked = _chosenFor(p.id).toList();
    final error = await widget.shop.addToCart(p.id, upgradeIds: picked);
    if (!mounted) return;

    final added = picked.isEmpty
        ? '${p.name} added to your cart.'
        : '${p.name} added with ${picked.length} '
              '${picked.length == 1 ? 'upgrade' : 'upgrades'}.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? added)));
  }
}
