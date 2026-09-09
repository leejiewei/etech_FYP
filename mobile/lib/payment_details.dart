/// How the shop takes money.
///
/// There is no payment gateway. A student project has no merchant
/// account, and the shop this is modelled on does what most small
/// Malaysian retailers do: shows a DuitNow QR or a bank account, lets the
/// customer pay from their own banking app, and has somebody look at the
/// receipt before anything is packed.
///
/// These are the same facts the website keeps in web/js/payment.js. They
/// are shop facts rather than screen furniture, which is why they sit in
/// one file per client rather than being typed into each screen.
///
/// ------------------------------------------------------------
/// THESE ARE PLACEHOLDERS AND MUST BE REPLACED BEFORE THE SHOP TAKES A
/// REAL PAYMENT.
///
/// They are deliberately obvious rather than plausible. A realistic
/// looking account number in a demo is the kind of thing that gets
/// screenshotted, quoted in a report, or paid into by somebody who did
/// not read the surrounding screen — so the fake is written to be
/// unmistakable. Put the real ones here, drop the QR image into
/// assets/images/duitnow-qr.png, add it to pubspec.yaml, and delete this
/// notice. The website's copy in web/js/payment.js has to change with
/// it: two clients quoting two different account numbers is worse than
/// either being wrong.
/// ------------------------------------------------------------
class PaymentDetails {
  static const String bankName = 'PLACEHOLDER BANK — NOT A REAL ACCOUNT';
  static const String accountName =
      'eTech Computer Accessories (PLACEHOLDER)';
  static const String accountNumber = '0000-0000-0000';
  static const String duitNowId = 'PLACEHOLDER — set this in payment_details.dart';

  /// Bundled rather than fetched: the customer is standing at a till with
  /// a banking app open and possibly no signal to spare.
  static const String qrAsset = 'assets/images/duitnow-qr.png';
}

/// The two ways to pay, as the database spells them.
enum PaymentMethod { qrCode, bankTransfer }

extension PaymentMethodNames on PaymentMethod {
  /// What place_order() expects. Matches the payment_method enum in
  /// Postgres exactly.
  String get value =>
      this == PaymentMethod.qrCode ? 'QR_CODE' : 'BANK_TRANSFER';

  String get label => this == PaymentMethod.qrCode
      ? 'DuitNow QR'
      : 'Bank transfer';

  String get hint => this == PaymentMethod.qrCode
      ? 'Scan with any Malaysian banking app'
      : 'Online transfer to our account';
}

String paymentMethodLabel(String? value) {
  switch (value) {
    case 'QR_CODE':
      return 'DuitNow QR';
    case 'BANK_TRANSFER':
      return 'Bank transfer';
    default:
      return 'Not recorded';
  }
}

String paymentStatusLabel(String? value) {
  switch (value) {
    case 'APPROVED':
      return 'Payment confirmed';
    case 'REJECTED':
      return 'Payment needs another look';
    case 'PENDING':
      return 'Checking your payment';
    default:
      return 'Not recorded';
  }
}
