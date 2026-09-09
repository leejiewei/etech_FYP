import 'dart:async';

import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/shop.dart';
import '../theme.dart';

/// A price, with the deal on it if there is one.
///
/// Every price the app draws goes through here, so a struck-through
/// RM1,499 and the RM1,249 beside it are two halves of one decision made
/// in one place -- and so a product on offer looks the same in the Shop
/// grid, on its own page and in the basket.
///
/// The old price stays visible rather than being replaced. A number
/// nobody can see is not a saving anybody believes.
///
/// [showCountdown] adds a ticking "Ends in 02:14:09" under the price and
/// is off by default. It is worth having on the Deals tab and on a
/// product's own page, and not worth having on a grid card: a screen of
/// twenty deals would be twenty timers all waking up to write the same
/// second, and at that size the struck-through price already says what
/// needs saying.
///
/// When the clock does run out, this widget puts the list price back by
/// itself. That is the visible half of a deal expiring. The half that
/// matters is in the database, which stops handing the deal out and
/// stops charging it at the same instant, whether or not anybody's phone
/// noticed.
class DealPriceText extends StatefulWidget {
  final Product product;
  final Shop shop;
  final double size;
  final bool showCountdown;

  /// Extra money on top of the product's own price -- the ticked
  /// upgrades on one of the shop's builds. A deal is on the machine and
  /// not on the options bolted to it, which is how the till works too,
  /// so this is added after the deal has been applied.
  final double extra;

  const DealPriceText({
    super.key,
    required this.product,
    required this.shop,
    this.size = 15,
    this.extra = 0,
    this.showCountdown = false,
  });

  @override
  State<DealPriceText> createState() => _DealPriceTextState();
}

class _DealPriceTextState extends State<DealPriceText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(DealPriceText old) {
    super.didUpdateWidget(old);
    _startTimerIfNeeded();
  }

  // A product with no deal on it costs no timer. One that has a deal is
  // ticked every second only where a countdown is being shown; elsewhere
  // it is checked once a minute, which is often enough for the price to
  // correct itself while somebody is reading the page.
  void _startTimerIfNeeded() {
    _timer?.cancel();
    _timer = null;

    if (widget.shop.dealFor(widget.product) == null) return;

    final period = widget.showCountdown
        ? const Duration(seconds: 1)
        : const Duration(minutes: 1);

    _timer = Timer.periodic(period, (_) {
      if (!mounted) return;
      setState(() {});
      // Once it is over there is nothing left to count.
      if (widget.shop.dealFor(widget.product) == null) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.shop.dealFor(widget.product);
    final now = money(widget.shop.priceOf(widget.product) + widget.extra);

    if (deal == null) {
      return Text(now,
          style: TextStyle(
              fontSize: widget.size,
              fontWeight: FontWeight.bold,
              color: AppTheme.redDark));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(money(widget.product.price + widget.extra),
            style: TextStyle(
              fontSize: widget.size - 3,
              color: Colors.grey.shade500,
              decoration: TextDecoration.lineThrough,
            )),
        Text(now,
            style: TextStyle(
                fontSize: widget.size,
                fontWeight: FontWeight.bold,
                color: AppTheme.red)),
        if (widget.showCountdown) ...[
          const SizedBox(height: 6),
          _countdownPill(deal.timeLeft),
        ],
      ],
    );
  }

  Widget _countdownPill(Duration left) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E0),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          'Ends in ${formatCountdown(left)}',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF8A4B00),
            fontWeight: FontWeight.w600,
            // Tabular figures, so the seconds do not shove the label
            // sideways twice a second as the digits change width.
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      );
}
