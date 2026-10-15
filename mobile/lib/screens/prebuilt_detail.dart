import 'package:flutter/material.dart';
import '../models/prebuilt.dart';
import '../models/product.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../widgets/deal_price.dart';
import '../widgets/product_image.dart';
import 'prebuilt.dart';
import 'product_detail.dart';

/// One prebuilt machine, on a screen of its own.
///
/// The app's half of web/js/prebuilt-detail.js, in the same look: a red
/// band with the name, stock and price; the picture above a table of the
/// parts; one numbered step per kind of upgrade; and a "Your PC" receipt
/// listing what was chosen. On a phone the receipt comes after the steps
/// and the total rides in a bar pinned to the bottom, so the price and
/// the Add button are always in reach while scrolling the options.
///
/// Nothing here prices anything for real. Only the chosen upgrade ids go
/// to the basket, and place_order reads what each one costs from
/// prebuilt_upgrades on the server.
class PrebuiltDetailScreen extends StatefulWidget {
  final Product product;
  final Shop shop;
  const PrebuiltDetailScreen({
    super.key,
    required this.product,
    required this.shop,
  });

  @override
  State<PrebuiltDetailScreen> createState() => _PrebuiltDetailScreenState();
}

/// What a slot is called on screen, and its icon. Matches UPGRADE_SLOTS
/// in web/js/prebuilt-detail.js; a slot missing from here still shows,
/// under its own name.
class _SlotInfo {
  final String title;
  final IconData icon;
  const _SlotInfo(this.title, this.icon);
}

const Map<String, _SlotInfo> _slots = {
  'cpu': _SlotInfo('Upgrade Processor', Icons.memory),
  'gpu': _SlotInfo('Upgrade Graphics Card', Icons.videogame_asset_outlined),
  'ram': _SlotInfo('Upgrade RAM', Icons.developer_board),
  'ssd': _SlotInfo('Upgrade Storage', Icons.storage),
  'cooler': _SlotInfo('Upgrade CPU Cooler', Icons.ac_unit),
  'extras': _SlotInfo('Add-on Fans', Icons.air),
  'monitor': _SlotInfo('Add-on Monitor', Icons.monitor),
  'peripherals': _SlotInfo('Add-on Keyboard & Mouse', Icons.keyboard),
  'audio': _SlotInfo('Add-on Speakers', Icons.speaker),
};

_SlotInfo _slotInfo(String slot) =>
    _slots[slot] ??
    _SlotInfo(
      slot.isEmpty
          ? 'Upgrade'
          : 'Upgrade ${slot[0].toUpperCase()}${slot.substring(1)}',
      Icons.extension_outlined,
    );

class _PrebuiltDetailScreenState extends State<PrebuiltDetailScreen> {
  /// The ids chosen so far. One per slot: a machine has one graphics
  /// card, so choosing a second replaces the first rather than charging
  /// for both.
  final Set<int> _chosen = {};
  bool _adding = false;

  Product get p => widget.product;

  List<PrebuiltUpgrade> get _options => widget.shop.upgradesFor(p.id);

  double get _extra => _options
      .where((u) => _chosen.contains(u.id))
      .fold<double>(0, (sum, u) => sum + u.priceDelta);

  /// Upgrades to the machine first, then the things sold beside it, each
  /// kept in the order the shop listed them.
  List<MapEntry<String, List<PrebuiltUpgrade>>> _groups() {
    final groups = <String, List<PrebuiltUpgrade>>{};
    for (final accessory in [false, true]) {
      for (final u in _options.where((u) => u.isAccessory == accessory)) {
        groups.putIfAbsent(u.slot, () => []).add(u);
      }
    }
    return groups.entries.toList();
  }

