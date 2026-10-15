import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../models/product.dart';
import '../services/compatibility.dart';
import '../services/shop.dart';
import '../theme.dart';
import '../widgets/product_image.dart';

/// Build Your Own PC — pick one part per slot, with the same compatibility
/// rules the website uses.
///
/// The app's half of web/js/build.js, in the same look: a red band with a
/// progress bar of eight segments, one numbered card per part, a picker
/// with a search box and brand tabs, and a "Your PC" card holding the
/// power meter and every check. On a phone the total and the Add button
/// ride in a bar pinned to the bottom.
class BuilderScreen extends StatefulWidget {
  final Shop shop;
  const BuilderScreen({super.key, required this.shop});

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

/// What a slot is called on screen, and its icon. Matches BUILD_SLOT_INFO
/// in web/js/build.js.
class _SlotInfo {
  final String title;
  final IconData icon;
  const _SlotInfo(this.title, this.icon);
}

const Map<String, _SlotInfo> _slotInfo = {
  'CPU': _SlotInfo('Processor (CPU)', Icons.memory),
  'Cooler': _SlotInfo('CPU Cooler', Icons.ac_unit),
  'Motherboard': _SlotInfo('Motherboard', Icons.developer_board),
  'RAM': _SlotInfo('Memory (RAM)', Icons.view_module),
  'GPU': _SlotInfo('Graphics Card (GPU)', Icons.videogame_asset_outlined),
  'Storage': _SlotInfo('Storage', Icons.storage),
  'PSU': _SlotInfo('Power Supply (PSU)', Icons.power),
  'Case': _SlotInfo('Case', Icons.computer),
};

_SlotInfo _info(String slot) =>
    _slotInfo[slot] ?? _SlotInfo(slot, Icons.extension_outlined);

num _num(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

class _BuilderScreenState extends State<BuilderScreen> {
  final Map<String, Product?> _build = {
    for (final slot in Compatibility.slots) slot: null,
  };
  bool _adding = false;

  /// The colour picked for a part that comes in several (mostly cases),
  /// by slot. Matches buildColours in web/js/build.js.
  final Map<String, String> _colours = {};

  Shop get shop => widget.shop;

  void _choose(String slot, Product? part) {
    setState(() {
      _build[slot] = part;
      _dropIncompatible();
      _colours.removeWhere((s, c) =>
          !(_build[s]?.colourOptions.contains(c) ?? false));
    });
    _scheduleReview();
  }

  // ------------------------------------------------------------
  // eTech AI review
  //
  // Once every part is picked, the build goes to eTech AI (Gemini, through
  // the chat-advisor Edge Function) for a technician's opinion, sorted the
  // shop's way: critical when the PC won't work, warning when it runs but
  // isn't ideal, plus up to two swaps from our own stock. The same feature
  // as web/js/build.js.
  //
  // The rule checks stay the only thing that can stop an order: eTech AI's
  // criticals are shown in red but never disable Add Build to Cart, and a
  // suggested swap is only offered when the rules pass with it swapped in.
  // ------------------------------------------------------------
  static const _reviewDelay = Duration(milliseconds: 1500);

  /// Reviews already had this session, by build, so changing a part and
  /// changing it back costs no second call.
  static final Map<String, Map<String, dynamic>> _reviewCache = {};

  Timer? _reviewTimer;
  String _reviewKey = '';
  Map<String, dynamic>? _review;
  bool _reviewFailed = false;

  @override
  void dispose() {
    _reviewTimer?.cancel();
    super.dispose();
  }

  String _buildKey() => Compatibility.slots
      .map((slot) => '$slot:${_build[slot]?.id ?? 0}')
      .join(',');

  void _scheduleReview() {
    _reviewTimer?.cancel();
    if (!Compatibility.allPicked(_build)) {
      setState(() {
        _reviewKey = '';
        _review = null;
        _reviewFailed = false;
      });
      return;
    }
    final key = _buildKey();
    setState(() {
      _reviewKey = key;
      _review = _reviewCache[key];
      _reviewFailed = false;
    });
    if (_review == null) {
      _reviewTimer = Timer(_reviewDelay, () => _requestReview(key));
    }
  }

  Future<void> _requestReview(String key) async {
    final checks = Compatibility.check(_build);
    final result = await shop.reviewBuild(
      {
        for (final slot in Compatibility.slots)
          if (_build[slot] != null) slot: _build[slot]!.id,
      },
      [
        for (final c in checks) {'level': c.level.name, 'text': c.text},
      ],
    );
    // The customer may have changed the build while we waited.
    if (!mounted || key != _reviewKey) return;
    setState(() {
      if (result == null) {
        _reviewFailed = true;
      } else {
        _reviewCache[key] = result;
        _review = result;
      }
    });
  }

  /// A swap is only offered when the part still exists, belongs in that
  /// slot, is in stock, and every rule passes with it swapped in.
  Product? _safeSwap(Map<String, dynamic> swap) {
    final slot = '${swap['slot']}';
    final id = swap['product_id'];
    final part = id is num ? shop.byId(id.toInt()) : null;
    if (part == null || part.subcategory != slot) return null;
    if (part.excludeFromBuilder || !part.inStock || _build[slot]?.id == part.id) {
      return null;
    }
    final trial = Map<String, Product?>.of(_build)..[slot] = part;
    final ok = Compatibility.check(trial).every((c) => c.level != Level.critical);
    return ok ? part : null;
  }

  /// Changing the CPU or board can strand a part chosen earlier, so forget
  /// anything that no longer fits rather than leaving a bad combination.
  void _dropIncompatible() {
    for (final slot in ['Motherboard', 'CPU', 'RAM', 'Cooler', 'Case']) {
      final current = _build[slot];
      if (current == null) continue;
      final stillOk = Compatibility.eligible(
        slot,
        shop.products,
        _build,
      ).any((p) => p.id == current.id);
      if (!stillOk) _build[slot] = null;
    }
  }

  int get _pickedCount => _build.values.where((p) => p != null).length;

  /// The deal price when there is one, as the cart will charge it.
  double get _total => Compatibility.slots.fold<double>(
    0,
    (sum, s) => sum + (_build[s] == null ? 0 : shop.priceOf(_build[s]!)),
  );

  String _specText() {
    final lines = [
      for (final slot in Compatibility.slots)
        if (_build[slot] != null)
          '${_info(slot).title}: ${_build[slot]!.name} - '
              '${money(shop.priceOf(_build[slot]!))}',
    ];
    return lines.isEmpty
        ? ''
        : 'My eTech PC build\n${lines.join('\n')}\nTotal: ${money(_total)}';
  }

  Future<void> _reset() async {
    if (_pickedCount == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start over?'),
        content: const Text('This clears every part from this build.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start over'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      for (final slot in Compatibility.slots) {
        _build[slot] = null;
      }
    });
    _scheduleReview();
  }

  Future<void> _copySpecs() async {
    final messenger = ScaffoldMessenger.of(context);
    final text = _specText();
    if (text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing to copy yet')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(const SnackBar(content: Text('Build copied')));
  }

  /// WhatsApp the shop, carrying the build so far, so they see exactly
  /// what the customer is asking about.
  Future<void> _talkToUs() async {
    final messenger = ScaffoldMessenger.of(context);
    final spec = _specText();
    final uri = Config.whatsappLink(
      spec.isEmpty
          ? "Hi eTech, I'd like help choosing parts for a PC build."
          : 'Hi eTech, can you check this build for me?\n\n$spec',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  Future<void> _addToCart() async {
    final messenger = ScaffoldMessenger.of(context);
    // A part that comes in several colours needs one picked first, or
    // the shop has to ring to ask which case to build in.
    for (final slot in Compatibility.slots) {
      final part = _build[slot];
      if (part != null && part.colourOptions.isNotEmpty && _colours[slot] == null) {
        messenger.showSnackBar(SnackBar(
            content: Text('Choose a colour for your ${_info(slot).title.toLowerCase()} first.')));
        return;
      }
    }
    setState(() => _adding = true);
    int added = 0;
    for (final slot in Compatibility.slots) {
      final part = _build[slot];
      if (part == null) continue;
      final error = await shop.addToCart(part.id, colour: _colours[slot]);
      if (error != null) {
        if (mounted) setState(() => _adding = false);
        messenger.showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      added++;
    }
    if (mounted) setState(() => _adding = false);
    messenger.showSnackBar(
      SnackBar(content: Text('$added parts added to your cart')),
    );
  }

  // ------------------------------------------------------------
  // The part picker
  // ------------------------------------------------------------

  void _openPicker(String slot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _PartPicker(
        slot: slot,
        shop: shop,
        build: _build,
        onPick: (p) => _choose(slot, p),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shop,
      builder: (context, _) {
        final checks = Compatibility.check(_build);
        final canOrder = Compatibility.canOrder(_build, checks);
        final criticals = checks.where((c) => c.level == Level.critical).length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Build Your Own PC'),
            actions: [
              if (_pickedCount > 0)
                IconButton(
                  tooltip: 'Start over',
                  icon: const Icon(Icons.refresh),
                  onPressed: _reset,
                ),
            ],
          ),
          body: shop.products.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                  children: [
                    _hero(),
                    const SizedBox(height: 18),
                    for (var i = 0; i < Compatibility.slots.length; i++)
                      _slotCard(i, Compatibility.slots[i]),
                    const SizedBox(height: 8),
                    _yourPc(checks),
                  ],
                ),
          bottomNavigationBar: _bottomBar(canOrder, criticals > 0),
        );
      },
    );
  }

  /// The red band, with a bar of eight segments filled in as parts are
  /// chosen.
  Widget _hero() {
    final slots = Compatibility.slots;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        color: AppTheme.ink,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Build PC',
            style: TextStyle(fontSize: 12, color: Color(0xCCFFFFFF)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Build your own PC',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pick one part per step. Once you choose a processor we hide the '
            'boards, memory and coolers that will not work with it.',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Color(0xE6FFFFFF),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$_pickedCount of ${slots.length} parts chosen',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < slots.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: _build[slots[i]] != null
                          ? Colors.white
                          : const Color(0x40FFFFFF),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// A chosen part's photo, in the picked colour when we have that photo.
  Widget _slotPhoto(Product part, String? colour) {
    final main = ProductImage(url: part.imageUrl, isSvg: part.isSvg, height: 38);
    final url = part.colourPhotoUrl(colour);
    if (url == null) return main;
    return Image.network(
      url,
      key: ValueKey(url),
      height: 38,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => main,
    );
  }

  Widget _slotCard(int index, String slot) {
    final info = _info(slot);
    final part = _build[slot];
    final optional =
        slot == 'Cooler' && _build['CPU']?.attrs['coolerIncluded'] == 'Yes';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: part == null ? Colors.white : const Color(0xFFFDF0F1),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: () => _openPicker(slot),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(
                color: part == null ? AppTheme.line : AppTheme.red,
                width: part == null ? 1 : 1.4,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: part == null
                      ? const Color(0xFFEDEEF1)
                      : AppTheme.red,
                  child: part == null
                      ? Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.ink,
                          ),
                        )
                      : const Icon(Icons.check, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(color: AppTheme.line),
                  ),
                  child: part == null
                      ? Icon(info.icon, size: 22, color: Colors.grey.shade500)
                      : Padding(
                          padding: const EdgeInsets.all(4),
                          child: _slotPhoto(part, _colours[slot]),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              info.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.redDark,
                              ),
                            ),
                          ),
                          if (optional && part == null)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                'optional',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        part?.name ?? 'Not chosen yet',
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (part != null)
                            Text(
                              money(shop.priceOf(part)),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          const Spacer(),
                          Text(
                            part == null ? 'Choose' : 'Change',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.red,
                            ),
                          ),
                        ],
                      ),
                      if (part != null && part.colourOptions.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final c in part.colourOptions)
                              ChoiceChip(
                                label: Text(c, style: const TextStyle(fontSize: 12)),
                                visualDensity: VisualDensity.compact,
                                selected: _colours[slot] == c,
                                onSelected: (on) => setState(() {
                                  if (on) {
                                    _colours[slot] = c;
                                  } else {
                                    _colours.remove(slot);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (part != null)
                  IconButton(
                    tooltip: 'Remove ${info.title}',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _choose(slot, null),
                  )
                else
                  const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The receipt: each part and its price, the power meter, the checks,
  /// and the Copy Specs / Talk to Us buttons.
  Widget _yourPc(List<Check> checks) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your PC',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_pickedCount == 0)
            Text(
              'No parts chosen yet.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            )
          else
            for (final slot in Compatibility.slots)
              if (_build[slot] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${_info(slot).title}\n',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              TextSpan(
                                text: _build[slot]!.name,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        money(shop.priceOf(_build[slot]!)),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                money(_total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.redDark,
                ),
              ),
            ],
          ),
          _powerMeter(),
          const SizedBox(height: 14),
          if (checks.isEmpty)
            Text(
              'Start picking parts and every compatibility check will '
              'appear here.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            )
          else
            ..._checks(checks),
          ..._aiReview(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copySpecs,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Specs'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _talkToUs,
                  icon: const Icon(Icons.chat_outlined, size: 16),
                  label: const Text('Talk to Us'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Estimated draw against the power supply, as a bar, and the supply
  /// the build needs. The same Compatibility.psuNeed as the PSU check.
  Widget _powerMeter() {
    final cpu = _build['CPU'];
    final gpu = _build['GPU'];
    final psu = _build['PSU'];
    if (cpu == null && gpu == null) return const SizedBox.shrink();

    final n = Compatibility.psuNeed(cpu, gpu);
    final needed = n.needed;
    final capacity = _num(psu?.attrs['wattage']);
    final over = capacity > 0 && capacity < n.draw;
    final tight = capacity > 0 && !over && capacity < needed;
    final share = capacity > 0 ? (n.draw / capacity).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Estimated power draw',
                style: TextStyle(fontSize: 12.5),
              ),
              Text(
                'about ${n.draw}W',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recommended power supply',
                style: TextStyle(fontSize: 12.5),
              ),
              Text(
                '${needed}W or more',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (capacity > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share.toDouble(),
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E4E8),
                color: over
                    ? AppTheme.red
                    : tight
                        ? AppTheme.amber
                        : AppTheme.green,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              over
                  ? 'Your ${capacity.round()}W supply is too small for this build.'
                  : tight
                      ? '${(share * 100).round()}% of your ${capacity.round()}W supply — '
                          'below the ${needed}W we recommend.'
                      : '${(share * 100).round()}% of your ${capacity.round()}W supply.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
            ),
          ] else
            Text(
              'Choose a power supply of at least ${needed}W.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
            ),
        ],
      ),
    );
  }

  List<Widget> _checks(List<Check> checks) {
    final criticals = checks.where((c) => c.level == Level.critical).toList();
    final passes = checks.where((c) => c.level == Level.pass).toList();
    return [
      _summaryHeader(criticals.length, passes.length),
      if (criticals.isNotEmpty)
        _group(
          'Critical — needs changing',
          criticals,
          const Color(0xFFFDE8E8),
          AppTheme.red,
          Icons.close,
        ),
      if (passes.isNotEmpty)
        _group(
          'Checks passed',
          passes,
          const Color(0xFFE3F8E8),
          AppTheme.green,
          Icons.check,
        ),
    ];
  }

  /// The total and the Add button, always on screen.
  Widget _bottomBar(bool canOrder, bool hasCriticals) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.line)),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    money(_total),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.redDark,
                    ),
                  ),
                  Text(
                    _pickedCount == 0
                        ? 'No parts selected'
                        : '$_pickedCount of ${Compatibility.slots.length} parts selected',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: canOrder && !_adding ? _addToCart : null,
              child: Text(
                canOrder
                    ? 'Add Build to Cart'
                    : hasCriticals
                    ? 'Fix the problems'
                    : 'Choose every part',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The eTech AI review section, under the rule checks.
  List<Widget> _aiReview() {
    const note = TextStyle(fontSize: 12.5, color: AppTheme.ink3, height: 1.4);
    const heading = Padding(
      padding: EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        'eTech AI review',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );

    if (_reviewKey.isEmpty) {
      return const [
        heading,
        Text(
          'Pick every part and eTech AI will review the whole build: how '
          'well the parts suit each other, and what to change.',
          style: note,
        ),
      ];
    }
    if (_reviewFailed) {
      return [
        heading,
        const Text(
          "eTech AI couldn't review this build just now. The checks above "
          'still apply.',
          style: note,
        ),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: () {
            setState(() => _reviewFailed = false);
            _requestReview(_reviewKey);
          },
          child: const Text('Try again'),
        ),
      ];
    }
    final review = _review;
    if (review == null) {
      return const [
        heading,
        Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brand),
            ),
            SizedBox(width: 10),
            Expanded(child: Text('eTech AI is reviewing your build…', style: note)),
          ],
        ),
      ];
    }

    final issues = (review['issues'] is List ? review['issues'] as List : const [])
        .whereType<Map>()
        .map((i) => Check(
              i['level'] == 'critical' ? Level.critical : Level.warning,
              '${i['text'] ?? ''}',
            ))
        .where((c) => c.text.isNotEmpty)
        .toList();
    final criticals = issues.where((c) => c.level == Level.critical).toList();
    final warnings = issues.where((c) => c.level == Level.warning).toList();

    final swaps = <(Map<String, dynamic>, Product)>[];
    for (final raw in (review['swaps'] is List ? review['swaps'] as List : const [])) {
      if (raw is! Map) continue;
      final swap = Map<String, dynamic>.from(raw);
      final part = _safeSwap(swap);
      if (part != null) swaps.add((swap, part));
    }

    final verdict = switch ('${review['verdict']}') {
      'great' => ('eTech AI: a well-balanced build.', Level.pass),
      'rethink' => ("eTech AI: it works, but it's worth rethinking.", Level.warning),
      'fix_first' => ('eTech AI: fix the critical problems first.', Level.critical),
      _ => ('eTech AI: a good build, with room to improve.', Level.pass),
    };
    // The same tints as the rule checks' summary header.
    final (bg, fg) = switch (verdict.$2) {
      Level.critical => (const Color(0xFFFDE8E8), AppTheme.red),
      Level.warning => (const Color(0xFFFFF4DD), AppTheme.amber),
      Level.pass => (const Color(0xFFE3F8E8), AppTheme.green),
    };
    final summary = '${review['summary'] ?? ''}';

    return [
      heading,
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Text(
          verdict.$1,
          style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
      if (summary.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(summary, style: note.copyWith(color: AppTheme.ink)),
        ),
      if (criticals.isNotEmpty)
        _group(
          "Critical — eTech AI says this won't work",
          criticals,
          const Color(0xFFFDE8E8),
          AppTheme.red,
          Icons.close,
        ),
      if (warnings.isNotEmpty)
        _group(
          'Worth knowing',
          warnings,
          const Color(0xFFFFF4DD),
          AppTheme.amber,
          Icons.warning_amber_rounded,
        ),
      if (swaps.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 0, 6),
          child: Text(
            'SUGGESTED SWAPS',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        for (final (swap, part) in swaps) _swapRow(swap, part),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          '${criticals.isNotEmpty ? "eTech AI can be wrong. If you're unsure, ask us before you order. " : ""}'
          'Reviewed by eTech AI from our catalogue. Prices are ours; the '
          'checks above decide what can be ordered.',
          style: const TextStyle(fontSize: 11, color: AppTheme.ink3, height: 1.35),
        ),
      ),
    ];
  }

  Widget _swapRow(Map<String, dynamic> swap, Product part) {
    final slot = '${swap['slot']}';
    final now = _build[slot];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_info(slot).title,
                    style: const TextStyle(fontSize: 11, color: AppTheme.ink3)),
                Text(part.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                if (now != null)
                  Text('instead of ${now.name}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.ink3)),
                const SizedBox(height: 2),
                Text('${swap['reason'] ?? ''}',
                    style: const TextStyle(fontSize: 12.5, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(shop.priceOf(part)),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () => _choose(slot, part),
                child: const Text('Swap in'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryHeader(int criticals, int passes) {
    late String text;
    late Color bg, fg;
    if (criticals > 0) {
      text =
          '$criticals critical problem${criticals > 1 ? "s" : ""} — '
          'this build will not work until you change '
          '${criticals > 1 ? "them" : "it"}.';
      bg = const Color(0xFFFDE8E8);
      fg = AppTheme.red;
    } else {
      text = 'All $passes compatibility checks passed.';
      bg = const Color(0xFFE3F8E8);
      fg = AppTheme.green;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _group(
    String title,
    List<Check> items,
    Color bg,
    Color fg,
    IconData icon,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 0, 6),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            letterSpacing: 1,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
          ),
        ),
      ),
      ...items.map(
        (c) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.text,
                  style: TextStyle(fontSize: 12.5, color: fg, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// The sheet that opens for one slot: a search box, brand tabs, the parts
/// grouped by brand with the specs that matter for fitting, and a note
/// saying how many were left out because they don't fit.
class _PartPicker extends StatefulWidget {
  final String slot;
  final Shop shop;
  final Map<String, Product?> build;
  final ValueChanged<Product?> onPick;
  const _PartPicker({
    required this.slot,
    required this.shop,
    required this.build,
    required this.onPick,
  });

  @override
  State<_PartPicker> createState() => _PartPickerState();
}

class _PartPickerState extends State<_PartPicker> {
  String _brand = 'All';
  String _query = '';

  /// A short line of the specs that matter for fitting. Matches
  /// partSpecLine in web/js/build.js.
  static String _specLine(String slot, Product p) {
    final a = p.attrs;
    String? w(String key, String suffix) =>
        _num(a[key]) > 0 ? '${_num(a[key]).round()}$suffix' : null;
    final bits = <String?>[
      ...switch (slot) {
        'CPU' => [
          a['socket'] as String?,
          w('tdp', 'W'),
          a['igpu'] == 'No' ? 'needs a graphics card' : null,
        ],
        'Cooler' => [
          _num(a['coolerRating']) > 0
              ? 'cools up to ${w('coolerRating', 'W')}'
              : null,
        ],
        'Motherboard' => [
          a['socket'] as String?,
          a['formFactor'] as String?,
          a['ramGen'] as String?,
        ],
        'RAM' => [a['ramGen'] as String?],
        'GPU' => [w('length', 'mm long'), w('power', 'W')],
        'Storage' => [
          _num(a['pcieGen']) > 0 ? 'PCIe Gen ${_num(a['pcieGen'])}' : null,
        ],
        'PSU' => [w('wattage', 'W')],
        'Case' => [
          (a['supportedFormFactors'] as List?)?.join(' / '),
          _num(a['maxGpuLength']) > 0
              ? 'cards up to ${w('maxGpuLength', 'mm')}'
              : null,
        ],
        _ => const <String?>[],
      },
    ];
    return bits.where((b) => b != null && b.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final slot = widget.slot;
    final title = _info(slot).title;
    final eligible = Compatibility.eligible(slot, shop.products, widget.build);
    final brands = [
      'All',
      ...{for (final p in eligible) p.brand}.toList()..sort(),
    ];
    final brand = brands.contains(_brand) ? _brand : 'All';
    final q = _query.trim().toLowerCase();
    final shown = eligible
        .where(
          (p) =>
              (brand == 'All' || p.brand == brand) &&
              (q.isEmpty || p.name.toLowerCase().contains(q)),
        )
        .toList();

    // In-stock parts left out because they don't fit what's already
    // picked. Saying so beats letting someone think we don't sell them.
    final all = shop.products
        .where(
          (p) => p.subcategory == slot && !p.excludeFromBuilder && p.inStock,
        )
        .length;
    final hidden = all - eligible.length;

    final groups = <String, List<Product>>{};
    for (final p in shown) {
      groups.putIfAbsent(p.brand, () => []).add(p);
    }
    final chosen = widget.build[slot]?.id;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select $title',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (chosen != null)
                  TextButton(
                    onPressed: () {
                      widget.onPick(null);
                      Navigator.pop(context);
                    },
                    child: const Text('Remove'),
                  ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'Search all $title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                for (final b in brands)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(b),
                      selected: b == brand,
                      onSelected: (_) => setState(() => _brand = b),
                      selectedColor: AppTheme.red,
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        color: b == brand ? Colors.white : AppTheme.ink,
                      ),
                      showCheckmark: false,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 12),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              children: [
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      eligible.isEmpty
                          ? 'Nothing in stock fits what you have chosen so far. '
                                'Try changing the processor or motherboard first.'
                          : 'Nothing matches that search.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                for (final g in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 10, 0, 6),
                    child: Text(
                      g.key.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  for (final p in g.value) _option(p, p.id == chosen),
                ],
                if (hidden > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '$hidden more ${hidden > 1 ? "are" : "is"} hidden because '
                      '${hidden > 1 ? "they don't" : "it doesn't"} fit the parts '
                      "you've already picked.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _option(Product p, bool chosen) {
    final shop = widget.shop;
    final spec = _specLine(widget.slot, p);
    final deal = shop.hasDeal(p);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: chosen ? const Color(0xFFFDF0F1) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: () {
            widget.onPick(p);
            Navigator.pop(context);
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(
                color: chosen ? AppTheme.red : AppTheme.line,
                width: chosen ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: ProductImage(
                    url: p.imageUrl,
                    isSvg: p.isSvg,
                    height: 42,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (spec.isNotEmpty)
                        Text(
                          spec,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      const SizedBox(height: 4),
                      StockPill(
                        stock: shop.stockOf(p),
                        label: shop.stockLabelOf(p),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (deal)
                      Text(
                        money(p.price),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    Text(
                      money(shop.priceOf(p)),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: deal ? AppTheme.red : AppTheme.ink,
                      ),
                    ),
                    if (chosen)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.check_circle,
                          size: 18,
                          color: AppTheme.red,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
