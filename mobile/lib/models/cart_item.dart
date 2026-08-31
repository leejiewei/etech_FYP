import '../config.dart';
import 'product.dart' show numericOf;

/// A line in the basket: a row of cart_items with its product joined on.
class CartItem {
  final int id;
  final String name;
  final double price;
  final int qty;
  final String imgSlug;
  final String? imagePath;
  final String stock;
  final double lineTotal;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.qty,
    required this.imgSlug,
    this.imagePath,
    required this.stock,
    required this.lineTotal,
  });

  factory CartItem.fromRow(Map<String, dynamic> row) {
    final product = Map<String, dynamic>.from(row['products'] as Map);
    final price = numericOf(product['price']);
    final qty = row['quantity'] as int;

    return CartItem(
      id: row['product_id'] as int,
      name: product['name'] ?? '',
      price: price,
      qty: qty,
      imgSlug: product['img_slug'] ?? 'default',
      imagePath: product['image_path'],
      stock: product['stock_status'] ?? 'in',
      // Worked out here rather than read back, because it is the same
      // arithmetic either way and one less thing to keep in step.
      lineTotal: price * qty,
    );
  }

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
  final String shippingAddress;
  final List<OrderLine> items;

  Order({
    required this.id,
    required this.date,
    required this.status,
    required this.subtotal,
    required this.discount,
    required this.total,
    this.couponCode,
    required this.shippingAddress,
    required this.items,
  });

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
        shippingAddress: row['shipping_address'] ?? '',
        items: ((row['order_items'] ?? []) as List)
            .map((e) => OrderLine.fromRow(Map<String, dynamic>.from(e)))
            .toList(),
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
