import 'dart:async';

import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/notification.dart';
import '../payment_details.dart';
import '../pickup_details.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../widgets/payment_panel.dart';

/// The customer's own orders, and where each one has got to.
class OrdersScreen extends StatefulWidget {
  final Shop shop;
  const OrdersScreen({super.key, required this.shop});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Order>> _future;
  StreamSubscription<ShopNotification>? _arrivals;

  @override
  void initState() {
    super.initState();
    _future = widget.shop.loadOrders();
    // Staff just moved one of these orders. Reading them again is how the
    // card finds out what changed, rather than guessing from the message.
    _arrivals = widget.shop.notificationArrivals.listen(
        (_) => setState(() => _future = widget.shop.loadOrders()));
  }

  @override
  void dispose() {
    _arrivals?.cancel();
    super.dispose();
  }

  // The shop has a counter, not a courier account: an order is put
  // aside and collected. Ready is the stage that messages the customer.
  static const List<String> _stages = [
    'Pending',
    'Processing',
    'Ready',
    'Collected'
  ];

  /// What a stage means to somebody who is not standing behind the
  /// counter. Only where the bare word is not enough — 'Ready' on its own
  /// reads as a shrug, where 'Ready to collect' is an instruction.
  static String _statusLabel(String status) =>
      status == 'Ready' ? 'Ready to collect' : status;

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
                child: Text(_statusLabel(order.status),
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
          _collectionLine(order),
          _paymentSection(order),
        ],
      ),
    );
  }

  /// Where to come and get it — but only while that is still something
  /// the customer has to do. A cancelled order has nothing waiting, and
  /// an order already collected would be somebody being told to fetch
  /// what is in their hands, so both are left alone.
  Widget _collectionLine(Order order) {
    if (order.status == 'Cancelled' || order.status == 'Collected') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(PickupDetails.line,
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
    );
  }

  /// Where the money stands, and what the customer can do about it.
  ///
  /// Kept apart from the collection stages above deliberately. An order can
  /// be Pending with the payment approved, or Processing with the payment
  /// rejected, and folding those into one line would hide exactly the
  /// case the customer needs to act on.
  Widget _paymentSection(Order order) {
    // Null means this order predates the shop being able to take a
    // payment at all — it went through the old card sandbox. Said plainly
    // rather than dressed up as a bank transfer that never happened.
    if (order.paymentMethod == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text('Placed before online payment was available.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
      );
    }

    final settled = order.paymentSettled;
    final rejected = order.paymentStatus == 'REJECTED';
    final colour = settled
        ? AppTheme.green
        : rejected
            ? AppTheme.red
            : AppTheme.amber;

    final method = PaymentMethod.values.firstWhere(
      (m) => m.value == order.paymentMethod,
      orElse: () => PaymentMethod.bankTransfer,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(paymentStatusLabel(order.paymentStatus),
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: colour)),
          ),
          const SizedBox(width: 8),
          Text(paymentMethodLabel(order.paymentMethod),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ]),

        // Approved is the end of it. There is nothing for the customer to
        // do and nothing they are allowed to change.
        if (settled) const SizedBox.shrink() else ...[
          const SizedBox(height: 8),
          Text(
            rejected
                ? 'We could not match that receipt to this order. Please send '
                    'another — a clear photo showing the amount and the date.'
                : order.receiptPath != null
                    ? 'Your receipt is with us. We will confirm it shortly.'
                    : 'We have not received a receipt for this order yet.',
            style: TextStyle(
                fontSize: 12,
                color: rejected ? AppTheme.red : Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          PaymentPanel(method: method),
          const SizedBox(height: 10),
          ReceiptUploader(
            shop: widget.shop,
            orderId: order.id,
            // Reload rather than patch the one card: the database has
            // just moved payment_status back to PENDING, and reading it
            // again is how this screen finds that out rather than
            // guessing it.
            onSent: () => setState(() => _future = widget.shop.loadOrders()),
          ),
        ],
      ],
    );
  }
}
