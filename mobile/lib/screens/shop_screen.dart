import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../widgets/product_card.dart';

/// The catalogue: search, category chips, brand filter and sorting.
class ShopScreen extends StatefulWidget {
  final Shop shop;
  const ShopScreen({super.key, required this.shop});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String _search = '';
  String _category = 'All';
  String _brand = 'All';
  String _sort = 'default';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filtered {
    var list = widget.shop.products.where((p) {
      if (_category != 'All' && p.category != _category) return false;
      if (_brand != 'All' && p.brand != _brand) return false;
      if (_search.trim().isNotEmpty) {
        final term = _search.trim().toLowerCase();
        if (!('${p.name} ${p.brand}').toLowerCase().contains(term)) return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case 'brand':
        list.sort((a, b) => a.brand.compareTo(b.brand));
        break;
      case 'price-low':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price-high':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          IconButton(
            tooltip: 'Filter by brand',
            icon: const Icon(Icons.sell_outlined),
            onPressed: _pickBrand,
          ),
          IconButton(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            onPressed: _pickSort,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: TextField(
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
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: ['All', ...widget.shop.categories].map((c) {
                final selected = c == _category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = c),
                    selectedColor: AppTheme.redDark,
                    labelStyle: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white : AppTheme.ink),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_brand != 'All' || _sort != 'default')
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(children: [
                if (_brand != 'All')
                  _activeChip(_brand, () => setState(() => _brand = 'All')),
                if (_sort != 'default')
                  _activeChip(_sortLabel(_sort), () => setState(() => _sort = 'default')),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${results.length} products',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text('Nothing matches those filters.',
                        style: TextStyle(color: Colors.grey.shade600)))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: results.length,
                    itemBuilder: (_, i) =>
                        ProductCard(product: results[i], shop: widget.shop),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _activeChip(String label, VoidCallback onClear) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Chip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          backgroundColor: const Color(0xFFFDE7E9),
          deleteIcon: const Icon(Icons.close, size: 15),
          onDeleted: onClear,
        ),
      );

  String _sortLabel(String key) => {
        'brand': 'Brand A-Z',
        'price-low': 'Price: low to high',
        'price-high': 'Price: high to low',
      }[key] ??
      key;

  void _pickBrand() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, controller) => ListView(
          controller: controller,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Filter by brand',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...['All', ...widget.shop.brands].map((b) => ListTile(
                  title: Text(b),
                  trailing: b == _brand
                      ? const Icon(Icons.check, color: AppTheme.red)
                      : null,
                  onTap: () {
                    setState(() => _brand = b);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _pickSort() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sort by',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...{
              'default': 'Default',
              'brand': 'Brand (A-Z)',
              'price-low': 'Price: low to high',
              'price-high': 'Price: high to low',
            }.entries.map((e) => ListTile(
                  title: Text(e.value),
                  trailing: e.key == _sort
                      ? const Icon(Icons.check, color: AppTheme.red)
                      : null,
                  onTap: () {
                    setState(() => _sort = e.key);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }
}
