import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

/// The connection to Supabase.
///
/// This file used to be an HTTP client for the shop's PHP API. It kept
/// hold of the PHPSESSID cookie by hand, because Flutter's http package
/// does not do cookies the way a browser does, and saved it to the phone
/// so closing the app did not sign you out.
///
/// All of that is gone. The app holds a Supabase session — a signed token
/// rather than a pointer to a session file on somebody's server — and
/// supabase_flutter stores it, refreshes it before it expires and attaches
/// it to every request. The phone and the website are now doing exactly
/// the same thing as each other, against exactly the same policies.
class Api {
  /// Called once from main() before anything is drawn.
  static Future<void> init() async {
    await Supabase.initialize(
      url: Config.supabaseUrl,
      publishableKey: Config.supabaseKey,
    );
  }

  static SupabaseClient get db => Supabase.instance.client;

  /// Reading more than a thousand rows.
  ///
  /// Supabase returns at most 1000 rows per request, and the catalogue's
  /// specifications run to more than that. The PHP had no such limit and
  /// simply handed over everything the query matched, so this is the one
  /// genuinely new thing about talking to the database directly.
  ///
  /// Truncating silently would be the worst kind of bug — the shop would
  /// look fine and a few products would quietly lose the specs the PC
  /// Builder's compatibility checks depend on — so anything that could be
  /// long is read a page at a time until a short page ends it.
  static const int pageSize = 1000;

  static Future<List<Map<String, dynamic>>> selectAll(
    PostgrestTransformBuilder<PostgrestList> Function() build,
  ) async {
    final rows = <Map<String, dynamic>>[];
    for (var from = 0;; from += pageSize) {
      final page = await build().range(from, from + pageSize - 1);
      rows.addAll(page.cast<Map<String, dynamic>>());
      if (page.length < pageSize) return rows;
    }
  }

  /// Turns a database error into something a customer can read.
  ///
  /// The functions in the database raise their refusals deliberately —
  /// "Your cart is empty.", "Sorry, X is out of stock." — and those should
  /// be shown as they are. Anything else is a fault rather than a refusal.
  static String message(Object error, [String? fallback]) {
    if (error is PostgrestException) {
      // raise_exception: everything the shop deliberately refuses.
      if (error.code == 'P0001') return error.message;
      // insufficient_privilege: in practice, a session that has gone stale.
      if (error.code == '42501') return 'Please sign in first.';
      return fallback ?? error.message;
    }
    if (error is AuthException) return error.message;
    return fallback ?? 'Could not reach the shop. Check your connection.';
  }
}
