import 'product.dart' show numericOf;

/// What the shop knows about whether one of its own builds can be sold.
///
/// The Gaming and Office ranges are assembled in the shop, so a machine's
/// availability is a fact about its parts rather than about its own row.
/// prebuilt_availability does that arithmetic in the database — worst
/// component wins — and this is the answer.
///
/// [pending] is the important field. A machine whose bill of materials is
/// only half filled in has not been described well enough to draw a badge
/// from, and saying "In Stock" on that basis would be a guess wearing a
/// badge's clothes. While pending is above zero the screens fall back to
/// the machine's own stock_status; see [PrebuiltAvailability.statusOr].
class PrebuiltAvailability {
  final int prebuiltId;
  final int linked;
  final int pending;
  final int notStocked;
  final String? derivedStatus; // 'in', 'low', 'out', or null when nothing is linked
  final String blockingParts; // names of the out-of-stock parts, comma separated

  const PrebuiltAvailability({
    required this.prebuiltId,
    required this.linked,
    required this.pending,
    required this.notStocked,
    required this.derivedStatus,
    required this.blockingParts,
  });

  factory PrebuiltAvailability.fromRow(Map<String, dynamic> row) =>
      PrebuiltAvailability(
        prebuiltId: row['prebuilt_id'] as int,
        linked: (row['linked'] ?? 0) as int,
        pending: (row['pending'] ?? 0) as int,
        notStocked: (row['not_stocked'] ?? 0) as int,
        derivedStatus: row['derived_status'] as String?,
        blockingParts: row['blocking_parts'] ?? '',
      );

  /// True once every slot has been answered, so the derived status can
  /// be trusted on its own.
  bool get isComplete => pending == 0 && derivedStatus != null;

  /// The status to show, given what the machine's own row claims.
  ///
  /// Complete bill of materials wins, because it is the more specific
  /// truth: it knows *why*. Otherwise the machine's own status stands,
  /// exactly as it did before any of this existed.
  String statusOr(String ownStatus) => isComplete ? derivedStatus! : ownStatus;

  /// The parts holding this machine back, as a sentence, or null when
  /// nothing is.
  String? get blockedBy {
    if (!isComplete || derivedStatus != 'out' || blockingParts.isEmpty) {
      return null;
    }
    return blockingParts;
  }
}

/// One priced thing a customer can add when buying a machine.
///
/// The shop quotes these as a difference — "+RM499 to RTX 5050 8GB" — so
/// [priceDelta] is what it adds to the order, never a replacement total.
/// The machine's own price stays the base, which is what keeps the phone
/// out of the business of inventing totals.
///
/// Two kinds, and the difference is real even though the tick box looks
/// the same. An **upgrade** changes what the machine is — a bigger drive
/// instead of the one it ships with. An **accessory** is a separate
/// thing sold beside it at a price that exists only because a machine is
/// being bought at the same time.
class PrebuiltUpgrade {
  final int id;
  final int prebuiltId;
  final String slot; // 'gpu', 'ssd', 'ram', ... matching the spec keys
  final String label;
  final double priceDelta;
  final String kind; // 'upgrade' or 'accessory'

  const PrebuiltUpgrade({
    required this.id,
    required this.prebuiltId,
    required this.slot,
    required this.label,
    required this.priceDelta,
    required this.kind,
  });

  bool get isAccessory => kind == 'accessory';

  factory PrebuiltUpgrade.fromRow(Map<String, dynamic> row) => PrebuiltUpgrade(
    id: row['upgrade_id'] as int,
    prebuiltId: row['prebuilt_id'] as int,
    slot: row['slot'] ?? '',
    label: row['label'] ?? '',
    priceDelta: numericOf(row['price_delta']),
    kind: row['kind'] ?? 'upgrade',
  );
}
