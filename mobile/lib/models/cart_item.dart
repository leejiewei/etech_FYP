import '../config.dart';
import 'product.dart' show numericOf;
import 'prebuilt.dart';

/// A line in the basket: a row of cart_items with its product joined on.
///
/// A line for one of the shop's own builds can also carry the upgrades
/// the customer ticked on the prebuilt card. They are part of the line
/// rather than lines of their own, because they are not separately
/// deliverable — nobody is buying a "+RM499 to RTX 5050" on its own.
class CartItem {
  final int id;
  final String name;
  final double price;

  /// What the product costs when nothing is on offer. Equal to [price]
  /// unless a deal is running, and kept so the basket can strike it
  /// through rather than quietly showing a smaller number.
  final double listPrice;
  final int qty;
  final String imgSlug;
  final String? imagePath;
  final String stock;
  final List<PrebuiltUpgrade> upgrades;
  final double lineTotal;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.listPrice,
    required this.qty,
    required this.imgSlug,
    this.imagePath,
    required this.stock,
    this.upgrades = const [],
    required this.lineTotal,
  });

  bool get onDeal => price < listPrice;

  /// [dealPrice] is passed in by Shop.loadCart from the catalogue, which
  /// is reading the same window place_order reads out of the deals
  /// table. Null for a line with no deal on it, and then the product's
  /// own price stands -- which is what the till would charge for it too.
  factory CartItem.fromRow(
    Map<String, dynamic> row, {
    List<PrebuiltUpgrade> upgrades = const [],
    double? dealPrice,
  }) {
    final product = Map<String, dynamic>.from(row['products'] as Map);
    final listPrice = numericOf(product['price']);
    final price = dealPrice ?? listPrice;
    final qty = row['quantity'] as int;
    // Each machine carries its own upgrades, so two of them cost two
    // upgrade fees -- the same way two of anything costs twice.
    final perUnit =
        price + upgrades.fold<double>(0, (sum, u) => sum + u.priceDelta);

    return CartItem(
      id: row['product_id'] as int,
      name: product['name'] ?? '',
      price: price,
      listPrice: listPrice,
      qty: qty,
      imgSlug: product['img_slug'] ?? 'default',
      imagePath: product['image_path'],
      stock: product['stock_status'] ?? 'in',
      upgrades: upgrades,
      // Worked out here rather than read back, because it is the same
      // arithmetic either way and one less thing to keep in step.
      lineTotal: perUnit * qty,
    );
  }

  /// What the upgrades add to this line, for showing the base price and
  /// the extras apart from one another.
  double get upgradeTotal =>
      upgrades.fold<double>(0, (sum, u) => sum + u.priceDelta) * qty;

  String get imageUrl =>
      imagePath != null ? imagePath! : Config.illustration(imgSlug);

  bool get isSvg => imagePath == null;
}

/// One of the customer's past orders.
class Order {
  final int id;
  final DateTime date;
  final String status;
  final double subtotal;
  final double discount;
  final double total;
  final String? couponCode;
  final List<OrderLine> items;

  /// Where the money stands, as distinct from where the goods stand.
  ///
  /// An order can be Pending with the payment approved (paid, not yet
  /// put together) or Processing with the payment rejected (a blurred
  /// receipt on an order somebody has already started), so these are
  /// separate fields and are shown separately.
  ///
  /// [status] runs Pending -> Processing -> Ready -> Collected. Ready
  /// means it is on the counter waiting; nothing is ever posted, because
  /// the shop does not deliver. The order's shipping_address column is
  /// not read here at all — it holds what older orders were placed
  /// against and is kept for that history alone.
  ///
  /// [paymentMethod] is null on the orders placed before the shop could
  /// take a payment at all, through the old card sandbox. That null means
  /// something and is not filled in with a guess.
  final String? paymentMethod;
  final String paymentStatus;
  final String? receiptPath;

  Order({
    required this.id,
    required this.date,
    required this.status,
    required this.subtotal,
    required this.discount,
    required this.total,
    this.couponCode,
    required this.items,
    this.paymentMethod,
    this.paymentStatus = 'PENDING',
    this.receiptPath,
  });

  bool get paymentSettled => paymentStatus == 'APPROVED';
  bool get needsReceipt => paymentMethod != null && !paymentSettled;

  factory Order.fromRow(Map<String, dynamic> row) => Order(
        id: row['order_id'] as int,
        // The date arrives as a proper UTC timestamp now rather than a
        // string with the zone trimmed off, so .toLocal() shows it in
        // whatever zone the phone is in.
        date: DateTime.tryParse('${row['order_date']}')?.toLocal() ??
            DateTime.now(),
        status: row['status'] ?? 'Pending',
        subtotal: numericOf(row['subtotal']),
        discount: numericOf(row['discount']),
        total: numericOf(row['total']),
        couponCode: row['coupon_code'],
        items: ((row['order_items'] ?? []) as List)
            .map((e) => OrderLine.fromRow(Map<String, dynamic>.from(e)))
            .toList(),
        paymentMethod: row['payment_method'],
        paymentStatus: row['payment_status'] ?? 'PENDING',
        receiptPath: row['receipt_image_path'],
      );
}

class OrderLine {
  final String name;
  final int quantity;
  final double lineTotal;

  OrderLine({required this.name, required this.quantity, required this.lineTotal});

  factory OrderLine.fromRow(Map<String, dynamic> row) => OrderLine(
        name: row['product_name'] ?? '',
        quantity: row['quantity'] as int,
        lineTotal: numericOf(row['line_total']),
      );
}

/// A promotion currently running.
class Deal {
  final String code;
  final String description;
  final double discountPercent;
  final String? category;

  Deal({
    required this.code,
    required this.description,
    required this.discountPercent,
    this.category,
  });

  factory Deal.fromRow(Map<String, dynamic> row) => Deal(
        code: row['code'] ?? '',
        description: row['description'] ?? '',
        discountPercent: numericOf(row['discount_percent']),
        // null means the promotion applies to everything
        category: row['categories'] == null
            ? null
            : (row['categories'] as Map)['name'] as String?,
      );
}
