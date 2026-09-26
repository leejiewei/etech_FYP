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
  final String? officialUrl; // the maker's own page, for the full specs
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
    this.officialUrl,
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
      officialUrl: row['official_url'],
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

  /// The colours the shop stocks this in side by side. Empty for almost
  /// everything, which is what keeps the picker off other products.
  List<String> get colourOptions => _list('colourOption');
}

/// A price on one product until a stated moment.
///
/// Not the same thing as a [Deal], which despite the name is a coupon
/// code for a whole category that the customer has to type at the
/// checkout. This is a price on the shelf: nothing is typed, the old
/// price is shown struck through, and place_order charges this one until
/// the window closes.
///
/// The end time is checked twice. The database only ever hands over a
/// deal that is running, and [isRunning] checks it again on every call,
/// because a phone can sit in a pocket with the app open. Somebody
/// looking at the Shop tab at 23:59 should watch the sale end rather
/// than find out at the checkout.
class TimedDeal {
  final int id;
  final int productId;
  final double price;
  final DateTime startsAt;
  final DateTime endsAt;

  TimedDeal({
    required this.id,
    required this.productId,
    required this.price,
    required this.startsAt,
    required this.endsAt,
  });

  factory TimedDeal.fromRow(Map<String, dynamic> row) => TimedDeal(
        id: row['deal_id'] as int,
        productId: row['product_id'] as int,
        price: numericOf(row['discount_price']),
        startsAt: DateTime.parse(row['start_time'] as String).toLocal(),
        endsAt: DateTime.parse(row['end_time'] as String).toLocal(),
      );

  bool get isRunning => DateTime.now().isBefore(endsAt);

  Duration get timeLeft {
    final left = endsAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }
}

/// HH:MM:SS, with the days broken out in front once there is more than
/// one. A three-week deal reading "504:00:00" is arithmetic, not an
/// answer to "how long have I got".
String formatCountdown(Duration left) {
  if (left <= Duration.zero) return 'Ended';

  String two(int n) => n.toString().padLeft(2, '0');
  final clock = '${two(left.inHours % 24)}:${two(left.inMinutes % 60)}:'
      '${two(left.inSeconds % 60)}';
  return left.inDays > 0 ? '${left.inDays}d $clock' : clock;
}

/// A machine somebody built, photographed, with the parts they used.
///
/// The ASUS badge is not a field anybody sets. It is worked out in the
/// database from the tagged parts by a trigger, every time the tags
/// change, so it is a fact about the build rather than an opinion about
/// it. This class only carries the answer.
class RigShowcase {
  final int id;
  final String title;
  final String? description;
  final List<String> imageUrls;
  final bool asusVerified;
  final String builder;
  final DateTime createdAt;

  /// Filled in from rig_gallery_parts, which only ever returns the parts
  /// of a published build.
  final List<RigPart> parts;

  RigShowcase({
    required this.id,
    required this.title,
    this.description,
    required this.imageUrls,
    required this.asusVerified,
    required this.builder,
    required this.createdAt,
    this.parts = const [],
  });

  factory RigShowcase.fromRow(Map<String, dynamic> row,
          {List<RigPart> parts = const []}) =>
      RigShowcase(
        id: row['rig_id'] as int,
        title: row['title'] ?? '',
        description: row['description'],
        imageUrls:
            ((row['image_urls'] ?? []) as List).map((e) => '$e').toList(),
        asusVerified: (row['is_asus_verified'] ?? 0) == 1,
        builder: row['builder'] ?? 'a customer',
        createdAt:
            DateTime.tryParse('${row['created_at']}')?.toLocal() ?? DateTime.now(),
        parts: parts,
      );
}

/// One part tagged in a build. A real product id rather than a line of
/// text, so tapping it can go to the thing itself.
class RigPart {
  final int rigId;
  final int productId;
  final String name;
  final String brand;
  final double price;

  RigPart({
    required this.rigId,
    required this.productId,
    required this.name,
    required this.brand,
    required this.price,
  });

  factory RigPart.fromRow(Map<String, dynamic> row) => RigPart(
        rigId: row['rig_id'] as int,
        productId: row['product_id'] as int,
        name: row['product_name'] ?? '',
        brand: row['brand'] ?? '',
        price: numericOf(row['price']),
      );
}
