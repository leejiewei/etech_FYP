import '../config.dart';

/// Reads a money column.
///
/// Postgres numeric arrives over JSON as a string, because a double
/// cannot represent every value numeric can. Prices in this shop are
/// nowhere near that limit, but the value still has to be parsed rather
/// than cast, and every model here has money columns to read.
double numericOf(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

/// One product.
///
/// Built from a row of the products table plus the three things that live
/// in other tables — the brand name, the category names and the
/// specifications. Shop.loadProducts() fetches those and puts them
/// together; this class is just the result.
class Product {
  final int id;
  final String name;
  final String brand;
  final String category;
  final String? subcategory;
  final double price;
  final String stock; // 'in', 'low' or 'out'
  final String description;
  final String imgSlug; // which drawing to fall back on
  final String? imagePath; // a real photo, if one was uploaded
  final Map<String, dynamic> attrs;
  final bool excludeFromBuilder;

  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    this.subcategory,
    required this.price,
    required this.stock,
    required this.description,
    required this.imgSlug,
    this.imagePath,
    required this.attrs,
    required this.excludeFromBuilder,
  });

  factory Product.fromRow(
    Map<String, dynamic> row, {
    required String brand,
    required String category,
    String? subcategory,
    required Map<String, dynamic> attrs,
  }) {
    return Product(
      id: row['product_id'] as int,
      name: row['name'] ?? '',
      brand: brand,
      category: category,
      subcategory: subcategory,
      price: numericOf(row['price']),
      stock: row['stock_status'] ?? 'in',
      description: row['description'] ?? '',
      imgSlug: row['img_slug'] ?? 'default',
      imagePath: row['image_path'],
      attrs: attrs,
      excludeFromBuilder: (row['exclude_from_builder'] ?? 0) == 1,
    );
  }

  /// A real photo if there is one, otherwise the drawn illustration.
  ///
  /// The photo is a full URL, because uploads go to Supabase Storage now
  /// rather than to a folder on the web server. The illustration is a
  /// path inside the app's own bundle, so it needs no network at all.
  String get imageUrl =>
      imagePath != null ? imagePath! : Config.illustration(imgSlug);

  bool get isSvg => imagePath == null;
  bool get inStock => stock != 'out';

  String get stockLabel {
    switch (stock) {
      case 'in':
        return 'In Stock';
      case 'low':
        return 'Low Stock';
      default:
        return 'Out of Stock';
    }
  }

  /// "Components > CPU", or just the category when there is no sub-type.
  String get categoryPath =>
      subcategory == null ? category : '$category > $subcategory';

  // ---- helpers the PC Builder needs ----
  String? get socket => attrs['socket'] as String?;
  String? get ramGen => attrs['ramGen'] as String?;
  String? get formFactor => attrs['formFactor'] as String?;

  int get tdp => _int('tdp');
  int get coolerRating => _int('coolerRating');
  int get wattage => _int('wattage');
  int get power => _int('power');
  int get length => _int('length');
  int get maxGpuLength => _int('maxGpuLength');

  int _int(String key) {
    final v = attrs[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  List<String> _list(String key) {
    final v = attrs[key];
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String) return [v];
    return [];
  }

  List<String> get sockets => _list('sockets');
  List<String> get supportedFormFactors => _list('supportedFormFactors');
  List<String> get incompatibleSockets => _list('incompatibleSockets');
}
