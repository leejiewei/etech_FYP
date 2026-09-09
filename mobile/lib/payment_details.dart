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
/// THE BANK ACCOUNT IS REAL. THE DUITNOW ID IS NOT, YET.
///
/// The transfer details below are the shop's actual Maybank account and
/// match web/js/payment.js exactly — two clients quoting two different
/// account numbers is worse than either being wrong. The DuitNow entry is
/// still a placeholder, written to be unmistakable rather than plausible.
///
/// Because one method works and the other does not, `duitNowReady` decides
/// whether the app offers DuitNow at all. To turn it back on: set
/// duitNowId, drop the image into assets/images/duitnow-qr.png, add it to
/// pubspec.yaml, and change nothing else here or on the website.
/// ------------------------------------------------------------
class PaymentDetails {
  static const String duitNowPlaceholder =
      'PLACEHOLDER — set this in payment_details.dart';

  static const String bankName = 'Maybank';
  static const String accountName = 'eTech Computer';
  static const String accountNumber = '557139242697';
  static const String duitNowId = duitNowPlaceholder;

  /// Bundled rather than fetched: the customer is standing at a till with
  /// a banking app open and possibly no signal to spare.
  static const String qrAsset = 'assets/images/duitnow-qr.png';

  /// Whether DuitNow can actually be paid. The website's duitNowReady()
  /// in web/js/payment.js is the same check against the same values, and
  /// the two must agree about which methods the shop accepts.
  static bool get duitNowReady =>
      duitNowId.trim().isNotEmpty && duitNowId != duitNowPlaceholder;
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
