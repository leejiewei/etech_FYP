/// Collection or delivery, and the words each one uses.
///
/// An order goes through four stages in the database — Pending,
/// Processing, Ready, Collected — and those four are the same four
/// whichever way the customer is getting their things. What differs is
/// what the last two are *called*:
///
///     stage        PICKUP             DELIVERY
///     Ready        Ready to collect   Shipped
///     Collected    Collected          Delivered
///
/// Keeping one ladder and translating the rungs is deliberate. The
/// alternative — seven stages, three of them meaningless for any given
/// order — would give staff a dropdown full of wrong answers and would
/// make every report that groups by status have to know that Ready and
/// Shipped are the same thing. See
/// supabase/migrations/20260916160000_collect_it_or_have_it_sent.sql.
///
/// web/js/fulfilment.js is the same table for the website. The two must
/// agree: one stage described two ways on two screens is worse than
/// either wording being wrong.
library;

/// The two ways of getting an order, as the database spells them.
enum Fulfilment { pickup, delivery }

extension FulfilmentNames on Fulfilment {
  /// What place_order() expects. Matches the fulfilment_method enum in
  /// Postgres exactly.
  String get value => this == Fulfilment.delivery ? 'DELIVERY' : 'PICKUP';

  String get label => this == Fulfilment.delivery ? 'Deliver to me' : 'Collect at the shop';

  String get hint => this == Fulfilment.delivery
      ? 'We send it to your address'
      : 'Bukit Jambul, open daily 11am - 8pm';
}

/// Everything a stage is called, keyed by the method then the stage.
const Map<String, Map<String, String>> _stageWords = {
  'PICKUP': {
    'Pending': 'Pending',
    'Processing': 'Processing',
    'Ready': 'Ready to collect',
    'Collected': 'Collected',
    'Cancelled': 'Cancelled',
  },
  'DELIVERY': {
    'Pending': 'Pending',
    'Processing': 'Processing',
    'Ready': 'Shipped',
    'Collected': 'Delivered',
    'Cancelled': 'Cancelled',
  },
};

/// The four stages in order. A progress strip walks this, so the order
/// matters as much as the words.
const List<String> fulfilmentStages = [
  'Pending',
  'Processing',
  'Ready',
  'Collected',
];

/// Falls back to PICKUP for a row whose method is missing rather than
/// throwing: an order placed before the column existed is a collection as
/// far as anything here is concerned, and a blank stage on screen helps
/// nobody.
String stageLabel(String status, String? method) {
  final words = _stageWords[method] ?? _stageWords['PICKUP']!;
  return words[status] ?? status;
}

/// The same four labels, in order, for a progress strip.
List<String> stageLabels(String? method) =>
    fulfilmentStages.map((s) => stageLabel(s, method)).toList();

bool isDelivery(String? method) => method == 'DELIVERY';

/// What the method itself is called, when it has to be named on its own.
String fulfilmentLabel(String? method) =>
    isDelivery(method) ? 'Delivery' : 'Collection';
