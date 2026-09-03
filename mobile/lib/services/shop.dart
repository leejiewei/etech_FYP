import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
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
      ]);

      products = _shapeCatalogue(results[0], results[1], results[2], results[3]);
      _shapePrebuilts(results[4], results[5]);
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
    } else {
      cart = [];
      cartTotal = 0;
      wishlist = [];
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
  Future<String?> register(String name, String email, String password) async {
    name = name.trim();
    email = email.trim().toLowerCase();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      return 'Please fill in every field.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    try {
      final result = await Api.db.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      // No session back means the project is set to confirm addresses by
      // email before letting anyone in. The account exists either way.
      if (result.session == null) {
        return 'Account created. Check your email to confirm the address, '
            'then sign in.';
      }
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('already registered')) {
        return 'An account with this email already exists.';
      }
      return e.message;
    } catch (e) {
      return Api.message(e, 'Could not create the account.');
    }

    await refreshSession();
    await _claimAnonActivity();
    return null;
  }

  Future<void> logout() async {
    await Api.db.auth.signOut();
    user = null;
    isAdmin = false;
    cart = [];
    cartTotal = 0;
    wishlist = [];
    notifyListeners();
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

      cart = results[0]
          .map<CartItem>((r) => CartItem.fromRow(
                r,
                upgrades: chosen[r['product_id'] as int] ?? const [],
              ))
          .toList();
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
  /// Only the delivery details and the coupon code are sent. Every price,
  /// the discount and the total are worked out down there from the basket
  /// rows, so a modified app cannot change what anything costs.
  Future<Map<String, dynamic>> placeOrder(
      String name, String phone, String address, String coupon) async {
    try {
      final result = await Api.db.rpc('place_order', params: {
        'p_name': name,
        'p_phone': phone,
        'p_address': address,
        'p_coupon': coupon,
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
