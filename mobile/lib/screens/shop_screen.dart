import 'dart:async';

import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../widgets/product_card.dart';
import 'product_detail.dart';

/// The catalogue: search, sorting, and tick-box filters with counts.
///
/// The app's half of web/js/shop.js, in the same look: a red band naming
/// what is on show, and a Refine panel that slides in from the right
/// with Availability, Categories, Type, Brands and -- once one category
/// (and, where it has types, one type) is ticked -- its technical
/// details. There is no Apply button: a tick redraws the grid straight
/// away, and every tick is also a chip above the grid, so it is always
/// plain why only some products are showing.
class ShopScreen extends StatefulWidget {
  final Shop shop;
  const ShopScreen({super.key, required this.shop});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

/// Brand lists run long; this many show before "Show all".
const int _brandsShown = 8;

class _ShopScreenState extends State<ShopScreen> {
  String _search = '';
  String _sort = 'default';
  final _searchController = TextEditingController();

  /// What is ticked, one set per group. An empty set means "any". Ticking
  /// two brands shows either brand; ticking a brand and a category shows
  /// products that are both.
  final Map<String, Set<String>> _selected = {
    'stock': {}, // 'in', 'out'
    'category': {},
    'subcategory': {},
    'brand': {},
  };
  Map<String, Set<String>> _attrs = {}; // e.g. {socket: {AM5}}

  // Recording a search waits until the typing stops. Without this, "rtx"
  // would be written down as three searches, two of which found nothing.
  Timer? _searchDebounce;

