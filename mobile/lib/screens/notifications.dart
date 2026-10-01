import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../services/shop.dart';
import '../theme.dart';
import 'orders.dart';
import 'product_detail.dart';

/// The messages the shop has sent: how their orders are moving, and when
/// something they were watching has come down in price.
///
/// Opening this screen is reading them: everything unread is marked read
/// in the database as it opens. The highlight stays on the new ones
/// until the screen is closed, so they can still be picked out.
class NotificationsScreen extends StatefulWidget {
  final Shop shop;
  const NotificationsScreen({super.key, required this.shop});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// Which ones were unread when the screen opened.
  late final Set<int> _fresh =
      widget.shop.notifications.where((n) => n.unread).map((n) => n.id).toSet();

  @override
  void initState() {
    super.initState();
    widget.shop.markNotificationsRead();
  }

  /// Once more on the way out, for anything that arrived while the list
  /// was on screen — it has been seen, and should not come back as a badge.
  @override
  void dispose() {
    widget.shop.markNotificationsRead();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: AnimatedBuilder(
        animation: widget.shop,
        builder: (context, _) {
          final list = widget.shop.notifications;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none, size: 50, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('Nothing yet. We will let you know here when your order moves.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: widget.shop.loadNotifications,
            child: ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _tile(list[i]),
            ),
          );
        },
      ),
    );
  }

  /// Where a message leads. A price drop names a product and opens it; the
  /// three order messages name an order and open Order History.
  ///
  /// The product is looked up in the catalogue the app already holds, so a
  /// message about something since delisted falls back to Order History
  /// rather than opening a screen with nothing on it.
  void _open(ShopNotification n) {
    final id = n.productId;
    if (id != null) {
      final product = widget.shop.byId(id);
      if (product != null) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    ProductDetailScreen(product: product, shop: widget.shop)));
        return;
      }
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => OrdersScreen(shop: widget.shop)));
  }

  Widget _tile(ShopNotification n) {
    // Anything that arrives while the screen is open is new too.
    final fresh = _fresh.contains(n.id) || n.unread;
    final colour = n.needsAction
        ? AppTheme.red
        : n.isPriceDrop
            ? const Color(0xFFB4642A)
            : n.isRecommendation
            ? const Color(0xFF1F6FB2)
            : n.kind == 'order_ready'
                ? const Color(0xFF6A3FB5)
                : AppTheme.green;
    final icon = n.needsAction
        ? Icons.error_outline
        : n.isPriceDrop
            ? Icons.sell_outlined
            : n.isRecommendation
            ? Icons.auto_awesome_outlined
            : n.kind == 'order_ready'
                ? Icons.storefront_outlined
                : Icons.check_circle_outline;

    return Material(
      color: fresh ? const Color(0xFFFDF2F3) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _open(n),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colour),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: n.needsAction ? AppTheme.red : AppTheme.ink)),
                    const SizedBox(height: 3),
                    Text(n.body, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 5),
                    Text(_when(n.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _when(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${t.day}/${t.month}/${t.year}';
  }
}
