import 'package:flutter/material.dart';
import '../services/shop.dart';
import '../theme.dart';

/// Checkout.
///
/// Only the delivery details and an optional coupon are sent. Every price,
/// the discount and the total are worked out by the server from the basket
/// in the database, so nothing the phone sends can change what things cost.
///
/// The card fields are a mock sandbox — nothing is sent anywhere and no
/// card details are stored.
class CheckoutScreen extends StatefulWidget {
  final Shop shop;
  const CheckoutScreen({super.key, required this.shop});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _coupon = TextEditingController();
  final _card = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();

  String? _error;
  bool _busy = false;
  Map<String, dynamic>? _done;

  @override
  void initState() {
    super.initState();
    final user = widget.shop.user;
    _name.text = user?['name'] ?? '';
    _phone.text = user?['phone'] ?? '';
    _address.text = user?['address'] ?? '';
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _coupon, _card, _expiry, _cvv]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    final digits = _card.text.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{16}$').hasMatch(digits)) {
      setState(() => _error =
          'Enter a 16-digit mock card number (this is not a real payment).');
      return;
    }
    if (_name.text.trim().isEmpty || _address.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in your delivery details.');
      return;
    }

    setState(() => _busy = true);
    final result = await widget.shop.placeOrder(
      _name.text.trim(),
      _phone.text.trim(),
      _address.text.trim(),
      _coupon.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result['ok'] == true) {
        _done = result;
      } else {
        _error = result['error'] ?? 'Could not place the order.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_done != null) return _confirmation();

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card_(
            'Order summary',
            Column(
              children: [
                ...widget.shop.cart.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text('${item.qty} ×  ',
                              style: TextStyle(color: Colors.grey.shade600)),
                          Expanded(
                              child: Text(item.name,
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis)),
                          Text(money(item.lineTotal),
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    )),
                const Divider(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(money(widget.shop.cartTotal),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.redDark)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card_(
            'Delivery details',
            Column(children: [
              _field('Full name', _name),
              _field('Phone number', _phone, keyboard: TextInputType.phone),
              _field('Shipping address', _address, lines: 3),
              _field('Coupon code (optional)', _coupon,
                  hint: 'e.g. PARTS10', caps: true),
            ]),
          ),
          const SizedBox(height: 14),
          _card_(
            'Payment (mock sandbox)',
            Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4DD),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'This is a simulated payment. Nothing is charged and no card '
                  'details are stored — please do not enter a real card.',
                  style: TextStyle(fontSize: 12, color: AppTheme.amber),
                ),
              ),
              _field('Card number', _card,
                  hint: '4111 1111 1111 1111', keyboard: TextInputType.number),
              Row(children: [
                Expanded(child: _field('Expiry', _expiry, hint: '12/28')),
                const SizedBox(width: 12),
                Expanded(
                    child: _field('CVV', _cvv,
                        hint: '123', keyboard: TextInputType.number)),
              ]),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_error!,
                  style: const TextStyle(color: AppTheme.red, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Place Order (Simulated)'),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _confirmation() => Scaffold(
        appBar: AppBar(title: const Text('Order placed'), automaticallyImplyLeading: false),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 66, color: AppTheme.green),
                const SizedBox(height: 18),
                Text('Order #${_done!['orderId']}',
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if ((_done!['discount'] as num) > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Coupon ${_done!['coupon']} saved you '
                      '${money(_done!['discount'] as num)}',
                      style: const TextStyle(color: AppTheme.green, fontSize: 13),
                    ),
                  ),
                Text('Total: ${money(_done!['total'] as num)}',
                    style: const TextStyle(fontSize: 17)),
                const SizedBox(height: 16),
                Text(
                  'This was a simulated payment — no real money was charged. '
                  'You can follow the order from your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 26),
                ElevatedButton(
                  onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                  child: const Text('Back to shopping'),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _card_(String title, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: const Border(top: BorderSide(color: AppTheme.red, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _field(String label, TextEditingController controller,
          {String? hint,
          int lines = 1,
          TextInputType? keyboard,
          bool caps = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          maxLines: lines,
          keyboardType: keyboard,
          textCapitalization:
              caps ? TextCapitalization.characters : TextCapitalization.none,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );
}
