import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../payment_details.dart';
import '../services/shop.dart';
import '../theme.dart';

/// Where to send the money, for one method.
///
/// Shown on the checkout form before the order is placed, again on the
/// confirmation while the customer's banking app is open, and again in
/// the order history — because somebody who closed the app halfway
/// through still has to be able to find out where to pay.
class PaymentPanel extends StatelessWidget {
  final PaymentMethod method;
  const PaymentPanel({super.key, required this.method});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFC),
        border: Border.all(color: const Color(0xFFE6E8EC)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: method == PaymentMethod.qrCode ? _qr(context) : _bank(context),
    );
  }

  Widget _qr(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Scan to pay',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          // The asset is not in the repository yet, so a missing file has
          // to say so rather than throwing a grey box at the customer.
          Image.asset(
            PaymentDetails.qrAsset,
            width: 220,
            errorBuilder: (_, __, ___) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'QR image not bundled yet — add ${PaymentDetails.qrAsset}',
                style: const TextStyle(fontSize: 12, color: AppTheme.amber),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _copyLine(context, 'DuitNow ID', PaymentDetails.duitNowId),
          const SizedBox(height: 6),
          _note(),
        ],
      );

  Widget _bank(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transfer to',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _copyLine(context, 'Bank', PaymentDetails.bankName),
          _copyLine(context, 'Account name', PaymentDetails.accountName),
          _copyLine(context, 'Account number', PaymentDetails.accountNumber),
          const SizedBox(height: 6),
          _note(),
        ],
      );

  Widget _note() => Text(
        'Pay the exact amount shown, then send us the receipt.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      );

  // Tappable, because the alternative is somebody retyping an account
  // number from a screen into a banking app, which is where the digits
  // get transposed.
  Widget _copyLine(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label copied')),
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text('$label:',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600)),
              ),
              Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace')),
              ),
              const Icon(Icons.copy, size: 14, color: Colors.grey),
            ],
          ),
        ),
      );
}

/// Photograph the receipt and send it.
///
/// The picture is asked for at a size the shop can actually read — an
/// account number and an amount have to stay legible — and well inside
/// the bucket's 5MB limit. The upload and the three checks behind it are
/// in Shop.sendReceipt.
class ReceiptUploader extends StatefulWidget {
  final Shop shop;
  final int orderId;

  /// Called after a receipt lands, so the screen around this can refresh
  /// what it knows about the order.
  final VoidCallback? onSent;

  const ReceiptUploader({
    super.key,
    required this.shop,
    required this.orderId,
    this.onSent,
  });

  @override
  State<ReceiptUploader> createState() => _ReceiptUploaderState();
}

class _ReceiptUploaderState extends State<ReceiptUploader> {
  bool _busy = false;
  String? _error;
  bool _sent = false;

  Future<void> _pickAndSend(ImageSource source) async {
    setState(() {
      _error = null;
      _sent = false;
    });

    final picker = ImagePicker();
    final XFile? file;
    try {
      file = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (e) {
      setState(() => _error = 'Could not open the camera or gallery.');
      return;
    }

    if (file == null) return; // cancelled, which is not an error

    setState(() => _busy = true);
    final bytes = await file.readAsBytes();
    final problem = await widget.shop.sendReceipt(widget.orderId, bytes);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = problem;
      _sent = problem == null;
    });

    if (problem == null) widget.onSent?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Sending your receipt…', style: TextStyle(fontSize: 13)),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickAndSend(ImageSource.camera),
              icon: const Icon(Icons.photo_camera, size: 18),
              label: const Text('Photograph'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickAndSend(ImageSource.gallery),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('From gallery'),
            ),
          ),
        ]),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!,
                style: const TextStyle(color: AppTheme.red, fontSize: 12.5)),
          ),
        if (_sent)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Receipt received. We will check it and move your order on.',
              style: const TextStyle(color: AppTheme.green, fontSize: 12.5),
            ),
          ),
      ],
    );
  }
}
