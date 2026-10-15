import 'package:flutter/material.dart';
import '../config.dart';
import '../services/shop.dart';
import '../theme.dart';
import 'login.dart';
import 'notifications.dart';
import 'orders.dart';
import 'wishlist.dart';
import 'privacy.dart';
import 'profile_edit.dart';

class AccountScreen extends StatelessWidget {
  final Shop shop;
  const AccountScreen({super.key, required this.shop});

  // A route of its own, so the AnimatedBuilder round the home screen does
  // not reach it. Without this one, signing in from here came back to
  // "Not signed in", and the unread count on Notifications never moved.
  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: shop, builder: (context, _) => _page(context));

  Widget _page(BuildContext context) {
    final user = shop.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        children: [
          Container(
            width: double.infinity,
            color: AppTheme.redDark,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user != null) ...[
                  Text(user['name'] ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(user['email'] ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ] else ...[
                  const Text('Not signed in',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => LoginScreen(shop: shop)));
                    },
                    child: const Text('Sign in or register'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (user != null) ...[
            _tile(context, Icons.receipt_long_outlined, 'My Orders',
                'Track what you have ordered',
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => OrdersScreen(shop: shop)))),
            _tile(context, Icons.notifications_none, 'Notifications',
                shop.unreadNotifications > 0
                    ? '${shop.unreadNotifications} new'
                    : 'Payment and delivery updates',
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => NotificationsScreen(shop: shop)))),
            _tile(context, Icons.favorite_border, 'Wishlist',
                '${shop.wishlist.length} saved',
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => WishlistScreen(shop: shop)))),
            _tile(context, Icons.person_outline, 'Profile',
                'Name, phone and delivery address',
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ProfileEditScreen(shop: shop)))),
          ],
          // Staff only. It names the service the shop is built on and
          // shows its address, which is nobody's business but ours -- a
          // customer has no use for it and a stranger should not be told
          // what to go looking at. Hiding it is not what keeps the data
          // safe; Row Level Security does that, and the address is in the
          // app bundle either way. This just stops the shop volunteering
          // it on a screen every customer opens.
          if (shop.isAdmin)
            _tile(context, Icons.cloud_done_outlined, 'Connection',
                'Supabase — nothing to set up', () => _connectionDialog(context)),
          // Outside the `user != null` block on purpose. Somebody deciding
          // whether to take part has not signed in yet, and this is the
          // participant information sheet -- it is no use only to people who
          // have already handed over their details.
          _tile(context, Icons.privacy_tip_outlined, 'Privacy Policy',
              'What this app records, and why',
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()))),
          if (user != null)
            _tile(context, Icons.logout, 'Sign out', '', () async {
              await shop.logout();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signed out')));
              }
            }, danger: true),
          const SizedBox(height: 24),
          Center(
            child: Text('eTech Computer Accessories',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle,
          VoidCallback onTap,
          {bool danger = false}) =>
      Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(AppTheme.radius)),
        child: ListTile(
          leading: Icon(icon, color: danger ? AppTheme.red : AppTheme.redDark),
          title: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: danger ? AppTheme.red : AppTheme.ink)),
          subtitle: subtitle.isEmpty
              ? null
              : Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: danger ? null : const Icon(Icons.chevron_right, size: 20),
          onTap: onTap,
        ),
      );

  /// This used to be an editable server address, and it had to be, because
  /// the app read everything through PHP running on somebody's PC and a
  /// phone is a different machine from that PC. It is now a plain statement
  /// of where the data comes from, because there is nothing left to get
  /// wrong: Supabase is at a fixed address and the emulator, a handset and
  /// the website all reach the same one.
  void _connectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This app reads and writes the shop database directly. There is '
              'no server of ours in between, so there is no address to set and '
              'nothing to be on the same WiFi as.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            SelectableText(
              Config.supabaseUrl,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 10),
            Text(
              'What you are allowed to see is decided by the database itself, '
              'from the account you are signed in as.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await shop.start();
            },
            child: const Text('Reload'),
          ),
        ],
      ),
    );
  }
}
