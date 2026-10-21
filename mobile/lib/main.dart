import 'dart:async';

import 'package:flutter/material.dart';
import 'models/notification.dart';
import 'services/api.dart';
import 'services/push.dart';
import 'services/shop.dart';
import 'theme.dart';
import 'screens/home.dart';
import 'screens/shop_screen.dart';
import 'screens/builder.dart';
import 'screens/cart.dart';
import 'screens/orders.dart';
import 'screens/prebuilt.dart';
import 'widgets/motion.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Connect to Supabase and restore the saved session before anything is
  // drawn, so the app opens already signed in if it was signed in before.
  await Api.init();
  // Push, if this build has a Firebase project behind it. Does nothing
  // at all if it does not, which is the state the app ships in until
  // someone runs `flutterfire configure` -- see services/push.dart.
  await Push.init();
  runApp(const EtechApp());
}

class EtechApp extends StatefulWidget {
  const EtechApp({super.key});

  @override
  State<EtechApp> createState() => _EtechAppState();
}

/// Held at the top so a message from the shop can be shown, and its
/// View button can open the orders, whichever screen is on top at the time.
final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> _messenger =
    GlobalKey<ScaffoldMessengerState>();

class _EtechAppState extends State<EtechApp> with WidgetsBindingObserver {
  final Shop shop = Shop();
  StreamSubscription<ShopNotification>? _arrivals;

  @override
  void initState() {
    super.initState();
    shop.start();
    _arrivals = shop.notificationArrivals.listen(_showNotification);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _arrivals?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Realtime only delivers while the socket is open, and it is not kept
  /// open while the phone is locked. Anything staff did in the meantime is
  /// in the table, so coming back to the app reads the table again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && shop.loggedIn) {
      shop.loadNotifications();
    }
  }

  void _showNotification(ShopNotification n) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: n.needsAction ? AppTheme.red : AppTheme.ink,
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(n.body),
          ],
        ),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () => _navigator.currentState?.push(
            MaterialPageRoute(builder: (_) => OrdersScreen(shop: shop)),
          ),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eTech Computer Accessories',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      navigatorKey: _navigator,
      scaffoldMessengerKey: _messenger,
      home: MainShell(shop: shop),
    );
  }
}

/// The five main sections, with the bar along the bottom.
class MainShell extends StatefulWidget {
  final Shop shop;
  const MainShell({super.key, required this.shop});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.shop,
      builder: (context, _) {
        final pages = [
          HomeScreen(
            shop: widget.shop,
            onBrowse: () => setState(() => _tab = 1),
            onBuild: () => setState(() => _tab = 2),
          ),
          ShopScreen(shop: widget.shop),
          BuilderScreen(shop: widget.shop),
          CartScreen(shop: widget.shop),
          PrebuiltScreen(shop: widget.shop),
        ];

        return Scaffold(
          body: TabEntrance(
            tab: _tab,
            child: IndexedStack(index: _tab, children: pages),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFFDE7E9),
            destinations: [
              const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home, color: AppTheme.red),
                  label: 'Home'),
              const NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view, color: AppTheme.red),
                  label: 'Shop'),
              const NavigationDestination(
                  icon: Icon(Icons.build_outlined),
                  selectedIcon: Icon(Icons.build, color: AppTheme.red),
                  label: 'Build PC'),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: widget.shop.cartCount > 0,
                  label: Text('${widget.shop.cartCount}'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                selectedIcon: const Icon(Icons.shopping_cart, color: AppTheme.red),
                label: 'Cart',
              ),
              const NavigationDestination(
                  icon: Icon(Icons.desktop_windows_outlined),
                  selectedIcon: Icon(Icons.desktop_windows, color: AppTheme.red),
                  label: 'Prebuilt'),
            ],
          ),
        );
      },
    );
  }
}
