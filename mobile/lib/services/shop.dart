import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
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
    await loadProducts();
    await refreshSession();
    await loadDeals();
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
      ]);

      products = _shapeCatalogue(results[0], results[1], results[2], results[3]);
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
      final rows = await Api.db
          .from('cart_items')
          .select('product_id,quantity,'
              'products(name,price,icon,img_slug,image_path,stock_status)')
          .order('added_at');

      cart = rows.map<CartItem>((r) => CartItem.fromRow(r)).toList();
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
  Future<String?> addToCart(int productId) async {
    if (!loggedIn) return 'Please sign in first.';
    try {
      await Api.db.rpc('cart_add', params: {'p_product_id': productId});
    } catch (e) {
      return Api.message(e, 'Could not add that.');
    }
    await loadCart();
    return null;
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
      'product_id': productId,
      'event_type': 'view',
    }).catchError((e) => debugPrint('Recording a view: $e'));
  }

  void logChat(String question, String answer, bool wasBuildRequest) {
    Api.db.from('chatbot_logs').insert({
      'customer_id': _customerId,
      'question': question,
      'answer': answer,
      'was_build_request': wasBuildRequest ? 1 : 0,
    }).catchError((e) => debugPrint('Logging the conversation: $e'));
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