  Shop get shop => widget.shop;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Called on every keystroke; writes at most one row per typed phrase.
  ///
  /// The count comes from the filtered list rather than from a guess, so
  /// it is the number of products the shopper was actually shown --
  /// including zero, which is the case worth knowing about.
  void _onSearchChanged(String value) {
    setState(() => _search = value);

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      shop.trackSearch(value, _filtered().length);
    });
  }

  /// What a product is, for each tick-box group.
  ///
  /// shop.inStock, not product.inStock: a prebuilt has no stock of its
  /// own, only whatever its scarcest part allows, and the filter has to
  /// agree with the badge the card is about to draw. "In stock" keeps the
  /// low ones -- somebody filtering for what they can buy today wants the
  /// last two in the box.
  String? _valueOf(String group, Product p) => switch (group) {
    'stock' => shop.inStock(p) ? 'in' : 'out',
    'category' => p.category,
    'subcategory' => p.subcategory,
    'brand' => p.brand,
    _ => null,
  };

  /// [skip] names a group to leave out, so each group's counts say how
  /// many products ticking that box would show, given everything else.
  bool _matches(Product p, [String? skip]) {
    for (final e in _selected.entries) {
      if (e.key == skip || e.value.isEmpty) continue;
      if (!e.value.contains(_valueOf(e.key, p))) return false;
    }
    for (final e in _attrs.entries) {
      if ('attr:${e.key}' == skip || e.value.isEmpty) continue;
      if (!e.value.contains(p.attrs[e.key])) return false;
    }
    final term = _search.trim().toLowerCase();
    if (term.isNotEmpty &&
        !'${p.name} ${p.brand}'.toLowerCase().contains(term)) {
      return false;
    }
    return true;
  }

  List<Product> _filtered() {
    final list = shop.products.where((p) => _matches(p)).toList();
    switch (_sort) {
      case 'brand':
        list.sort((a, b) => a.brand.compareTo(b.brand));
      case 'price-low':
        list.sort((a, b) => shop.priceOf(a).compareTo(shop.priceOf(b)));
      case 'price-high':
        list.sort((a, b) => shop.priceOf(b).compareTo(shop.priceOf(a)));
    }
    return list;
  }

  /// {value: count} for one group, over the products the others allow.
  Map<String, int> _counts(String skip, String? Function(Product) valueOf) {
    final counts = <String, int>{};
    for (final p in shop.products) {
      final v = valueOf(p);
      if (v == null || v.isEmpty || !_matches(p, skip)) continue;
      counts[v] = (counts[v] ?? 0) + 1;
    }
    return counts;
  }

  /// The technical filters only make sense inside one category -- with
  /// every category at once they would list socket, paper size and VESA
  /// mount side by side.
  String? get _attrCategory =>
      _selected['category']!.length == 1 ? _selected['category']!.first : null;

  bool _inView(Product p) =>
      p.category == _attrCategory &&
      (_selected['subcategory']!.isEmpty ||
          _selected['subcategory']!.contains(p.subcategory));

  void _toggle(String group, String value, bool on) {
    setState(() {
      final Set<String> set;
      if (group.startsWith('attr:')) {
        set = _attrs.putIfAbsent(group.substring(5), () => {});
      } else {
        set = _selected[group]!;
      }
      on ? set.add(value) : set.remove(value);

      // A category change leaves the old category's technical filters
      // meaning nothing, and its types too.
      if (group == 'category') {
        _attrs = {};
        _pruneSubcategories();
      }
      if (group == 'subcategory') _pruneAttrs();
    });
  }

  /// Drops ticked types that no longer belong to any ticked category.
  void _pruneSubcategories() {
    final cats = _selected['category']!;
    if (cats.isEmpty) return;
    _selected['subcategory']!.removeWhere(
      (sub) => !shop.products.any(
        (p) => p.subcategory == sub && cats.contains(p.category),
      ),
    );
  }

  /// Drops ticked technical values that no product in view has any more,
  /// e.g. a CPU socket left ticked after switching the type to GPU.
  void _pruneAttrs() {
    for (final e in _attrs.entries) {
      e.value.removeWhere(
        (v) => !shop.products.any((p) => _inView(p) && p.attrs[e.key] == v),
      );
    }
  }

  void _clearAll() {
    setState(() {
      for (final s in _selected.values) {
        s.clear();
      }
      _attrs = {};
    });
  }

  int get _tickedCount =>
      _selected.values.fold(0, (n, s) => n + s.length) +
      _attrs.values.fold(0, (n, s) => n + s.length);

  String get _title {
    String? one(Set<String> s) => s.length == 1 ? s.first : null;
    return one(_selected['subcategory']!) ??
        one(_selected['category']!) ??
        one(_selected['brand']!) ??
        'All Products';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shop,
      builder: (context, _) {
        final results = _filtered();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Shop'),
            actions: [
              // The Scaffold's own endDrawer button is replaced by this
              // one, which carries the count of ticked filters.
              Builder(
                builder: (ctx) => IconButton(
                  tooltip: 'Refine',
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                  icon: Badge(
                    isLabelVisible: _tickedCount > 0,
                    label: Text('$_tickedCount'),
                    child: const Icon(Icons.tune),
                  ),
                ),
              ),
            ],
          ),
          endDrawer: _refinePanel(),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _head(results.length)),
              if (results.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nothing matches those filters.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.62,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: results.length,
                    itemBuilder: (_, i) =>
                        ProductCard(product: results[i], shop: shop),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// The red band with the title and count, then the search box, the
  /// Refine and Sort buttons, and a chip for each thing ticked.
  Widget _head(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.redDarker, AppTheme.redDark, AppTheme.red],
                stops: [0, 0.6, 1],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shop',
                  style: TextStyle(fontSize: 12, color: Color(0xCCFFFFFF)),
                ),
                const SizedBox(height: 6),
                Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 1 ? '1 product' : '$count products',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xE6FFFFFF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products or brands...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                    ),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (ctx) => OutlinedButton.icon(
                    onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                    icon: const Icon(Icons.tune, size: 18),
                    label: Text(
                      _tickedCount == 0 ? 'Refine' : 'Refine ($_tickedCount)',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickSort,
                  icon: const Icon(Icons.sort, size: 18),
                  label: Text(
                    _sortLabel(_sort),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          if (_tickedCount > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final v in _selected['stock']!)
                  _chip(_stockLabel(v), () => _toggle('stock', v, false)),
                for (final v in _selected['category']!)
                  _chip(v, () => _toggle('category', v, false)),
                for (final v in _selected['subcategory']!)
                  _chip('Type: $v', () => _toggle('subcategory', v, false)),
                for (final v in _selected['brand']!)
                  _chip('Brand: $v', () => _toggle('brand', v, false)),
                for (final e in _attrs.entries)
                  for (final v in e.value)
                    _chip(
                      '${ProductDetailScreen.specLabel(e.key)}: $v',
                      () => _toggle('attr:${e.key}', v, false),
                    ),
                TextButton(
                  onPressed: _clearAll,
                  child: const Text('Clear all'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onClear) => Chip(
    label: Text(label, style: const TextStyle(fontSize: 12)),
    backgroundColor: const Color(0xFFFDE7E9),
    side: BorderSide.none,
    visualDensity: VisualDensity.compact,
    deleteIcon: const Icon(Icons.close, size: 15),
    onDeleted: onClear,
  );

  // ------------------------------------------------------------
  // The Refine panel
  // ------------------------------------------------------------

  Widget _refinePanel() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.86,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 6, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Refine',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_tickedCount > 0)
                    TextButton(
                      onPressed: _clearAll,
                      child: const Text('Clear all'),
                    ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: _facets(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Show ${_filtered().length} products'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _showAllBrands = false;

  List<Widget> _facets() {
    final tick = _toggle;
    final out = <Widget>[];

    out.add(
      _facetGroup(
        'Availability',
        'stock',
        _counts('stock', (p) => _valueOf('stock', p)),
        _selected['stock']!,
        tick,
        order: const ['in', 'out'],
        label: _stockLabel,
      ),
    );

    out.add(
      _facetGroup(
        'Categories',
        'category',
        _counts('category', (p) => p.category),
        _selected['category']!,
        tick,
      ),
    );

    // Types appear once there is something to narrow.
    if (_selected['category']!.isNotEmpty ||
        _selected['subcategory']!.isNotEmpty) {
      out.add(
        _facetGroup(
          'Type',
          'subcategory',
          _counts('subcategory', (p) => p.subcategory),
          _selected['subcategory']!,
          tick,
        ),
      );
    }

    out.add(
      _facetGroup(
        'Brands',
        'brand',
        _counts('brand', (p) => p.brand),
        _selected['brand']!,
        tick,
        limit: _showAllBrands ? null : _brandsShown,
        onMore: () => setState(() => _showAllBrands = true),
      ),
    );

    // Technical details for the products in view: one category, and
    // inside a category split into types, only once a type is ticked --
    // otherwise the CPU's socket, the case's board size and the PSU's
    // 80+ rating would all be listed at once.
    final category = _attrCategory;
    if (category != null) {
      final hasTypes = shop.products.any(
        (p) => p.category == category && p.subcategory != null,
      );
      if (hasTypes && _selected['subcategory']!.isEmpty) {
        out.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Text(
              'Tick a type above to filter by technical details.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ),
        );
      } else {
        final keys =
            <String>{
              for (final p in shop.products.where(_inView))
                for (final e in p.attrs.entries)
                  if (e.value is String) e.key, // skip numbers like wattage
            }.toList()..sort(
              (a, b) => ProductDetailScreen.specLabel(
                a,
              ).compareTo(ProductDetailScreen.specLabel(b)),
            );
        for (final key in keys) {
          final ticked = _attrs[key] ?? <String>{};
          out.add(
            _facetGroup(
              ProductDetailScreen.specLabel(key),
              'attr:$key',
              _counts('attr:$key', (p) {
                final v = p.attrs[key];
                return _inView(p) && v is String ? v : null;
              }),
              ticked,
              tick,
              startOpen: ticked.isNotEmpty,
            ),
          );
        }
      }
    }
    return out;
  }

  /// One group of tick boxes. A ticked value stays listed even when its
  /// count drops to nothing, so it can always be unticked.
  Widget _facetGroup(
    String title,
    String group,
    Map<String, int> counts,
    Set<String> ticked,
    void Function(String, String, bool) tick, {
    List<String>? order,
    String Function(String)? label,
    int? limit,
    VoidCallback? onMore,
    bool startOpen = true,
  }) {
    for (final v in ticked) {
      counts.putIfAbsent(v, () => 0);
    }
    var values = order != null
        ? order.where(counts.containsKey).toList()
        : (counts.keys.toList()..sort());
    if (values.isEmpty) return const SizedBox.shrink();

    var hidden = 0;
    if (limit != null && values.length > limit) {
      final shown = [
        for (var i = 0; i < values.length; i++)
          if (i < limit || ticked.contains(values[i])) values[i],
      ];
      hidden = values.length - shown.length;
      values = shown;
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('facet-$group'),
        initiallyExpanded: startOpen,
        tilePadding: const EdgeInsets.symmetric(horizontal: 18),
        childrenPadding: const EdgeInsets.only(bottom: 6),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
        ),
        children: [
          for (final v in values)
            CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              activeColor: AppTheme.red,
              value: ticked.contains(v),
              onChanged: (on) => tick(group, v, on ?? false),
              title: Text(
                label?.call(v) ?? v,
                style: TextStyle(
                  fontSize: 13.5,
                  color: counts[v] == 0 ? Colors.grey.shade500 : AppTheme.ink,
                ),
              ),
              secondary: Text(
                '${counts[v]}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          if (hidden > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: TextButton(
                  onPressed: onMore,
                  child: Text('Show all ${values.length + hidden}'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Sorting
  // ------------------------------------------------------------

  static const Map<String, String> _sorts = {
    'default': 'Default',
    'brand': 'Brand (A-Z)',
    'price-low': 'Price: low to high',
    'price-high': 'Price: high to low',
  };

  String _sortLabel(String key) =>
      key == 'default' ? 'Sort' : _sorts[key] ?? key;

  String _stockLabel(String key) => key == 'in' ? 'In stock' : 'Out of stock';

  void _pickSort() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sort by',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ..._sorts.entries.map(
              (e) => ListTile(
                title: Text(e.value),
                trailing: e.key == _sort
                    ? const Icon(Icons.check, color: AppTheme.red)
                    : null,
                onTap: () {
                  setState(() => _sort = e.key);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
