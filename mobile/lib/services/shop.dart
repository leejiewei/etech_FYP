import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/notification.dart';
import '../models/prebuilt.dart';
import 'api.dart';

/// Everything the app knows about the shop, in one place.
///
/// Screens listen to this rather than fetching for themselves, so when the
/// basket changes every screen showing it updates at once. This is Flutter's
/// built-in ChangeNotifier — no extra state-management package needed.
///
/// Every method here used to call the shop's PHP API. They now go straight
/// to Supabase. The methods, and what they hand back to the screens, are
/// unchanged — the screens did not have to be touched.
///
/// The rules that used to live in PHP did not disappear; they moved into
/// the database. "Only my own basket", "only my own orders", "the shop
/// decides the price, not the phone" are all enforced by Row Level
/// Security and by database functions now, which is what makes it safe for
/// the app to hold the key at all. See supabase/migrations.
class Shop extends ChangeNotifier {
  // ---- catalogue ----
  List<Product> products = [];
  bool loadingProducts = false;
  String? loadError;

  // ---- the shop's own builds ----
  //
  // Keyed by the machine's product id. Both are empty for every product
  // that is not one of the shop's DIY builds, and the helpers below are
  // written so that an empty map means "nothing to say", never "no".
  Map<int, PrebuiltAvailability> availability = {};
  Map<int, List<PrebuiltUpgrade>> upgrades = {};

  // ---- timed deals ----
  //
  // Keyed by product id, and the same promise as the two above: a
  // product with no deal on it is simply not in here. Fetched with the
  // catalogue rather than when the Deals tab opens, because a struck
  // through price has to read the same in the Shop grid, on the product
  // page and in the basket, not only on the one screen.
  Map<int, TimedDeal> timedDeals = {};

  // ---- who is signed in ----
  Map<String, dynamic>? user;
  bool get loggedIn => user != null;

  /// Whether the signed-in account is shop staff.
  ///
  /// Only used to decide what the Account tab is willing to show. It is
  /// not a permission: the database decides what anyone may actually read
  /// or write, through is_admin() inside its policies, and it would go on
  /// refusing a customer even if this were forced to true.
  bool isAdmin = false;

  // ---- basket and wishlist ----
  List<CartItem> cart = [];
  double cartTotal = 0;
  List<int> wishlist = [];

  // ---- promotions ----
  List<Deal> deals = [];

  int get cartCount => cart.fold(0, (sum, item) => sum + item.qty);

  /// The columns a customer may read of their own row. Asking for
  /// everything would be refused: password_hash is revoked from every
  /// client role, and a select of all columns has to be allowed all of
  /// them.
  static const String _profileColumns = 'customer_id,name,email,phone,address';

  // ------------------------------------------------------------
  // Start-up
  // ------------------------------------------------------------
  Future<void> start() async {
    await _loadAnonId();
    await loadProducts();
    await refreshSession();
    await loadDeals();
  }

  // ------------------------------------------------------------
  // The id of this phone, as distinct from the person holding it
  //
  // customer_id answers "who is this?" and is null for anyone not signed
  // in, which leaves an anonymous visitor's rows as a heap of unrelated
  // facts — two views a minute apart from this phone cannot be told from
  // two views by two strangers. _anonId answers the weaker question "was
  // this the same phone?", which is all that is needed to group a visit
  // into a session and, once they sign up, to hand them what they did
  // before they had an account.
  //
  // Made once and kept. It is not a login and proves nothing: the
  // database does not check it, and it identifies an install rather than
  // a person. Reinstalling starts a new one, which is correct — that is
  // a new anonymous visitor as far as anything here can tell.
  //
  // Read once at start-up and held, so that tracking a view stays a
  // fire-and-forget call with no await in front of it.
  // ------------------------------------------------------------
  static const String _anonIdKey = 'etech_anon_id';
  String? _anonId;

