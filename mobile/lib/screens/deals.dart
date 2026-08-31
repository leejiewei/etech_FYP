import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/shop.dart';
import '../theme.dart';

/// The promotions currently running, straight from the coupons table —
/// so switching one on in the admin panel makes it appear here.
class DealsScreen extends StatelessWidget {
  final Shop shop;
  const DealsScreen({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deals')),
      body: shop.deals.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_offer_outlined,
                      size: 50, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No promotions running right now',
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: shop.deals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final deal = shop.deals[i];
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: const Border(
                        top: BorderSide(color: AppTheme.red, width: 3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('${deal.discountPercent.round()}%',
                              style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.red)),
                          const SizedBox(width: 8),
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text('OFF',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.red)),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF0F3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(deal.category ?? 'Everything',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(deal.description,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: deal.code));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Code ${deal.code} copied — '
                                'paste it at checkout'),
                          ));
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppTheme.red,
                                width: 1.4,
                                style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFFFDF2F3),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(deal.code,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: AppTheme.redDark)),
                              const SizedBox(width: 10),
                              const Icon(Icons.copy,
                                  size: 16, color: AppTheme.redDark),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
