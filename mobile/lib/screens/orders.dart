import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../services/shop.dart';
import '../theme.dart';

/// The customer's own orders, and where each one has got to.
class OrdersScreen extends StatefulWidget {
  final Shop shop;
  const OrdersScreen({super.key, required this.shop});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Order>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.shop.loadOrders();
  }

  static const List<String> _stages = ['Pending', 'Processing', 'Shipped', 'Delivered'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: FutureBuilder<List<Order>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 50, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No orders yet',
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = widget.shop.loadOrders());
              await _future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _orderCard(orders[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _orderCard(Order order) {
    final stageIndex = _stages.indexOf(order.status);
    final cancelled = order.status == 'Cancelled';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order #${order.id}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.statusColour(order.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(order.status,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.statusColour(order.status))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${order.date.day}/${order.date.month}/${order.date.year}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),

          // Progress through the stages
          if (!cancelled) ...[
            const SizedBox(height: 14),
            Row(
              children: List.generate(_stages.length * 2 - 1, (i) {
                if (i.isOdd) {
                  final done = (i ~/ 2) < stageIndex;
                  return Expanded(
                    child: Container(
                      height: 2,
                      color: done ? AppTheme.green : AppTheme.line,
                    ),
                  );
                }
                final step = i ~/ 2;
                final reached = step <= stageIndex;
                return Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: reached ? AppTheme.green : Colors.white,
                    border: Border.all(
                        color: reached ? AppTheme.green : AppTheme.line, width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: reached
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                );
              }),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _stages
                  .map((s) => Text(s,
                      style: TextStyle(
                          fontSize: 9,
                          color: _stages.indexOf(s) <= stageIndex
                              ? AppTheme.green
                              : Colors.grey.shade500)))
                  .toList(),
            ),
          ],

          const Divider(height: 24),
          ...order.items.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Text('${line.quantity} ×  ',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    Expanded(
                        child: Text(line.name,
                            style: const TextStyle(fontSize: 12.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                    Text(money(line.lineTotal), style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
              )),
          if (order.discount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Coupon ${order.couponCode}: −${money(order.discount)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.green)),
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w600)),
              Text(money(order.total),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.redDark)),
            ],
          ),
        ],
      ),
    );
  }
}
