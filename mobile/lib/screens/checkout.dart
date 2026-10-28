import 'package:flutter/material.dart';
import '../fulfilment.dart';
import '../payment_details.dart';
import '../pickup_details.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../widgets/payment_panel.dart';

/// Checkout.
///
/// A name, a phone number, how the customer wants to get their things,
/// an optional coupon and how they intend to pay. The address goes with
/// it only when they chose delivery — a collection has nowhere to send
/// anything. See fulfilment.dart for the two vocabularies and
/// pickup_details.dart for where the shop is.
///
/// Every price, the discount and the total are worked out by the server
/// from the basket in the database, so nothing the phone sends can change
/// what things cost.
///
/// The card sandbox that used to sit at the bottom of this screen is
/// gone. It took sixteen digits, sent them nowhere and said so. In its
/// place is what a small shop without a payment gateway actually does:
/// show a DuitNow QR or a bank account, take a photograph of the receipt,
/// and have somebody check it against the amount before anything is put
/// aside.
///
/// The order is written before the receipt is asked for, and that order
/// is deliberate. The receipt has to be filed against something, and the
/// customer has to know the exact amount before they can pay it. So the
/// order is placed, its payment_status starts at PENDING, and the
/// confirmation screen is where the money actually moves. An order with
/// no receipt against it is not a failure — it is a customer who has not
/// paid yet, which the shop can see and chase.
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

  // Collection is the default because it is what most orders are, and
  // because it is the one that needs nothing else typed in.
  Fulfilment _fulfilment = Fulfilment.pickup;

  // Not qrCode unconditionally: the markup equivalent of an unattended
  // default is how somebody ends up on the one method that cannot be paid.
  PaymentMethod _method = PaymentDetails.duitNowReady
      ? PaymentMethod.qrCode
      : PaymentMethod.bankTransfer;

  String? _error;
  bool _busy = false;
  Map<String, dynamic>? _done;

  @override
  void initState() {
    super.initState();
    final user = widget.shop.user;
    _name.text = user?['name'] ?? '';
    _phone.text = user?['phone'] ?? '';
    // Filled now rather than when delivery is picked. The profile is
    // already loaded here, and a field that populates itself as you tap a
    // radio button looks like a glitch.
    _address.text = user?['address'] ?? '';
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _coupon]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    // The phone number is required either way: it is how the shop says
    // the order is on the counter, and how a driver finds the gate.
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in your name and phone number.');
      return;
    }

    // The address is required for one method and meaningless for the
    // other. Checked here as well as in the database so the answer comes
    // back without a round trip.
    if (_fulfilment == Fulfilment.delivery && _address.text.trim().isEmpty) {
      setState(() => _error = 'Please give us an address to deliver to.');
      return;
    }

    setState(() => _busy = true);
    final couponProblem = await widget.shop.couponProblem(_coupon.text.trim());
    if (!mounted) return;
    if (couponProblem != null) {
      setState(() {
        _busy = false;
        _error = couponProblem;
      });
      return;
    }
    final result = await widget.shop.placeOrder(
      _name.text.trim(),
      _phone.text.trim(),
      _coupon.text.trim(),
      paymentMethod: _method.value,
      fulfilment: _fulfilment.value,
      address: _address.text.trim(),
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
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card_(
              'Order summary',
              Column(
                children: [
                  ...widget.shop.cart.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            '${item.qty} ×  ',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          Expanded(
                            child: Text(
                              item.colour == null
                                  ? item.name
                                  : '${item.name} (${item.colour})',
                              style: const TextStyle(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            money(item.lineTotal),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        money(widget.shop.cartTotal),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.redDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card_(
              'How would you like to get it?',
              RadioGroup<Fulfilment>(
                groupValue: _fulfilment,
                onChanged: (chosen) =>
                    setState(() => _fulfilment = chosen ?? _fulfilment),
                child: Column(
                  children: Fulfilment.values
                      .map((f) => RadioListTile<Fulfilment>(
                            value: f,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            activeColor: AppTheme.red,
                            title: Text(f.label,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: Text(f.hint,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600)),
                          ))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _card_(
              'Your details',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field(
                    'Full name',
                    _name,
                    autofill: const [AutofillHints.name],
                  ),
                  _field(
                    'Phone number',
                    _phone,
                    keyboard: TextInputType.phone,
                    autofill: const [AutofillHints.telephoneNumber],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _fulfilment == Fulfilment.delivery
                          ? 'We message this number about your delivery.'
                          : 'We message this number when your order is ready '
                              'to collect.',
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.grey.shade600),
                    ),
                  ),
                  // Only for a delivery. Absent rather than disabled for a
                  // collection: a greyed box still reads as something the
                  // customer was meant to fill in.
                  if (_fulfilment == Fulfilment.delivery)
                    _field(
                      'Delivery address',
                      _address,
                      lines: 3,
                      autofill: const [AutofillHints.fullStreetAddress],
                    ),
                  _field(
                    'Coupon code (optional)',
                    _coupon,
                    hint: 'e.g. PARTS10',
                    caps: true,
                  ),
                  // Read before the order is placed, not after: whether
                  // somebody can get to the shop is part of deciding to
                  // buy.
                  if (_fulfilment == Fulfilment.pickup) _pickupNotice(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card_(
              'How are you paying?',
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Pay from your own banking app, then send us the receipt. '
                      'We check every payment by hand before we start on your '
                      'order.',
                      style:
                          TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                    ),
                  ),
                  // RadioGroup rather than a groupValue on each tile:
                  // the per-tile form is deprecated, and the group is
                  // where the chosen value belongs anyway.
                  RadioGroup<PaymentMethod>(
                    groupValue: _method,
                    onChanged: (chosen) =>
                        setState(() => _method = chosen ?? _method),
                    child: Column(
                      children: PaymentMethod.values
                          .map((m) {
                            // Greyed rather than dropped, so the list reads
                            // as a shop between QR codes rather than one
                            // that never took DuitNow.
                            final off = m == PaymentMethod.qrCode &&
                                !PaymentDetails.duitNowReady;
                            return RadioListTile<PaymentMethod>(
                              value: m,
                              enabled: !off,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              activeColor: AppTheme.red,
                              title: Text(m.label,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: off ? Colors.grey.shade500 : null)),
                              subtitle: Text(
                                  off ? 'Unavailable at the moment' : m.hint,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontStyle:
                                          off ? FontStyle.italic : FontStyle.normal,
                                      color: Colors.grey.shade600)),
                            );
                          })
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  PaymentPanel(method: _method),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.red, fontSize: 13),
                ),
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
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Place Order'),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _confirmation() => Scaffold(
    appBar: AppBar(
      title: const Text('Order placed'),
      automaticallyImplyLeading: false,
    ),
    // A list rather than a centred column: the receipt has to be sent
    // from here, and a keyboard-free camera flow still needs room to
    // scroll on a short phone.
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.check_circle, size: 60, color: AppTheme.green),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'Order #${_done!['orderId']}',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 6),
        if ((_done!['discount'] as num) > 0)
          Center(
            child: Text(
              'Coupon ${_done!['coupon']} saved you '
              '${money(_done!['discount'] as num)}',
              style: const TextStyle(color: AppTheme.green, fontSize: 13),
            ),
          ),
        Center(
          child: Text(
            'Amount to pay: ${money(_done!['total'] as num)}',
            style: const TextStyle(fontSize: 17),
          ),
        ),
        const SizedBox(height: 18),

        // The same instructions again, because this is the screen
        // somebody is looking at while their banking app is open.
        PaymentPanel(method: _method),
        const SizedBox(height: 16),

        // Repeated here on purpose: this is the screen people screenshot
        // and come back to, and it is the one that has to answer the
        // question they will have tomorrow — which is a different
        // question depending on how they asked to get it.
        if (_fulfilment == Fulfilment.pickup)
          _pickupNotice()
        else
          _deliveryNotice(),
        const SizedBox(height: 16),

        const Text('Send us your receipt',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          'A photo or screenshot of the transfer confirmation. We compare it '
          'against the amount above, then move your order on. Nothing is '
          'prepared until a member of staff has checked it.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        ReceiptUploader(
          shop: widget.shop,
          orderId: _done!['orderId'] as int,
        ),

        const SizedBox(height: 22),
        Text(
          'You can also send it later from your order history.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          child: const Text('Back to shopping'),
        ),
      ],
    ),
  );

  /// The collection notice, built from pickup_details.dart.
  ///
  /// Given a box and a left edge rather than being left as running text,
  /// because it is the one thing on this screen the customer has to act
  /// on later: nothing is posted, and somebody has to physically come and
  /// get this.
  Widget _pickupNotice() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: const BoxDecoration(
      color: Color(0xFFF4F7FB),
      borderRadius: BorderRadius.all(Radius.circular(8)),
      border: Border(left: BorderSide(color: Color(0xFF2C5D8F), width: 4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Collection at the shop',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C5D8F),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          PickupDetails.notice,
          style: TextStyle(
              fontSize: 12.5, height: 1.45, color: Colors.grey.shade800),
        ),
      ],
    ),
  );

  /// The delivery equivalent of [_pickupNotice]. Same box, same left
  /// edge, different promise — and deliberately vague about timing,
  /// because the shop has not committed to one and this screen must not
  /// invent it.
  Widget _deliveryNotice() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: const BoxDecoration(
      color: Color(0xFFF4F7FB),
      borderRadius: BorderRadius.all(Radius.circular(8)),
      border: Border(left: BorderSide(color: Color(0xFF2C5D8F), width: 4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C5D8F),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'We will send this to the address you gave us once your payment '
          'has been checked, and message you when it is on its way.',
          style: TextStyle(
              fontSize: 12.5, height: 1.45, color: Colors.grey.shade800),
        ),
      ],
    ),
  );

  Widget _card_(String title, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      border: Border.all(color: AppTheme.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    int lines = 1,
    TextInputType? keyboard,
    bool caps = false,
    List<String>? autofill,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      maxLines: lines,
      keyboardType: keyboard,
      autofillHints: autofill,
      textCapitalization: caps
          ? TextCapitalization.characters
          : TextCapitalization.none,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );
}