  Future<void> _loadAnonId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_anonIdKey);
      if (id == null) {
        id = _newUuidV4();
        await prefs.setString(_anonIdKey, id);
      }
      _anonId = id;
    } catch (e) {
      // Storage unavailable. Tracking must never stop the app starting,
      // so this install is simply untrackable while signed out.
      debugPrint('Anon id: $e');
      _anonId = null;
    }
  }

  /// A version 4 UUID, which is the type the anon_id column holds.
  ///
  /// Written out rather than pulled in: the uuid package would be a new
  /// dependency for sixteen random bytes, and Random.secure() is the same
  /// source of randomness it would use.
  static String _newUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // ------------------------------------------------------------
  // Catalogue
  //
  // Four tables, fetched at the same time rather than one after another.
  // A product's brand and category live in their own tables, and its
  // specifications are one row per spec — which is what lets a printer
  // have a paper size and a CPU have a socket without the products table
  // growing a column for every idea anyone ever has.
  //
  // Putting them back together is the work api/products.php was doing.
  // It has to happen somewhere, and here is as good a place as the PHP
  // was — better, in fact, because the website and the app now share the
  // shape rather than sharing a server.
  // ------------------------------------------------------------
  Future<void> loadProducts() async {
    loadingProducts = true;
    loadError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        Api.selectAll(() => Api.db
            .from('products')
            .select('product_id,name,price,stock_status,description,icon,'
                'img_slug,image_path,exclude_from_builder,brand_id,category_id')
            .eq('is_active', 1)
            .order('product_id')),
        Api.selectAll(() => Api.db.from('brands').select('brand_id,name')),
        Api.selectAll(
            () => Api.db.from('categories').select('category_id,name,parent_id')),
        Api.selectAll(() => Api.db
            .from('product_attributes')
            .select('product_id,attr_key,attr_value')),
        // The shop's own builds. Fetched with the catalogue rather than
        // when the Prebuilt tab opens, because the stock badge has to be
        // right everywhere a machine appears -- search results, the Shop
        // grid, its own product page -- not only on the one screen.
        Api.selectAll(() => Api.db.from('prebuilt_availability').select(
            'prebuilt_id,linked,pending,not_stocked,derived_status,blocking_parts')),
        Api.selectAll(() => Api.db
            .from('prebuilt_upgrades')
            .select('upgrade_id,prebuilt_id,slot,label,price_delta,kind')
            .eq('is_active', 1)
            .order('prebuilt_id')
            .order('sort_order')),
        // live_deals is a view and it is already only the running ones:
        // the policy on the deals table hides the rest from the shop
        // front, and the view's own WHERE hides them from a signed-in
        // member of staff. The app is not asked to filter anything.
        //
        // This one is allowed to fail on its own. Every other request
        // here is the shop -- no products, no app -- but an app that
        // cannot read its deals is an app at list price, which is a
        // worse day rather than a broken one. It also means a build can
        // ship before the migration that creates the view.
        Api.selectAll(() => Api.db
                .from('live_deals')
                .select('deal_id,product_id,discount_price,start_time,end_time'))
            .catchError((Object e) {
          debugPrint('Reading deals (prices shown will be list prices): $e');
          return <Map<String, dynamic>>[];
        }),
      ]);

      products = _shapeCatalogue(results[0], results[1], results[2], results[3]);
      _shapePrebuilts(results[4], results[5]);
      _shapeDeals(results[6]);
      loadError = null;
    } catch (e) {
      loadError = Api.message(e, 'Could not load the catalogue.');
    }

    loadingProducts = false;
    notifyListeners();
  }

  /// Specifications that can hold several values, so they must come back
  /// as a list even when there happens to be only one.
  static const _arraySpecs = {
    'sockets',
    'supportedFormFactors',
    'incompatibleSockets',
  };

  /// Specifications that are numbers. Everything is stored as text, and
  /// the compatibility checks compare these with < and >, so "90" has to
  /// become 90 or a 90W cooler looks bigger than a 105W one.
  static const _numberSpecs = {
    'tdp', 'coolerRating', 'power', 'length',
    'wattage', 'maxGpuLength', 'pcieGen', 'cores', 'threads',
  };

  List<Product> _shapeCatalogue(
    List<Map<String, dynamic>> productRows,
    List<Map<String, dynamic>> brandRows,
    List<Map<String, dynamic>> categoryRows,
    List<Map<String, dynamic>> attributeRows,
  ) {
    final brandName = {
      for (final b in brandRows) b['brand_id'] as int: b['name'] as String
    };
    final category = {
      for (final c in categoryRows) c['category_id'] as int: c
    };

    // Group the specifications by product, rather than looking them up
    // one product at a time.
    final specsFor = <int, Map<String, dynamic>>{};
    for (final row in attributeRows) {
      final id = row['product_id'] as int;
      final key = row['attr_key'] as String;
      final specs = specsFor.putIfAbsent(id, () => <String, dynamic>{});

      dynamic value = row['attr_value'];
      if (_numberSpecs.contains(key)) {
        value = num.tryParse(value as String) ?? value;
      }

      if (_arraySpecs.contains(key)) {
        (specs[key] ??= <dynamic>[]).add(value);
      } else {
        specs[key] = value;
      }
    }

    return productRows.map((row) {
      final own = category[row['category_id'] as int];
      final parentId = own?['parent_id'] as int?;
      final parent = parentId == null ? null : category[parentId];

      // A category with a parent is a sub-category: "Components > CPU".
      // The app shows the top-level name as the category and the child as
      // the subcategory.
      return Product.fromRow(
        row,
        brand: brandName[row['brand_id'] as int] ?? '',
        category: (parent ?? own)?['name'] as String? ?? '',
        subcategory: parent == null ? null : own!['name'] as String,
        attrs: specsFor[row['product_id'] as int] ?? const {},
      );
    }).toList();
  }

  // ------------------------------------------------------------
  // The shop's own builds
  //
  // A Gaming or Office machine is assembled here from parts the shop
  // also sells separately, so "can this be sold?" is a question about
  // those parts. The database answers it in prebuilt_availability; this
  // just files the answers by machine.
  // ------------------------------------------------------------
  void _shapePrebuilts(
    List<Map<String, dynamic>> availabilityRows,
    List<Map<String, dynamic>> upgradeRows,
  ) {
    availability = {
      for (final row in availabilityRows)
        row['prebuilt_id'] as int: PrebuiltAvailability.fromRow(row),
    };

    final byMachine = <int, List<PrebuiltUpgrade>>{};
    for (final row in upgradeRows) {
      final upgrade = PrebuiltUpgrade.fromRow(row);
      (byMachine[upgrade.prebuiltId] ??= []).add(upgrade);
    }
    upgrades = byMachine;
  }

  /// The stock status to show for a product.
  ///
  /// For anything that is not one of the shop's builds, and for a build
  /// whose bill of materials is not finished, this is the product's own
  /// status and nothing has changed. For a build that is fully described,
  /// the parts decide: one of them out and the machine is out.
  ///
  /// Every screen should ask this rather than reading product.stock, so
  /// that a machine cannot read "In Stock" in the Shop grid and "Out of
  /// Stock" on the Prebuilt tab.
  String stockOf(Product p) =>
      availability[p.id]?.statusOr(p.stock) ?? p.stock;

  bool inStock(Product p) => stockOf(p) != 'out';

  void _shapeDeals(List<dynamic> dealRows) {
    timedDeals = {
      for (final row in dealRows)
        row['product_id'] as int:
            TimedDeal.fromRow(Map<String, dynamic>.from(row as Map)),
    };
  }

  /// The deal running on a product right now, or null.
  ///
  /// A deal priced at or above the list price is a slip rather than an
  /// offer, and is ignored here for the same reason place_order takes
  /// the lower of the two: nobody should be charged more because a sale
  /// was typed in wrong.
  TimedDeal? dealFor(Product p) {
    final deal = timedDeals[p.id];
    if (deal == null || !deal.isRunning) return null;
    if (deal.price >= p.price) return null;
    return deal;
  }

  bool hasDeal(Product p) => dealFor(p) != null;

  /// What a product costs. Ask this rather than reading p.price, the
  /// same way [stockOf] is asked rather than reading p.stock.
  double priceOf(Product p) => dealFor(p)?.price ?? p.price;

  /// The products on offer, biggest saving first -- as a proportion, so
  /// RM50 off a RM200 keyboard is not buried under RM50 off a RM4,000
  /// machine.
  List<Product> get dealProducts {
    final list = products.where(hasDeal).toList();
    list.sort((a, b) {
      double cut(Product p) => (p.price - priceOf(p)) / p.price;
      return cut(b).compareTo(cut(a));
    });
    return list;
  }

  String stockLabelOf(Product p) {
    switch (stockOf(p)) {
      case 'in':
        return 'In Stock';
      case 'low':
        return 'Low Stock';
      default:
        return 'Out of Stock';
    }
  }

  /// Which parts are holding a machine back, when that is why it is out.
  /// Null whenever there is nothing useful to say.
  String? blockedBy(Product p) => availability[p.id]?.blockedBy;

  /// The upgrade options offered on a machine, in the shop's own order.
  List<PrebuiltUpgrade> upgradesFor(int productId) =>
      upgrades[productId] ?? const [];

  // ------------------------------------------------------------
  // Promotions
  //
  // Nothing here filters out the expired or switched-off ones, on
  // purpose: the policy on the coupons table only ever returns
  // promotions that are active and inside their dates. The app cannot
  // see a dead coupon in order to show it by mistake.
  // ------------------------------------------------------------
  Future<void> loadDeals() async {
    try {
      final rows = await Api.db
          .from('coupons')
          .select('code,description,discount_percent,ends_at,categories(name)')
          .order('discount_percent', ascending: false);

      deals = rows.map<Deal>((r) => Deal.fromRow(r)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Loading promotions: $e');
    }
  }

  // ------------------------------------------------------------
  // Account
  //
  // Two steps rather than one. Supabase Auth says whether there is a
  // valid session; the customers table says who that session belongs to.
  // The policy on that table means the query can only ever return the
  // caller's own row, which is why there is no "where customer_id = ..."
  // to get wrong.
  // ------------------------------------------------------------
  Future<void> refreshSession() async {
    if (Api.db.auth.currentSession == null) {
      user = null;
    } else {
      try {
        user = await Api.db
            .from('customers')
            .select(_profileColumns)
            .maybeSingle();
      } catch (e) {
        debugPrint('Reading the profile: $e');
        user = null;
      }
    }

    isAdmin = await _readIsAdmin();

    notifyListeners();

    if (loggedIn) {
      await loadCart();
      await loadWishlist();
      await loadNotifications();
      _subscribeToNotifications();
    } else {
      cart = [];
      cartTotal = 0;
      wishlist = [];
      await _unsubscribeFromNotifications();
      notifyListeners();
    }
  }

  /// Asks the database whether this account is staff.
  ///
  /// is_admin() is the same function the Row Level Security policies call,
  /// so there is one answer to this question rather than the app's opinion
  /// and the database's. It is granted to anon as well as authenticated
  /// and simply returns false when nobody is signed in.
  Future<bool> _readIsAdmin() async {
    if (Api.db.auth.currentSession == null) return false;
    try {
      final result = await Api.db.rpc('is_admin');
      return result == true;
    } catch (e) {
      // Treated as "not staff": the cautious answer, since the only thing
      // this unlocks is showing more about how the shop is built.
      debugPrint('Checking staff status: $e');
      return false;
    }
  }

  /// The customer's id. The screens know it as `user['customer_id']` now
  /// rather than `user['id']`, because it is read straight off the row.
  int? get _customerId => user?['customer_id'] as int?;

  /// Returns null when it worked, or a message to show.
  ///
  /// The same error whether the address is unknown or the password is
  /// wrong, so nobody can use this to find out who has an account here.
  /// That was true of the PHP and Supabase returns one error for both.
  Future<String?> login(String email, String password) async {
    try {
      await Api.db.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on AuthException {
      return 'Incorrect email or password.';
    } catch (e) {
      return Api.message(e, 'Could not sign in.');
    }

    await refreshSession();
    await _claimAnonActivity();
    return loggedIn ? null : 'That account cannot sign in to the shop.';
  }

  /// Registering writes to Supabase Auth. The row in customers is made by
  /// a database trigger watching for new sign-ups, which is why the name
  /// travels as sign-up metadata — the trigger reads it from there.
  /// Signing up has three outcomes, not two, now that email confirmation
  /// is on: refused, made-and-signed-in, and made-but-go-and-confirm. The
  /// third is a success and must not be painted in the red error box, so
  /// this returns a record rather than the old `String?` where any
  /// non-null value meant failure.
  ///
  ///   (ok: true,  message: null)     signed in, close the screen
  ///   (ok: true,  message: "Check…") made, needs confirming
  ///   (ok: false, message: "…")      refused, show as an error
  Future<({bool ok, String? message})> register(
      String name, String email, String password) async {
    name = name.trim();
    email = email.trim().toLowerCase();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      return (ok: false, message: 'Please fill in every field.');
    }
    // Matches auth.minimum_password_length in supabase/config.toml and the
    // same check in web/js/auth.js.
    if (password.length < 8) {
      return (ok: false, message: 'Password must be at least 8 characters.');
    }

    try {
      final result = await Api.db.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      // No session back means the project is set to confirm addresses by
      // email before letting anyone in. The account exists either way.
      // With confirmation on this is the normal path for a new customer,
      // not the unusual one. The link expires in fifteen minutes
      // (auth.email.otp_expiry in supabase/config.toml).
      if (result.session == null) {
        return (
          ok: true,
          message: 'Account created. Check your email to confirm the address, '
              'then sign in. The link expires in 15 minutes.',
        );
      }
    } on AuthException catch (e) {
      // Deliberately does not say whether the address is already taken.
      // Answering that turns this form into a way of testing whether a
      // given person shops here, one address at a time — see the note on
      // registerError() in web/js/auth.js. The sign-in screen has always
      // given one answer to both a wrong password and an unknown address;
      // this is the same rule, applied to the other door.
      //
      // Passing e.message straight back is dropped for the same reason:
      // Supabase's own wording names the cause.
      final m = e.message.toLowerCase();
      if (m.contains('invalid') && m.contains('email')) {
        return (ok: false, message: 'That email address does not look right.');
      }
      if (m.contains('weak') || m.contains('password')) {
        return (ok: false, message: 'Please choose a stronger password.');
      }
      return (
        ok: false,
        message: 'Could not create the account. If you have signed up before, '
            'please sign in instead.',
      );
    } catch (e) {
      return (ok: false, message: Api.message(e, 'Could not create the account.'));
    }

    await refreshSession();
    await _claimAnonActivity();
    return (ok: true, message: null);
  }

  Future<void> logout() async {
    // Before signing out, while the channel is still the customer's.
    await _unsubscribeFromNotifications();
    await Api.db.auth.signOut();
    user = null;
    isAdmin = false;
    cart = [];
    cartTotal = 0;
    wishlist = [];
    notifyListeners();
  }

  /// Ask for a "set a new password" email.
  ///
  /// The link in that email lands on the *website*, not here. Finishing a
  /// reset needs the recovery token in the link to reach a Supabase client,
  /// and the app has no way to receive a link until it registers a deep
  /// link with Android. web/reset-password.html already does the job, is
  /// already inside the redirect allow-list, and was tested end to end on
  /// 9 September, so the app asks for the mail and the website completes it.
  /// The screen says so plainly rather than leaving somebody waiting for
  /// something to happen on the phone.
  ///
  /// The answer is deliberately the same whether or not the address has an
  /// account, exactly as web/js/auth.js does it: a different reply for a
  /// real address turns this box into a way of finding out who is
  /// registered. Failures are swallowed for the same reason.
  static const String resetSentMessage =
      'If that address has an account, a link to set a new password is on its '
      'way. Open it on the website — it expires in 15 minutes, and it may '
      'take a minute to arrive, so check the spam folder before asking for '
      'another.';

  Future<({bool ok, String message})> requestPasswordReset(String email) async {
    final address = email.trim().toLowerCase();

    // A malformed address is a fact about what was typed, not about who
    // holds an account, so this one can be answered honestly.
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address)) {
      return (ok: false, message: 'That email address does not look right.');
    }

    try {
      await Api.db.auth.resetPasswordForEmail(
        address,
        redirectTo: '${Config.webOrigin}/reset-password.html',
      );
    } catch (_) {
      // Deliberately ignored. See above.
    }
    return (ok: true, message: resetSentMessage);
  }

  /// Three columns and no more. That is not politeness — UPDATE on the
  /// customers table is granted on exactly (name, phone, address), so a
  /// request trying to change the email or the login it belongs to is
  /// refused by Postgres rather than by this method.
  Future<String?> updateProfile(String name, String phone, String address) async {
    final id = _customerId;
    if (id == null) return 'Please sign in first.';
    if (name.trim().isEmpty) return 'Name cannot be empty.';

    try {
      await Api.db.from('customers').update({
        'name': name.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
      }).eq('customer_id', id);
    } catch (e) {
      return Api.message(e, 'Could not save.');
    }

    user?['name'] = name.trim();
    user?['phone'] = phone.trim();
    user?['address'] = address.trim();
    notifyListeners();
    return null;
  }

  // ------------------------------------------------------------
  // Basket
  //
  // The basket, with each line's product joined on, so one request brings
  // back the names, prices and pictures too. This is the same query
  // api/cart.php was running; Supabase spells the join as a nested select.
  // ------------------------------------------------------------
  Future<void> loadCart() async {
    if (!loggedIn) return;
    try {
      // Two requests rather than one nested select. cart_item_upgrades
      // hangs off cart_items by a two-column key, which PostgREST will
      // not walk without being told which constraint to use; asking for
      // the rows plainly and matching them up here is the version that
      // keeps working when the schema is next touched.
      final results = await Future.wait([
        Api.db
            .from('cart_items')
            .select('product_id,quantity,'
                'products(name,price,icon,img_slug,image_path,stock_status)')
            .order('added_at'),
        Api.db.from('cart_item_upgrades').select(
            'product_id,prebuilt_upgrades(upgrade_id,prebuilt_id,slot,label,price_delta,kind)'),
      ]);

      final chosen = <int, List<PrebuiltUpgrade>>{};
      for (final row in results[1]) {
        final upgrade = row['prebuilt_upgrades'];
        if (upgrade == null) continue;
        (chosen[row['product_id'] as int] ??= []).add(
          PrebuiltUpgrade.fromRow(Map<String, dynamic>.from(upgrade as Map)),
        );
      }
      for (final list in chosen.values) {
        list.sort((a, b) => a.slot.compareTo(b.slot));
      }

      // A live deal changes what the line costs, so the basket has to
      // know about it or the total on screen disagrees with the total
      // charged. The deal is looked up in the catalogue by id; a product
      // switched off while it sat in somebody's basket is not there, and
      // then its own price stands.
      cart = results[0].map<CartItem>((r) {
        final productId = r['product_id'] as int;
        final inCatalogue = byId(productId);

        return CartItem.fromRow(
          r,
          upgrades: chosen[productId] ?? const [],
          dealPrice: inCatalogue == null ? null : dealFor(inCatalogue)?.price,
        );
      }).toList();
      cartTotal = cart.fold(0, (sum, item) => sum + item.lineTotal);
      notifyListeners();
    } catch (e) {
      debugPrint('Reading the basket: $e');
    }
  }

  /// Adding goes through a database function rather than writing the row
  /// directly, because it is two things at once: the basket line, and an
  /// activity record worth 3 in the Inventory Velocity score. If the app
  /// could write those separately it could write the second without the
  /// first, and the score the admin dashboard is built on would mean
  /// nothing. cart_add() does both or neither, and re-checks the stock.
  /// [upgradeIds] are the options ticked on a prebuilt card. They are
  /// written after the line exists, because cart_item_upgrades is keyed
  /// on the line and cannot be written before there is one. Adding the
  /// same machine again replaces its upgrades with the newer choice
  /// rather than merging the two, which is what a customer changing
  /// their mind on the card expects to happen.
  Future<String?> addToCart(
    int productId, {
    List<int> upgradeIds = const [],
  }) async {
    if (!loggedIn) return 'Please sign in first.';
    try {
      await Api.db.rpc('cart_add', params: {'p_product_id': productId});
    } catch (e) {
      return Api.message(e, 'Could not add that.');
    }

    if (upgradeIds.isNotEmpty) {
      final customerId = user?['customer_id'];
      try {
        await Api.db
            .from('cart_item_upgrades')
            .delete()
            .eq('product_id', productId);
        await Api.db.from('cart_item_upgrades').insert([
          for (final id in upgradeIds)
            {
              'customer_id': customerId,
              'product_id': productId,
              'upgrade_id': id,
            },
        ]);
      } catch (e) {
        // The machine is in the basket either way; say so plainly rather
        // than leaving the customer thinking nothing happened.
        await loadCart();
        return Api.message(e, 'Added, but the upgrades could not be saved.');
      }
    }

    await loadCart();
    return null;
  }

  /// Drop one upgrade from a basket line, from the cart screen.
  Future<void> removeUpgrade(int productId, int upgradeId) async {
    try {
      await Api.db
          .from('cart_item_upgrades')
          .delete()
          .eq('product_id', productId)
          .eq('upgrade_id', upgradeId);
    } catch (e) {
      debugPrint('Removing an upgrade: $e');
    }
    await loadCart();
  }

  Future<void> setQty(int productId, int qty) async {
    if (qty < 1) return;
    try {
      await Api.db
          .from('cart_items')
          .update({'quantity': qty})
          .eq('product_id', productId);
    } catch (e) {
      debugPrint('Changing the quantity: $e');
    }
    await loadCart();
  }

  Future<void> removeFromCart(int productId) async {
    try {
      await Api.db.from('cart_items').delete().eq('product_id', productId);
    } catch (e) {
      debugPrint('Removing from the basket: $e');
    }
    await loadCart();
  }

  // ------------------------------------------------------------
  // Wishlist
  // ------------------------------------------------------------
  Future<void> loadWishlist() async {
    if (!loggedIn) return;
    try {
      final rows = await Api.db
          .from('wishlist_items')
          .select('product_id')
          .order('added_at');

      wishlist = rows.map<int>((r) => r['product_id'] as int).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Reading the wishlist: $e');
    }
  }

  bool inWishlist(int productId) => wishlist.contains(productId);

  /// Like adding to the basket, this goes through a database function:
  /// adding records an activity and removing does not, and the app should
  /// not be the thing deciding which happened. The function hands the
  /// whole list back, so one round trip repaints every heart.
  Future<String?> toggleWishlist(int productId) async {
    if (!loggedIn) return 'Please sign in first.';
    try {
      final ids = await Api.db
          .rpc('toggle_wishlist', params: {'p_product_id': productId});
      wishlist = (ids as List).cast<int>();
      notifyListeners();
    } catch (e) {
      return Api.message(e, 'Could not save that.');
    }
    return null;
  }

  // ------------------------------------------------------------
  // Notifications
  //
  // Staff approving a payment, rejecting a receipt or marking an order
  // Ready leaves a row in the notifications table, written by the same
  // database function that moves the order. The app reads the newest
  // twenty when the customer signs in, and holds a Realtime channel open
  // so a new one arrives the moment staff press the button — the website
  // does exactly the same (web/js/notifications.js).
  //
  // The policy on the table returns the customer's own rows only, and
  // Realtime applies that same policy before it hands a row over. The
  // filter on the channel is not what keeps anyone else's news out; it
  // only spares the server checking rows that were never ours.
  //
  // This is in-app only. A message reaches the phone while the app is
  // open; an alert on a locked phone would need a push service (Firebase
  // Cloud Messaging), which the shop does not have.
  // ------------------------------------------------------------
  static const int _notificationLimit = 20;

  List<ShopNotification> notifications = [];
  RealtimeChannel? _notificationChannel;
  final StreamController<ShopNotification> _arrivals =
      StreamController<ShopNotification>.broadcast();

  int get unreadNotifications => notifications.where((n) => n.unread).length;

  /// One event per message that arrives while the app is open. The shell
  /// shows a snack bar from it and the Orders screen reloads on it.
  Stream<ShopNotification> get notificationArrivals => _arrivals.stream;

  Future<void> loadNotifications() async {
    try {
      final rows = await Api.db
          .from('notifications')
          .select('notification_id,order_id,product_id,kind,title,body,created_at,read_at')
          .order('created_at', ascending: false)
          .limit(_notificationLimit);
      notifications = rows.map<ShopNotification>(ShopNotification.fromRow).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Loading notifications: $e');
    }
  }

  /// Everything unread becomes read. Called when the list is opened.
  Future<void> markNotificationsRead() async {
    if (unreadNotifications == 0) return;
    try {
      await Api.db.rpc('mark_notifications_read');
      final now = DateTime.now();
      for (final n in notifications) {
        n.readAt ??= now;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Marking notifications read: $e');
    }
  }

  void _subscribeToNotifications() {
    final id = _customerId;
    if (id == null || _notificationChannel != null) return;

    _notificationChannel = Api.db
        .channel('notifications-$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: id,
          ),
          callback: (payload) {
            final n = ShopNotification.fromRow(payload.newRecord);
            if (notifications.any((x) => x.id == n.id)) return;
            notifications = [n, ...notifications].take(_notificationLimit).toList();
            notifyListeners();
            _arrivals.add(n);
          },
        )
        .subscribe();
  }

  Future<void> _unsubscribeFromNotifications() async {
    final channel = _notificationChannel;
    _notificationChannel = null;
    notifications = [];
    if (channel != null) await Api.db.removeChannel(channel);
  }

  // ------------------------------------------------------------
  // Orders
  // ------------------------------------------------------------
  Future<List<Order>> loadOrders() async {
    try {
      // No "and only mine" filter, and none needed: the policy on orders
      // returns the signed-in customer's own rows and nothing else.
      final rows = await Api.db
          .from('orders')
          .select('order_id,order_date,status,subtotal,discount,total,'
              'coupon_code,shipping_name,shipping_phone,shipping_address,'
              'fulfilment_method,'
              'payment_method,payment_status,receipt_image_path,'
              'order_items(product_id,product_name,unit_price,quantity,line_total)')
          .order('order_date', ascending: false);

      return rows.map<Order>((r) => Order.fromRow(r)).toList();
    } catch (e) {
      debugPrint('Loading orders: $e');
      return [];
    }
  }

  /// Checkout.
  ///
  /// place_order() is a function inside the database. It reads the basket,
  /// prices it, writes the order and its lines, records a purchase against
  /// each product and empties the basket — all as one indivisible step, so
  /// a failure halfway cannot leave an order with no items in it.
  ///
  /// The name, the phone number, how the customer wants to get their
  /// things, the coupon code and how they intend to pay. The address goes
  /// with it only for a delivery — a collection has nowhere to send
  /// anything, and the database drops any address sent with one anyway.
  ///
  /// [fulfilment] is always sent explicitly. The database will infer it
  /// from the presence of an address if a caller says nothing, but that
  /// path exists for APKs built before the choice did, not for this one.
  ///
  /// Every price, the discount and the total are worked out down there
  /// from the basket rows, so a modified app cannot change what anything
  /// costs — nor whether the payment has been checked, which starts at
  /// PENDING on that side and can only be moved by a member of staff.
  Future<Map<String, dynamic>> placeOrder(
      String name, String phone, String coupon,
      {String paymentMethod = 'BANK_TRANSFER',
      String fulfilment = 'PICKUP',
      String address = ''}) async {
    try {
      final result = await Api.db.rpc('place_order', params: {
        'p_name': name,
        'p_phone': phone,
        'p_address': fulfilment == 'DELIVERY' ? address : '',
        'p_coupon': coupon,
        'p_payment_method': paymentMethod,
        'p_fulfilment': fulfilment,
      });

      await loadCart();
      return {'ok': true, ...Map<String, dynamic>.from(result as Map)};
    } catch (e) {
      return {
        'ok': false,
        'error': Api.message(e, 'Could not place the order. Nothing was charged.'),
      };
    }
  }

  // ------------------------------------------------------------
  // Sending a payment receipt.
  //
  // The picture goes into a private bucket, in a folder named after the
  // customer, and the path is then handed to attach_payment_receipt().
  // That function checks the order is theirs, that the payment has not
  // already been approved, and that the path is inside their own folder
  // before it records anything — so none of the three facts this method
  // asserts are taken on the app's word.
  //
  // Uploaded as the bytes that came off the camera. The website shrinks
  // its uploads through a canvas because a browser has one to hand;
  // image_picker is asked for the same thing up front instead, with
  // maxWidth and imageQuality, so a 4MB phone photo arrives as a legible
  // JPEG well inside the bucket's 5MB limit.
  //
  // The bucket takes JPG, PNG or WEBP up to 5MB and refuses anything
  // else, but its refusal is a storage error, not a sentence. So the same
  // two rules are checked here first, and said up front under the upload
  // buttons (receiptLimits) — the website does the same in js/photo.js.
  // image_picker does not always hand back a JPEG -- a picture with
  // transparency can come back as a PNG, and a GIF or HEIC may come back
  // as it was -- so the type is read from the file's first bytes and sent
  // as what it is, rather than everything being labelled a JPEG.
  // ------------------------------------------------------------
  static const int maxReceiptBytes = 5 * 1024 * 1024;
  static const String receiptLimits = 'JPG, PNG or WEBP, up to 5MB.';

  static const Map<String, String> _receiptExtensions = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  /// Which of the three accepted types [b] is, from its signature bytes,
  /// or null for anything else (a HEIC or a GIF from the gallery, say).
  static String? _imageType(Uint8List b) {
    bool at(int offset, List<int> sig) =>
        b.length >= offset + sig.length &&
        List.generate(sig.length, (i) => b[offset + i] == sig[i]).every((ok) => ok);

    if (at(0, [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
    if (at(0, [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
    if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) {
      return 'image/webp';
    }
    return null;
  }

  Future<String?> sendReceipt(int orderId, Uint8List bytes) async {
    if (!loggedIn) return 'Please sign in first.';

    final customerId = _customerId;
    if (customerId == null) return 'Please sign in again.';

    final type = _imageType(bytes);
    if (type == null) return 'That file is not a JPG, PNG or WEBP photo.';
    if (bytes.length > maxReceiptBytes) {
      final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      return 'That photo is ${mb}MB. The limit is 5MB.';
    }

    try {
      final path = '$customerId/order${orderId}_'
          '${DateTime.now().millisecondsSinceEpoch}.${_receiptExtensions[type]}';

      await Api.db.storage.from('payment-receipts').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: type),
          );

      await Api.db.rpc('attach_payment_receipt', params: {
        'p_order_id': orderId,
        'p_path': path,
      });
    } catch (e) {
      return Api.message(e, 'Could not upload that receipt.');
    }
    return null;
  }

  // ------------------------------------------------------------
  // Powered by ASUS: the showcase gallery
  //
  // Read from rig_gallery, a view that only ever returns approved
  // submissions — the policy on the table underneath says the same
  // thing, so a screen that forgot to filter would come back empty
  // rather than publishing somebody's pending photograph.
  //
  // Not fetched with the catalogue. Unlike deals and prebuilt
  // availability, nothing outside the gallery screen needs this, and it
  // is the one list here that gets longer without limit.
  // ------------------------------------------------------------
  Future<List<RigShowcase>> loadRigGallery() async {
    try {
      final results = await Future.wait([
        Api.db
            .from('rig_gallery')
            .select('rig_id,title,description,image_urls,is_asus_verified,'
                'created_at,builder')
            .order('created_at', ascending: false),
        Api.db
            .from('rig_gallery_parts')
            .select('rig_id,product_id,product_name,price,brand'),
      ]);

      final partsFor = <int, List<RigPart>>{};
      for (final row in results[1]) {
        final part = RigPart.fromRow(Map<String, dynamic>.from(row as Map));
        (partsFor[part.rigId] ??= []).add(part);
      }

      return results[0]
          .map<RigShowcase>((r) => RigShowcase.fromRow(
                Map<String, dynamic>.from(r as Map),
                parts: partsFor[r['rig_id'] as int] ?? const [],
              ))
          .toList();
    } catch (e) {
      debugPrint('Loading the rig gallery: $e');
      return [];
    }
  }

  /// Sends a build in for review.
  ///
  /// The photographs go up first, then one call writes the build and its
  /// tags together — two statements from a phone could land the first and
  /// lose the second, and a rig with no parts on it is the one case the
  /// badge rule cannot answer.
  ///
  /// The status is not an argument. A submission is PENDING and only
  /// staff can move it, which is decided on the database's side rather
  /// than trusted to this method.
  Future<String?> submitRig({
    required String title,
    required String description,
    required List<Uint8List> photos,
    required List<int> productIds,
  }) async {
    if (!loggedIn) return 'Please sign in first.';

    final customerId = _customerId;
    if (customerId == null) return 'Please sign in again.';
    if (photos.isEmpty) return 'Add at least one photo of the build.';
    if (photos.length > 6) return 'Six photos is the most a build can have.';

    try {
      final urls = <String>[];
      for (final bytes in photos) {
        final stamp = '${DateTime.now().millisecondsSinceEpoch}_'
            '${Random().nextInt(1 << 32).toRadixString(36)}';
        final path = '$customerId/rig_$stamp.jpg';

        await Api.db.storage.from('rig-showcases').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        urls.add(Api.db.storage.from('rig-showcases').getPublicUrl(path));
      }

      await Api.db.rpc('submit_rig_showcase', params: {
        'p_title': title,
        'p_description': description,
        'p_image_urls': urls,
        'p_product_ids': productIds,
      });
    } catch (e) {
      return Api.message(e, 'Could not send that build.');
    }
    return null;
  }

  // ------------------------------------------------------------
  // Tracking — the same events the admin dashboard counts
  //
  // Insert only. The policy on these two tables allows a row to be added
  // and nothing else, so the app cannot read back what other people have
  // been looking at, and a signed-in phone may only stamp its own
  // customer id on the row.
  // ------------------------------------------------------------
  void trackView(int productId) {
    // Fire and forget; a failure here must never interrupt shopping.
    Api.db.from('events').insert({
      'customer_id': _customerId, // null = browsing signed out
      'anon_id': _anonId, // ...but still the same phone
      'source': 'app',
      'product_id': productId,
      'event_type': 'view',
    }).catchError((e) => debugPrint('Recording a view: $e'));
  }

  void logChat(String question, String answer, bool wasBuildRequest) {
    Api.db.from('chatbot_logs').insert({
      'customer_id': _customerId,
      'anon_id': _anonId,
      'source': 'app',
      'question': question,
      'answer': answer,
      'was_build_request': wasBuildRequest ? 1 : 0,
    }).catchError((e) => debugPrint('Logging the conversation: $e'));
  }

  /// What was typed into the search box, and how many products came back.
  ///
  /// A typed search says more about what somebody wants than a handful of
  /// taps does, and it is the only signal here that can describe a thing
  /// the shop does not sell — which is why the count is recorded too. A
  /// search returning nothing is the most useful row in the table.
  ///
  /// The screen filters as you type, so the naive thing would write "r",
  /// "rt", "rtx" and call the first two searches that found nothing. The
  /// screen waits until the typing stops before calling this; this end
  /// drops anything too short to be a question and anything identical to
  /// what it just wrote, so that tapping a category chip afterwards does
  /// not log the same search twice.
  String _lastLoggedSearch = '';

  void trackSearch(String query, int resultCount) {
    final text = query.trim();
    if (text.length < 3) return;
    if (text.toLowerCase() == _lastLoggedSearch) return;
    _lastLoggedSearch = text.toLowerCase();

    Api.db.from('search_logs').insert({
      'customer_id': _customerId,
      'anon_id': _anonId,
      'source': 'app',
      'query': text,
      'result_count': resultCount,
    }).catchError((e) => debugPrint('Recording a search: $e'));
  }

  /// Hands this phone's signed-out activity to the account that just
  /// signed in.
  ///
  /// Someone browses, decides to buy, and only then makes an account.
  /// Until this runs, their browsing is filed under _anonId and belongs
  /// to nobody, so the purchase arrives with nothing leading up to it —
  /// which is exactly the shape a recommender is trying to learn.
  ///
  /// The database function does the work, and can only ever hand rows
  /// belonging to nobody to whoever is calling; it cannot be made to take
  /// somebody else's. Awaited rather than fired and forgotten so that it
  /// finishes before the login screen pops, but a failure is swallowed:
  /// losing the join is a worse dataset, not a failed sign-in.
  Future<void> _claimAnonActivity() async {
    final id = _anonId;
    if (id == null || !loggedIn) return;
    try {
      await Api.db.rpc('claim_anon_activity', params: {'p_anon_id': id});
    } catch (e) {
      debugPrint('Claiming earlier activity: $e');
    }
  }

  /// Ask the AI hardware consultant.
  ///
  /// The question goes to the chat-advisor Edge Function, which holds the
  /// Gemini key and hands the model our catalogue. The key is not in this
  /// app and must not be: the publishable key above is safe to ship
  /// because Row Level Security decides what it can reach, and a Gemini
  /// key has no such backstop -- anyone who unpacks the APK would be able
  /// to spend it. See supabase/functions/chat-advisor/index.ts.
  ///
  /// Returns null whenever the consultant cannot answer -- no key set, no
  /// quota, no signal. The chat screen then falls back to the built-in
  /// advisor, so the feature degrades instead of breaking.
  ///
  /// The model returns product ids and no prices. The screen looks each id
  /// up with byId() below and draws the real card, so what the customer
  /// sees is always our price and our stock.
  Future<Map<String, dynamic>?> askAdvisor(
      String message, List<Map<String, String>> history) async {
    try {
      final res = await Api.db.functions.invoke(
        'chat-advisor',
        body: {'message': message, 'history': history},
      );
      final data = res.data;
      if (data is Map && '${data['reply'] ?? ''}'.trim().isNotEmpty) {
        return Map<String, dynamic>.from(data);
      }
      debugPrint('AI consultant returned nothing usable: $data');
      return null;
    } catch (e) {
      debugPrint('AI consultant unavailable, using built-in answers: $e');
      return null;
    }
  }

  // ------------------------------------------------------------
  // Handy lookups
  // ------------------------------------------------------------
  Product? byId(int id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Product> bySubcategory(String sub) =>
      products.where((p) => p.subcategory == sub).toList();

  List<String> get categories {
    final seen = <String>[];
    for (final p in products) {
      if (!seen.contains(p.category)) seen.add(p.category);
    }
    seen.sort();
    return seen;
  }

  List<String> get brands {
    final seen = <String>[];
    for (final p in products) {
      if (!seen.contains(p.brand)) seen.add(p.brand);
    }
    seen.sort();
    return seen;
  }
}