  void _toggle(PrebuiltUpgrade u) {
    setState(() {
      if (_chosen.contains(u.id)) {
        _chosen.remove(u.id);
      } else {
        _chosen.removeWhere(
          (id) => _options.any((o) => o.id == id && o.slot == u.slot),
        );
        _chosen.add(u.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.shop,
      builder: (context, _) {
        final stock = widget.shop.stockOf(p);
        final outOfStock = stock == 'out';
        final waiting = widget.shop.blockedBy(p);
        final options = _options;
        final note = options.isEmpty ? PrebuiltScreen.upgradeNote(p) : null;
        final specs = PrebuiltScreen.orderedSpecs(p);
        final groups = _groups();

        return Scaffold(
          appBar: AppBar(title: Text(PrebuiltScreen.groupOf(p) ?? 'Prebuilt PC')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _hero(stock),
              const SizedBox(height: 14),
              _showcase(specs),
              if (waiting != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Waiting on: $waiting',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              if (options.isNotEmpty) ...[
                const SizedBox(height: 22),
                const Text(
                  'Make it yours',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Everything is optional. Pick one in a step to swap it in; '
                  'pick it again to go back to standard.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
              for (var i = 0; i < groups.length; i++)
                _step(i, groups[i].key, groups[i].value, outOfStock),
              if (note != null) _noteStep(note),
              const SizedBox(height: 20),
              _receipt(),
              if (p.description.trim().isNotEmpty) _about(),
            ],
          ),
          bottomNavigationBar: _bottomBar(outOfStock),
        );
      },
    );
  }

  /// The red band: which range, the name, stock, and the price -- with
  /// the saving spelled out when a deal is on.
  Widget _hero(String stock) {
    final deal = widget.shop.dealFor(p);
    final base = widget.shop.priceOf(p);
    final saving = deal != null ? p.price - base : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        color: AppTheme.ink,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prebuilt PCs / ${PrebuiltScreen.groupOf(p) ?? ''}',
            style: const TextStyle(fontSize: 12, color: Color(0xCCFFFFFF)),
          ),
          const SizedBox(height: 6),
          Text(
            p.name,
            style: const TextStyle(
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          StockPill(stock: stock, label: widget.shop.stockLabelOf(p)),
          const SizedBox(height: 14),
          if (saving > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Save ${money(saving)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.redDark,
                ),
              ),
            ),
          Text(
            money(base),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (saving > 0) ...[
            Text(
              'was ${money(p.price)}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xBFFFFFFF),
                decoration: TextDecoration.lineThrough,
                decorationColor: Color(0xBFFFFFFF),
              ),
            ),
            Text(
              'Deal ends in ${formatCountdown(deal!.timeLeft)}',
              style: const TextStyle(fontSize: 12, color: Color(0xCCFFFFFF)),
            ),
          ],
        ],
      ),
    );
  }

  /// The picture, then "What's inside" as a striped table.
  Widget _showcase(List<MapEntry<String, dynamic>> specs) {
    return _whiteCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F9),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: ProductImage(url: p.imageUrl, isSvg: p.isSvg, height: 176),
          ),
          if (specs.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              "What's inside",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < specs.length; i++)
              Container(
                color: i.isEven ? const Color(0xFFF7F7F9) : null,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        ProductDetailScreen.specLabel(specs[i].key),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF777777),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        specs[i].value is List
                            ? (specs[i].value as List).join(', ')
                            : '${specs[i].value}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// One numbered step per kind of upgrade. Each option is a tile with a
  /// round marker, its icon, its name and what it adds.
  Widget _step(
    int index,
    String slot,
    List<PrebuiltUpgrade> options,
    bool outOfStock,
  ) {
    final info = _slotInfo(slot);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppTheme.redDark,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  (index + 1).toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  info.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final u in options) _tile(u, info.icon, outOfStock),
        ],
      ),
    );
  }

  Widget _tile(PrebuiltUpgrade u, IconData icon, bool outOfStock) {
    final on = _chosen.contains(u.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: outOfStock ? 0.45 : 1,
        child: Material(
          color: on ? const Color(0xFFFDF0F1) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            side: BorderSide(
              color: on ? AppTheme.red : const Color(0xFFE2E2E2),
              width: on ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            onTap: outOfStock ? null : () => _toggle(u),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    on ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 20,
                    color: on ? AppTheme.red : const Color(0xFFBBBBBB),
                  ),
                  const SizedBox(width: 10),
                  Icon(icon, size: 26, color: AppTheme.redDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      u.label,
                      style: const TextStyle(fontSize: 13.5, height: 1.35),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+${money(u.priceDelta)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.redDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A machine with no priced options, only the record's prose.
  Widget _noteStep(String note) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4DD),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available upgrades',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(note, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              'Ask us in store or on WhatsApp to add one.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  /// The receipt: the machine, then each upgrade chosen on its own line.
  Widget _receipt() {
    final base = widget.shop.priceOf(p);
    final chosen = _options.where((u) => _chosen.contains(u.id)).toList();

    Widget line(String left, String right, {Color? colour}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(left, style: TextStyle(fontSize: 13.5, color: colour)),
          ),
          const SizedBox(width: 12),
          Text(right, style: TextStyle(fontSize: 13.5, color: colour)),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
        
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your PC',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          line(p.name, money(base)),
          if (chosen.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Standard build, no upgrades',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
              ),
            )
          else
            for (final u in chosen)
              line('+ ${u.label}', money(u.priceDelta),
                  colour: const Color(0xFF555555)),
          const SizedBox(height: 6),
          const _DashedLine(),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.redDark,
                  ),
                ),
              ),
              Text(
                money(base + _extra),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.redDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _about() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _whiteCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About this PC',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              p.description,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: Color(0xFF555555),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The total and the Add button, always on screen.
  Widget _bottomBar(bool outOfStock) {
    final count = _chosen.length;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.line)),
          boxShadow: [
            BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DealPriceText(
                    product: p,
                    shop: widget.shop,
                    size: 19,
                    extra: _extra,
                  ),
                  Text(
                    count == 0
                        ? 'Standard build'
                        : '$count ${count == 1 ? 'upgrade' : 'upgrades'} chosen',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: outOfStock || _adding ? null : _add,
              child: Text(outOfStock ? 'Out of Stock' : 'Add to Cart'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _whiteCard({required Widget child, required EdgeInsets padding}) =>
      Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.line),
        ),
        child: child,
      );

  Future<void> _add() async {
    setState(() => _adding = true);
    final picked = _chosen.toList();
    final error = await widget.shop.addToCart(p.id, upgradeIds: picked);
    if (!mounted) return;
    setState(() => _adding = false);

    final added = picked.isEmpty
        ? '${p.name} added to your cart.'
        : '${p.name} added with ${picked.length} '
              '${picked.length == 1 ? 'upgrade' : 'upgrades'}.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? added)));
  }
}

/// The dashed rule above the receipt's total.
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final dashes = (box.maxWidth / 7).floor();
        return Row(
          children: List.generate(
            dashes,
            (_) => Container(
              width: 4,
              height: 1,
              margin: const EdgeInsets.only(right: 3),
              color: const Color(0xFFCCCCCC),
            ),
          ),
        );
      },
    );
  }
}
