/// A message from the shop about one of the customer's orders, or about a
/// product they were watching.
///
/// Written by the database at the moment staff approve a payment, reject
/// a receipt, mark an order Ready — see
/// supabase/migrations/20260911090000_order_notifications.sql — or put a
/// product on offer that this customer had saved or kept coming back to,
/// see 20260915120100_telling_the_people_who_were_watching.sql. The app
/// only ever reads these and marks them read.
class ShopNotification {
  final int id;

  /// Set on the three order messages, NULL on a price drop.
  final int? orderId;

  /// Set on a price drop, NULL on the order messages. Exactly one of
  /// this and [orderId] is set, which is what decides where a tap goes.
  final int? productId;

  /// 'payment_approved', 'payment_rejected', 'order_ready',
  /// 'deal_started' or 'recommendation'.
  final String kind;
  final String title;
  final String body;
  final DateTime createdAt;
  DateTime? readAt;

  ShopNotification({
    required this.id,
    required this.orderId,
    this.productId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  bool get unread => readAt == null;

  /// The one kind where the customer has to do something.
  bool get needsAction => kind == 'payment_rejected';

  /// News rather than an instruction: a product they were watching has
  /// come down in price.
  bool get isPriceDrop => kind == 'deal_started';

  /// A "Picked for you" from the recommender. Names a product, like a
  /// price drop, so a tap opens it.
  bool get isRecommendation => kind == 'recommendation';

  /// Takes both a row from a select and the `newRecord` Realtime hands
  /// over, which carry the same columns under the same names.
  factory ShopNotification.fromRow(Map<String, dynamic> row) => ShopNotification(
        id: row['notification_id'] as int,
        orderId: row['order_id'] as int?,
        productId: row['product_id'] as int?,
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
