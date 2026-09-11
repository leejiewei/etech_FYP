/// A message from the shop about one of the customer's orders.
///
/// Written by the database at the moment staff approve a payment, reject
/// a receipt or mark an order Shipped — see
/// supabase/migrations/20260911090000_order_notifications.sql. The app
/// only ever reads these and marks them read.
class ShopNotification {
  final int id;
  final int? orderId;

  /// 'payment_approved', 'payment_rejected' or 'order_shipped'.
  final String kind;
  final String title;
  final String body;
  final DateTime createdAt;
  DateTime? readAt;

  ShopNotification({
    required this.id,
    required this.orderId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  bool get unread => readAt == null;

  /// The one kind where the customer has to do something.
  bool get needsAction => kind == 'payment_rejected';

  /// Takes both a row from a select and the `newRecord` Realtime hands
  /// over, which carry the same columns under the same names.
  factory ShopNotification.fromRow(Map<String, dynamic> row) => ShopNotification(
        id: row['notification_id'] as int,
        orderId: row['order_id'] as int?,
        kind: row['kind'] ?? '',
        title: row['title'] ?? '',
        body: row['body'] ?? '',
        createdAt: DateTime.tryParse('${row['created_at']}')?.toLocal() ??
            DateTime.now(),
        readAt: row['read_at'] == null
            ? null
            : DateTime.tryParse('${row['read_at']}')?.toLocal(),
      );
}
