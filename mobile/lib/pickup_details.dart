/// Where the order is collected.
///
/// eTech does not deliver. An order is paid for in the app, put aside
/// behind the counter, and picked up by the person who placed it — so the
/// one thing every screen has to be able to say is where that counter is
/// and when somebody is standing at it.
///
/// These are the same facts the website keeps in web/js/pickup.js, and
/// they sit in one file per client for the same reason payment_details.dart
/// does: they are shop facts rather than screen furniture, and two clients
/// sending customers to two different addresses is worse than either being
/// wrong.
///
/// ------------------------------------------------------------
/// THE ADDRESS BELOW IS THE REAL SHOP.
///
/// Unlike the DuitNow ID in payment_details.dart, this one is filled in:
/// it is the unit in Kompleks Bukit Jambul, and somebody who reads it off
/// the checkout screen and drives there on a Saturday will arrive at the
/// right door. Treat it accordingly — it is the shop's actual address,
/// not demo furniture, and web/js/pickup.js carries the same two strings
/// character for character.
///
/// `ready` still guards every use of it. Blank the address out and every
/// screen falls back to promising a message instead of naming a street,
/// which is what should happen if the shop ever moves and nobody has the
/// new unit number yet.
/// ------------------------------------------------------------
class PickupDetails {
  static const String placeholder =
      'PLACEHOLDER — set this in pickup_details.dart';

  static const String shopName = 'eTech Computer';
  static const String address =
      '3A-4-164 & 165, Kompleks Bukit Jambul, Jalan Rumbia, Bukit Jambul, 11900 Bayan Lepas, Pulau Pinang';
  /// Monday to Sunday, confirmed by the owner. 'daily' rather than a
  /// list of days because the notice prints it straight after 'Open'.
  static const String hours = 'daily, 11am - 8pm';

  /// Shown beside the address when there is one. A landmark saves more
  /// phone calls than a postcode does — and here the mall is the landmark,
  /// so it is already in the address above and this stays empty.
  static const String landmark = '';

  /// Whether the shop can actually be found. Everything that prints an
  /// address asks this rather than deciding for itself, so there is one
  /// answer and it changes in one place. pickupReady() in web/js/pickup.js
  /// is the same check against the same values.
  static bool get ready => address.trim().isNotEmpty && address != placeholder;

  /// The collection notice, in full.
  ///
  /// Two versions, and the difference is not cosmetic. With an address it
  /// tells somebody where to go; without one it promises a message, which
  /// is a thing the shop can actually keep. It never invents a street.
  static String get notice => ready
      ? 'We do not deliver. Collect your order from $shopName, $address'
          '${landmark.isEmpty ? '' : ' ($landmark)'}.\n'
          'Open $hours.\n'
          'We will message you when it is ready — please do not come before.'
      : 'We do not deliver. Your order is put aside for you, and we will '
          'message the phone number above with the address and the pickup '
          'time as soon as it is ready.';

  /// One line, for an order card, where the whole notice would not fit.
  static String get line => ready
      ? 'Collect at $shopName, $address'
      : 'Collect at the shop — we will message you the address when it is ready';
}
