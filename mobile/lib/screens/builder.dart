import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/compatibility.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../widgets/product_image.dart';

/// Build Your Own PC — pick one part per slot, with the same compatibility
/// rules the website uses.
class BuilderScreen extends StatefulWidget {
  final Shop shop;
  const BuilderScreen({super.key, required this.shop});

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  final Map<String, Product?> _build = {
    for (final slot in Compatibility.slots) slot: null
  };

  static const Map<String, IconData> _icons = {
    'CPU': Icons.memory,
    'Cooler': Icons.ac_unit,
    'Motherboard': Icons.developer_board,
    'RAM': Icons.view_module,
    'GPU': Icons.videogame_asset,
    'Storage': Icons.storage,
    'PSU': Icons.power,
    'Case': Icons.computer,
  };

  void _pick(String slot) {
    final options = Compatibility.eligible(slot, widget.shop.products, _build);

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No $slot fits what you have chosen so far. '
            'Try changing the CPU or motherboard first.'),
      ));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Choose $slot',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('${options.length} options fit your build',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  if (_build[slot] != null)
                    TextButton(
                      onPressed: () {
                        setState(() => _build[slot] = null);
                        Navigator.pop(context);
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final p = options[i];
                  final chosen = _build[slot]?.id == p.id;
                  return ListTile(
                    leading: SizedBox(
                      width: 46,
                      child: ProductImage(
                          url: p.imageUrl, isSvg: p.isSvg, height: 40),
                    ),
                    title: Text(p.name,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text(money(p.price),
                        style: const TextStyle(fontSize: 13)),
                    trailing: chosen
                        ? const Icon(Icons.check_circle, color: AppTheme.red)
                        : null,
                    onTap: () {
                      setState(() {
                        _build[slot] = p;
                        _dropIncompatible();
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Changing the CPU or board can strand a part chosen earlier, so forget
  /// anything that no longer fits rather than leaving a bad combination.
  void _dropIncompatible() {
    for (final slot in ['Motherboard', 'RAM', 'Cooler', 'Case']) {
      final current = _build[slot];
      if (current == null) continue;
      final stillOk = Compatibility.eligible(slot, widget.shop.products, _build)
          .any((p) => p.id == current.id);
      if (!stillOk) _build[slot] = null;
    }
  }

  Future<void> _addToCart() async {
    final messenger = ScaffoldMessenger.of(context);
    int added = 0;
    for (final slot in Compatibility.slots) {
      final part = _build[slot];
      if (part == null) continue;
      final error = await widget.shop.addToCart(part.id);
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      added++;
    }
    messenger.showSnackBar(
        SnackBar(content: Text('$added parts added to your cart')));
  }

  @override
  Widget build(BuildContext context) {
    final checks = Compatibility.check(_build);
    final criticals = checks.where((c) => c.level == Level.critical).toList();
    final warnings = checks.where((c) => c.level == Level.warning).toList();
    final passes = checks.where((c) => c.level == Level.pass).toList();
    final canOrder = Compatibility.canOrder(_build, checks);
    final subtotal = Compatibility.subtotal(_build);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Build Your Own PC'),
        actions: [
          if (_build.values.any((p) => p != null))
            IconButton(
              tooltip: 'Start again',
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() {
                for (final slot in Compatibility.slots) {
                  _build[slot] = null;
                }
              }),
            ),
        ],
      ),
      body: widget.shop.products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 170),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Pick one part per slot. Once you choose a CPU we hide the '
                    'motherboards, memory and coolers that will not work with it, '
                    'so you only ever see parts that fit together.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF2C5D8F)),
                  ),
                ),
                const SizedBox(height: 14),

                ...Compatibility.slots.map((slot) {
                  final part = _build[slot];
                  final optional = slot == 'Cooler' &&
                      _build['CPU']?.attrs['coolerIncluded'] == 'Yes';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => _pick(slot),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: part == null ? AppTheme.line : AppTheme.red,
                            width: part == null ? 1 : 1.4,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFBFC),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: part == null
                                  ? Icon(_icons[slot],
                                      size: 20, color: Colors.grey.shade400)
                                  : Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: ProductImage(
                                          url: part.imageUrl,
                                          isSvg: part.isSvg,
                                          height: 34),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(slot,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.redDark)),
                                    if (optional && part == null)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Text('optional',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade500)),
                                      ),
                                  ]),
                                  const SizedBox(height: 2),
                                  Text(
                                    part?.name ?? 'Tap to choose',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.25,
                                      color: part == null
                                          ? Colors.grey.shade500
                                          : AppTheme.ink,
                                      fontWeight: part == null
                                          ? FontWeight.normal
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(part == null ? '' : money(part.price),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                            const Icon(Icons.chevron_right,
                                size: 18, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                if (checks.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _summaryHeader(criticals.length, warnings.length, passes.length),
                  if (criticals.isNotEmpty)
                    _group('Critical — needs changing', criticals,
                        const Color(0xFFFDE8E8), AppTheme.red, Icons.close),
                  if (warnings.isNotEmpty)
                    _group('Worth knowing', warnings, const Color(0xFFFFF4DD),
                        AppTheme.amber, Icons.warning_amber_rounded),
                  if (passes.isNotEmpty)
                    _group('Checks passed', passes, const Color(0xFFE3F8E8),
                        AppTheme.green, Icons.check),
                ],
              ],
            ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.line)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(money(subtotal),
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.redDark)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canOrder ? _addToCart : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canOrder ? AppTheme.red : Colors.grey.shade400,
                  ),
                  child: Text(canOrder
                      ? 'Add Build to Cart'
                      : criticals.isNotEmpty
                          ? 'Fix the problems above'
                          : 'Choose every part'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryHeader(int criticals, int warnings, int passes) {
    late String text;
    late Color bg, fg;
    if (criticals > 0) {
      text = '$criticals critical problem${criticals > 1 ? "s" : ""} — '
          'this build will not work until you change '
          '${criticals > 1 ? "them" : "it"}.';
      bg = const Color(0xFFFDE8E8);
      fg = AppTheme.red;
    } else if (warnings > 0) {
      text = 'Everything fits. $warnings thing${warnings > 1 ? "s are" : " is"} '
          'worth a look, but you can order as-is.';
      bg = const Color(0xFFFFF4DD);
      fg = AppTheme.amber;
    } else {
      text = 'All $passes compatibility checks passed.';
      bg = const Color(0xFFE3F8E8);
      fg = AppTheme.green;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
      child: Text(text,
          style:
              TextStyle(color: fg, fontSize: 13.5, fontWeight: FontWeight.bold)),
    );
  }

  Widget _group(String title, List<Check> items, Color bg, Color fg, IconData icon) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 10, 0, 6),
            child: Text(title.toUpperCase(),
                style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500)),
          ),
          ...items.map((c) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 15, color: fg),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(c.text,
                          style: TextStyle(
                              fontSize: 12.5, color: fg, height: 1.35)),
                    ),
                  ],
                ),
              )),
        ],
      );
}
