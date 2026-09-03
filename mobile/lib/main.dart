import 'package:flutter/material.dart';
import 'services/api.dart';
import 'services/shop.dart';
import 'theme.dart';
import 'screens/home.dart';
import 'screens/shop_screen.dart';
import 'screens/builder.dart';
import 'screens/cart.dart';
import 'screens/prebuilt.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Connect to Supabase and restore the saved session before anything is
  // drawn, so the app opens already signed in if it was signed in before.
  await Api.init();
  runApp(const EtechApp());
}

class EtechApp extends StatefulWidget {
  const EtechApp({super.key});

  @override
  State<EtechApp> createState() => _EtechAppState();
}

class _EtechAppState extends State<EtechApp> {
  final Shop shop = Shop();

  @override
  void initState() {
    super.initState();
    shop.start();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eTech Computer Accessories',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
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
          HomeScreen(shop: widget.shop, onBrowse: () => setState(() => _tab = 1)),
          ShopScreen(shop: widget.shop),
          BuilderScreen(shop: widget.shop),
          CartScreen(shop: widget.shop),
          PrebuiltScreen(shop: widget.shop),
        ];

        return Scaffold(
          body: IndexedStack(index: _tab, children: pages),
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
