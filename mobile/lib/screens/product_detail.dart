import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../widgets/deal_price.dart';
import '../widgets/product_image.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  final Shop shop;
  const ProductDetailScreen({super.key, required this.product, required this.shop});

  /// Turns a spec key into something readable, matching the website.
  static const Map<String, String> _labels = {
    'socket': 'Socket', 'sockets': 'Socket Support', 'ramGen': 'RAM Type',
    'screenSize': 'Screen Size', 'storageSize': 'Storage', 'ram': 'Memory',
    'wattage': 'Wattage', 'power': 'Power Draw (W)', 'length': 'Card Length (mm)',
    'tdp': 'Cooling Needed (W)', 'coolerRating': 'Cooler Capacity (W)',
    'formFactor': 'Board Size', 'supportedFormFactors': 'Fits Board Sizes',
    'maxGpuLength': 'Max Card Length (mm)', 'printerType': 'Printer Type',
    'wifi': 'WiFi', 'resolution': 'Resolution', 'refreshRate': 'Refresh Rate',
    'panel': 'Panel Type', 'colour': 'Colour', 'fansIncluded': 'Fans Included',
    'acceptsAtxPsu': 'Takes ATX Power Supply', 'chipset': 'Chipset', 'chip': 'Chip',
    'vram': 'Video Memory', 'cores': 'Cores', 'threads': 'Threads',
    'igpu': 'Built-in Graphics', 'coolerIncluded': 'Cooler Included',
    'incompatibleSockets': 'Known Not To Fit', 'capacity': 'Capacity',
    'speed': 'Speed', 'cl': 'CAS Latency', 'kit': 'Kit', 'driveType': 'Drive Type',
    'connection': 'Interface', 'driveFormFactor': 'Form Factor',
    'pcieGen': 'PCIe Generation', 'heatsink': 'Heatsink', 'driveClass': 'Drive Class',
    'rpm': 'Spin Speed', 'cache': 'Cache', 'rating': '80+ Rating',
    'modularity': 'Cabling', 'connector12VHPWR': '12VHPWR Connector',
    'coolerType': 'Cooling Type', 'radiator': 'Radiator Size', 'lcd': 'LCD Screen',
    'lighting': 'Lighting', 'wifiStd': 'WiFi Standard', 'speedRating': 'Speed Rating',
    'bands': 'Bands', 'fanSize': 'Fan Size', 'pack': 'Pack Size',
    'bladeDirection': 'Blade Direction', 'connector': 'Connector',
    'productType': 'Type', 'armType': 'Arm Type', 'vesa': 'VESA Mount',
    'paperSize': 'Paper Size', 'weight': 'Paper Weight', 'backConnector': 'Back-connector Board',
    'supportsBackConnector': 'Back-connector Ready',
    // Keyboards, mice and mouse pads. Kept in step with attrLabel() in
    // web/js/products.js.
    'switch': 'Switch', 'battery': 'Power', 'size': 'Size',
    'colourOption': 'Available In',
    // Complete systems: laptops, towers, all-in-ones and prebuilts. These
    // arrived with the RigWorks record of 12 August 2026 and must stay in
    // step with attrLabel() in web/js/products.js -- the two maps describe
    // the same database, and a key missing here shows the customer the raw
    // column name where the website shows a proper label.
    'sku': 'SKU', 'cpu': 'Processor', 'gpu': 'Graphics',
    'motherboard': 'Motherboard', 'ssd': 'SSD', 'psu': 'Power Supply',
    'cooler': 'Cooler', 'chassis': 'Chassis', 'touch': 'Touchscreen',
    // Not specs any product carries -- the slots a prebuilt upgrade or
    // accessory sits in when it adds something rather than replacing a
    // part. Kept in step with attrLabel() in web/js/products.js.
    'extras': 'Extras', 'monitor': 'Monitor',
    'peripherals': 'Keyboard & Mouse', 'audio': 'Audio',
  };

  /// The readable name for a spec key, for any screen that shows specs.
  ///
  /// Public so the prebuilt screen can use this map rather than carry a
  /// second copy. There are already two -- this one and attrLabel() in
  /// web/js/products.js -- and they must be kept in step by hand; a third
  /// would be one more place for a label to drift.
  static String specLabel(String key) => _labels[key] ?? key;

  /// Opens the maker's page in the phone's browser. The database only
  /// accepts https links, and this checks again before handing one over.
  /// Public so a grid card can offer the same link beside its price.
  static Future<void> openOfficial(BuildContext context, Product product) async {
    final uri = Uri.tryParse(product.officialUrl ?? '');
    final ok = uri != null &&
        uri.scheme == 'https' &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the official site.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shop,
      builder: (context, _) {
        final saved = shop.inWishlist(product.id);
        return Scaffold(
          appBar: AppBar(
            title: Text(product.brand),
            actions: [
              IconButton(
                icon: Icon(saved ? Icons.favorite : Icons.favorite_border),
                onPressed: () async {
                  final error = await shop.toggleWishlist(product.id);
                  if (error != null && context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(error)));
                  }
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: ProductImage(
                      url: product.imageUrl, isSvg: product.isSvg, height: 180),
                ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.bold, height: 1.3)),
                    const SizedBox(height: 6),
                    Text(product.categoryPath,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 12),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // The countdown belongs here rather than on the
                      // grid card: this is the screen somebody reads
                      // before deciding, and the time left is part of
                      // the decision.
                      DealPriceText(
                        product: product,
                        shop: shop,
                        size: 26,
                        showCountdown: true,
                      ),
                      const SizedBox(width: 12),
                      StockPill(
                        stock: shop.stockOf(product),
                        label: shop.stockLabelOf(product),
                      ),
                    ]),
                    if (product.officialUrl != null) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => openOfficial(context, product),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('Full specs on the official site',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.red)),
                            SizedBox(width: 4),
                            Icon(Icons.open_in_new, size: 15, color: AppTheme.red),
                          ]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (product.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                _panel('About this product',
                    Text(product.description,
                        style: const TextStyle(fontSize: 14, height: 1.5))),
              ],
              if (product.attrs.isNotEmpty) ...[
                const SizedBox(height: 10),
                _panel('Specifications', _specTable()),
              ],
              const SizedBox(height: 20),
            ],
          ),
          bottomSheet: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.line)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(
                      shop.inStock(product) ? 'Add to Cart' : 'Out of Stock'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                          shop.inStock(product) ? AppTheme.red : Colors.grey.shade400),
                  onPressed: shop.inStock(product)
                      ? () async {
                          // A product stocked in several colours asks
                          // which one first; backing out adds nothing.
                          String? colour;
                          if (product.colourOptions.isNotEmpty) {
                            colour = await _pickColour(context);
                            if (colour == null) return;
                          }
                          final error = await shop.addToCart(product.id,
                              colour: colour);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(error ??
                                '${product.name}${colour == null ? '' : ' ($colour)'} added to cart'),
                            duration: const Duration(seconds: 2),
                          ));
                        }
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _pickColour(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Text('Choose a colour',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            for (final c in product.colourOptions)
              ListTile(
                title: Text(c),
                trailing: const Icon(Icons.add_shopping_cart, size: 20),
                onTap: () => Navigator.pop(sheet, c),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _panel(String title, Widget child) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  Widget _specTable() {
    final rows = product.attrs.entries.toList();
    return Column(
      children: rows.map((entry) {
        final label = _labels[entry.key] ?? entry.key;
        final value = entry.value is List
            ? (entry.value as List).join(', ')
            : '${entry.value}';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 145,
                child: Text(label,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ),
              Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
